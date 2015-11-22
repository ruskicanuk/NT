
//
//  GameLogic.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-08-02.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import NapoleonTriumph
import SpriteKit

// MARK: Move Logic

// Function returns which command options are available
func OrdersAvailableOnMove (groupSelected:Group, ordersLeft:(Int, Int) = (1,1)) -> (SelState, SelState, SelState, SelState) {
    
    // Move, Detach, Attach, Independent
    
    guard let commandSelected = groupSelected.command else {return (.Off, .Off, .Off, .Off)}
    guard let unitsSelected = groupSelected.units else {return (.Off, .Off, .Off, .Off)}
    
    var adjustCorps:Int
    var adjustInd:Int
    
    // If we are in commit mode, account for phantom commands
    if manager!.phaseNew == .Commit {
        (adjustCorps, adjustInd) = (manager!.phantomCorpsCommand, manager!.phantomIndCommand)
    }
    else {(adjustCorps, adjustInd) = (0, 0)}
    
    // Repeat attack with full command may always attack or move
    if groupSelected.mayRepeatMove && groupSelected.fullCommand {(adjustCorps, adjustInd) = (-1, -1)}

    var corpsOrders = ordersLeft.0 - adjustCorps
    var indOrders = ordersLeft.1 - adjustInd
    
    // Check for unique unit combinations (leader assigned or single unassigned unit)
    if groupSelected.command.hasLeader && groupSelected.command.theLeader!.assigned != "None" {corpsOrders = 0}
    else if groupSelected.command.hasLeader && groupSelected.command.theLeader!.assigned == "None" && groupSelected.command.OneSelectableOnlyWithLeader() {corpsOrders = 0; indOrders = 0}

    var attachMove:SelState = .Off
    var corpsMove:SelState = .Off
    var detachMove:SelState = .Off
    var independent:SelState = .Off
    
    // Free-move detector
    //var freeMove = false
    //if groupSelected.command.freeMove && groupSelected.command.turnEnteredMap == manager!.turn && groupSelected.command.moveNumber == 0 {
    //    freeMove = true
    //}
    
    // Corps move verification
    if corpsOrders > 0 {
        
        for each in commandSelected.currentLocation!.occupants {
            each.selector?.selected = .Off
            if each == commandSelected {continue}
            if CheckIfViableAttach(groupSelected, touchedUnit: nil) {attachMove = .On; each.selector?.selected = .On}
        }
        
        corpsMove = .On; detachMove = .On
        if indOrders > 0 {detachMove = .Option; independent = .On} else {independent = .NotAvail} // Default "On" state is option (1 selected) or On
        
    } else {
        corpsMove = .NotAvail; detachMove = .NotAvail; attachMove = .NotAvail
        if indOrders > 0 {independent = .On}
        else {independent = .NotAvail}
    }
    
    // Off map cannot detach or attach
    if commandSelected.currentLocationType == .Reserve && (commandSelected.currentLocation! as! Reserve).offMap! {detachMove = .Off; attachMove = .Off}
    
    // Has moved case - in which case either independent move / corps move again (or attach if there is a viable attach)
    if commandSelected.hasMoved {
        
        if commandSelected.movedVia == .IndMove {return (.Off, .Off, .Off, .On)}
        else if commandSelected.movedVia == .CorpsMove && groupSelected.fullCommand {return (.On, .Off, .Off, .Off)}
        //else {return (.Off, .Off, attachMove, .Off)}
    }
    
    // If command has finished move, return off for all (except if a single unit is selected - could happen if a unit is attached)
    /* Don't think this is used anymore
    var indUnit:Bool = false
    if unitsSelected.count == 1 && unitsSelected[0].unitType != .Ldr {indUnit = true}
    if commandSelected.finishedMove {
        if indUnit {return (.Off, .Off, attachMove, independent)}
        return (.Off, .Off, attachMove, .Off)
    }
    */
    
    let unitsHaveLeader:Bool = groupSelected.leaderInGroup
    
    // Case: 1 unit selected (most ambiguity is here)
    if unitsSelected.count <= 1 {
        
        if !commandSelected.hasLeader {return (.Off, .Off, .Off, independent)} // Independent
        else {return (.Off, detachMove, .Off, independent)}
        //else if commandSelected.unitCount == 1 {return (.Off, detachMove, .Off, independent)} // Can't attach last unit in a corps
        //else {return (.Off, detachMove, attachMove, independent)} // Independent, corps move and detach
        
    // Case: 2+ units selected, no leader, can only detach
    } else if !unitsHaveLeader {
        if detachMove == .Option {detachMove = .On}
        if unitsSelected.count < (commandSelected.activeUnits.count-1) {return (.Off, detachMove, .Off, .Off)} else {return (.Off, .Off, .Off, .Off)}
        
    // Case 3: Corps moves only (2+ units - must have leader)
    } else {
        return (corpsMove, .Off, attachMove, .Off)
    }
    
}

// Returns true (if road move), first array are viable "peaceful" moves, second array are viable "attack" moves
func MoveLocationsAvailable (groupSelected:Group, selectors:(SelState, SelState, SelState, SelState), undoOrAct:Bool = false) -> ([SKNode], [SKNode]) {
    
    // Safety Check
    guard let commandSelected = groupSelected.command else {return ([], [])}
    if groupSelected.nonLdrUnitCount == 0 {return ([], [])}
    if commandSelected.currentLocationType == .Start {return ([], [])}
    
    // Check has moved restrictions
    if groupSelected.someUnitsHaveMoved && !groupSelected.fullCommand {return ([], [])} // Return if some units moved (breaking up new commands must be done from 0-moved units)
    else if commandSelected.finishedMove && groupSelected.fullCommand == true {return ([], [])} // Command finished move - disable further movement
    
    // Determine unit size (1 or 2+)
    let unitSize:Int!
    if groupSelected.nonLdrUnitCount > 1 {unitSize = 2} else {unitSize = 1}

    // Set the scenario
    var scenario:Int = 0
    let (moveOnS, detachOnS, _, indOnS) = selectors
    let moveOn = (moveOnS == .On); let detachOn = (detachOnS == .On); let indOn = (indOnS == .On)
    
    if !(moveOn || detachOn || indOn) {return ([], [])}
    
    var isReserve:Bool = false
    var reinforcement:Bool = false
    if commandSelected.currentLocationType == .Reserve {
        isReserve = true
        reinforcement = (commandSelected.currentLocation as! Reserve).offMap
    }
    let moveNumber = commandSelected.moveNumber
    
    // Set the Scenario
    // 1 = Any move from Approach
    // 2 = Detach from reserve
    // 3 = 0 movement, 1 unit
    // 4 = 0 movement, 2 units
    // 5 = 1+ movement, 1 unit
    // 6 = 1+ movement, 2 units
    // Secondary scenario: All Cav (Cav can road-move into the approach + they can feint attack via road)
    
    if !isReserve {scenario = 1}
    else if detachOn {scenario = 2}
    else if moveNumber == 0 && unitSize == 1 {scenario = 3}
    else if moveNumber == 0 && unitSize == 2 {scenario = 4}
    else if moveNumber > 0 && unitSize == 1 {scenario = 5}
    else if moveNumber > 0 && unitSize == 2 {scenario = 6}
    else {return ([], [])}
    
    var currentReserve:Reserve?
    var currentApproach:Approach?
    
    if isReserve {currentReserve = commandSelected.currentLocation as? Reserve}
    else {currentApproach = commandSelected.currentLocation as? Approach; currentReserve = currentApproach?.ownReserve}
    
    var rdAvailableReserves:[Reserve] = []
    var rdAvailableApproaches:[Approach] = []
    var finalReserveMoves:[Reserve] = [] // Stores whether the potential move is a final move
    var adjAvailableReserves:[Reserve] = []
    var adjAvailableApproaches:[Approach] = []
    var enemyOccupiedAttackApproaches:[Approach] = []
    var enemyOccupiedMustFeintApproaches:[Approach] = []
    var rdBlock = false
    
    switch scenario {
        
    case 1:
        adjAvailableReserves += [currentApproach!.ownReserve!]
        if currentApproach!.adjReserve != nil {adjAvailableReserves += [currentApproach!.adjReserve!]}
        
    case 2:
        break // Handled below
        
    case 3:
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(groupSelected, twoPlusCorps: false)}
        
    case 4:
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(groupSelected, twoPlusCorps: true)}
        
    default: break
        
    }
    
    // Ensures that reinforcements are in rd-move mode
    if reinforcement && scenario == 3 {scenario = 5}
    else if reinforcement && scenario == 4 {scenario = 6}
    
    if scenario == 5 || scenario == 6 {
        
        let (theReserves, _, theRdBlock) = GroupMayMoveByRd(groupSelected)
        rdBlock = theRdBlock
        rdAvailableReserves = Array(Set(theReserves)) // Ensure the array is unique
        
    }
    
    // All reserve scenarios
    if scenario > 1 {
     
        for eachAdjReserve in currentReserve!.adjReserves {
            
            // This checks if it is likely and end-rd move
            for eachReservePath in currentReserve!.rdReserves {
                if eachReservePath.contains(eachAdjReserve) && moveNumber < eachReservePath.count-2 {finalReserveMoves += [eachAdjReserve]}
            }
            
            if !eachAdjReserve.has2PlusCorpsPassed {adjAvailableReserves += [eachAdjReserve]}
        }
        
        // Need to take those without a road as the "final" group
        finalReserveMoves = Array(Set(adjAvailableReserves).subtract(Set(finalReserveMoves))) // Ensure the array is unique
    }
    
    // Set reserve's approaches as adjacent available approaches for those who haven't moved
    if scenario == 2 || scenario == 3 || scenario == 4 {
        for each in currentReserve!.ownApproaches {adjAvailableApproaches += [each]}
    }
    
    // Move each enemy occupied adj move into the Attack bucket
    if (scenario == 1 || scenario == 2 || scenario == 3 || scenario == 4) {
        
        for each in adjAvailableReserves {
            if (manager!.actingPlayer.ContainsEnemy(each.localeControl)) {
            adjAvailableReserves.removeObject(each)
                if let defenseApproach = ApproachesFromReserves(currentReserve!, reserve2: each) {
                    if defenseApproach.1.threatened {continue} // Skip approaches already threatened
                    enemyOccupiedAttackApproaches += [defenseApproach.1]
                }
            }
        }
    }
    
    if !rdBlock && !(scenario == 1) && (scenario == 5 || (scenario == 6 && !(currentReserve!.containsAdjacent2PlusCorps == manager?.actingPlayer.Other()))) && !currentReserve!.offMap {
        
        // Allows Cav to move into the approach of a moved-into locale
        if groupSelected.allCav && !undoOrAct {
            if let reserve1 = commandSelected.rdMoves[moveNumber-1] as? Reserve {
                if let reserve2 = commandSelected.rdMoves[moveNumber] as? Reserve {
                    rdAvailableApproaches = CavApproaches(reserve1, currentReserve: reserve2)
                }
            }
        }
    }
    
    if moveNumber > 0 || reinforcement {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units (approaches too)
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(rdAvailableReserves))) {
            if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {
                rdAvailableReserves.removeObject(eachReserve)
                for eachApproach in eachReserve.ownApproaches {rdAvailableApproaches.removeObject(eachApproach)}
            }
        }
        
        let rdMoves = rdAvailableReserves as [SKNode] + rdAvailableApproaches as [SKNode]
        for each in rdMoves {each.hidden = false; each.zPosition = 200}
        
        if reinforcement {
        
            let mustFeintThreats = enemyOccupiedMustFeintApproaches as [SKNode]
            for each in mustFeintThreats {each.hidden = false; each.zPosition = 200}
            return (rdMoves, mustFeintThreats)

        } else {return (rdMoves, [])}
        
    } else {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(adjAvailableReserves))) {if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {adjAvailableReserves.removeObject(eachReserve)}}
        
        let adjMoves = adjAvailableReserves as [SKNode] + adjAvailableApproaches as [SKNode]
        
        // Remove approaches already attacked by normal attack
        for eachApproach in enemyOccupiedAttackApproaches {if !eachApproach.mayNormalAttack {enemyOccupiedAttackApproaches.removeObject(eachApproach)}}
        for eachApproach in enemyOccupiedMustFeintApproaches {if !eachApproach.mayNormalAttack {enemyOccupiedMustFeintApproaches.removeObject(eachApproach)}}
        
        let attackThreats = enemyOccupiedAttackApproaches as [SKNode]
        let mustFeintThreats = Array(Set(enemyOccupiedMustFeintApproaches).subtract(Set(enemyOccupiedAttackApproaches))) as [SKNode]
        //for each in (adjMoves + attackThreats + mustFeintThreats) {each.hidden = false; each.zPosition = 200}
        
        // Night turn or all general attacks made no attacks allowed
        if manager!.night || manager!.generalThreatsMade >= 2 {
            return (adjMoves, [])
        
        // Commit phase or fixed art, only attacks allowed
        } else if manager!.phaseNew == .Commit || groupSelected.someUnitsFixed {
            return ([],  attackThreats + mustFeintThreats)
            
        // Move phase, both attacks and moves allowed
        } else {
            return (adjMoves,  attackThreats + mustFeintThreats)
        }
        
    }
}

func CheckIfViableAttach(groupSelected:Group, touchedUnit:Unit?) -> Bool {
    
    //guard let touchedCommand = touchedUnit.parent as? Command else {return false}
    guard let commandSelected = groupSelected.command else {return false}
    var differentCommandSameLocation = false
    if touchedUnit != nil {
        let touchedCommand = touchedUnit!.parentCommand!
        if touchedCommand != commandSelected && touchedCommand.currentLocation == commandSelected.currentLocation && touchedCommand.activeUnits.count != 2 && touchedUnit!.unitType != .Ldr {
            differentCommandSameLocation = true
        }
    } else {
        differentCommandSameLocation = true
    }
    
    //guard let unitsSelected = groupSelected.units else {return false}
    //var viableCommandSelected = false
    //var viableTouchedSelected = false
    
    // Check if selected command is viable
    if groupSelected.fullCommand && differentCommandSameLocation && groupSelected.leaderInGroup {return true} else {return false}
    //else if commandSelected.unitCount == 1 && commandSelected.activeUnits[0].unitType != .Ldr {viableCommandSelected = true}
    
    //Check if touched command is viable
    //if !((touchedCommand == commandSelected) || (touchedCommand.currentLocation != commandSelected.currentLocation) || touchedCommand.hasLeader == false || touchedCommand.finishedMove == true) {viableTouchedSelected = true}
    
    //if viableCommandSelected && viableTouchedSelected {return true} else {return false}
    
}

func CheckIfViableGuardThreat(theThreat:Conflict) -> Bool {
    
    var corpsOnly = false
    var indOnly = false
    if theThreat.attackApproach.obstructedApproach {return false}
    else if manager!.guardFailed[theThreat.defenseSide.Other()!]! {return false}
    else if manager!.indCommandsAvail <= 0 && manager!.corpsCommandsAvail > 0 {corpsOnly = true}
    else if manager!.corpsCommandsAvail <= 0 && manager!.indCommandsAvail > 0 {indOnly = true}
    
    var viableGuard = false
    for eachCommand in theThreat.attackApproach.occupants + theThreat.attackReserve.occupants {
        for eachUnit in eachCommand.activeUnits {
            if (!corpsOnly && !indOnly) && eachUnit.unitType == .Grd && !eachUnit.hasMoved {viableGuard = true; break}
            else if corpsOnly && eachUnit.unitType == .Grd && !eachUnit.hasMoved && !eachCommand.hasMoved && eachCommand.activeUnits.count > 1 {viableGuard = true; break}
            else if indOnly && eachUnit.unitType == .Grd && !eachUnit.hasMoved && eachCommand.activeUnits.count != 2 {viableGuard = true; break}
        }
        if viableGuard {break}
    }
    
    return viableGuard
}

// MARK: Feint & Retreat Logic

// Returns groups available to defend (in reserve) and true if there are selectable defenders (false if something is on the approach or no defenders available)
func SelectableGroupsForDefense (theConflict:Conflict) -> [Group] {
    
    var theCommandGroups:[Group] = []

    if (theConflict.defenseApproach.occupantCount > 0) || !(theConflict.defenseReserve.defendersAvailable > 0) {return theCommandGroups}
    
    for eachReserveOccupant in theConflict.defenseReserve.occupants {
        
        if eachReserveOccupant.availableToDefend.count > 0 {

            // Commanded units
            if eachReserveOccupant.hasLeader {

                let selectedUnits = eachReserveOccupant.availableToDefend + [eachReserveOccupant.theLeader!]
                if selectedUnits.count > 0 {theCommandGroups += [Group(theCommand: eachReserveOccupant, theUnits: selectedUnits)]}

            // Detached units
            } else {
                theCommandGroups += [Group(theCommand: eachReserveOccupant, theUnits: eachReserveOccupant.availableToDefend)]
            }
            
        }
    }
    
    return theCommandGroups
    
}

// Returns all the groups in the conflict reserve
func SelectableGroupsForRetreat (theConflict:Conflict) -> [Group] {

    var theCommandGroups:[Group] = []
    
    for eachCommand in theConflict.defenseReserve.occupants {theCommandGroups += [Group(theCommand: eachCommand, theUnits: eachCommand.activeUnits)]}
    
    for eachApproach in theConflict.defenseReserve.ownApproaches {
        for eachCommand in eachApproach.occupants {theCommandGroups += [Group(theCommand: eachCommand, theUnits: eachCommand.activeUnits)]}
    }
    
    return theCommandGroups

}

func ReduceStrengthIfRetreat(touchedUnit:Unit, theLocation:Location, theGroupConflict:GroupConflict, retreatMode:Bool) -> Bool {
    if !retreatMode {return false} // Not in retreat mode
    if touchedUnit.selected != .Selected {return false} // Not selected

    // Artillery Check
    var canDestroy:Bool = false
    if theGroupConflict.destroyRequired[theLocation] > theGroupConflict.destroyDelivered[theLocation] {canDestroy = true}
    //print(theGroupConflict.destroyDelivered[theLocation])
    if touchedUnit.unitType == .Art && canDestroy {return true}
    
    // Other Units Check
    var canReduce:Bool = false
    if theGroupConflict.damageRequired[theLocation] > theGroupConflict.damageDelivered[theLocation] {canReduce = true}
    
    if theLocation is Approach {
        let viableReduce:Bool = touchedUnit.unitType == .Inf || touchedUnit.unitType == .Cav || touchedUnit.unitType == .Grd
        if canReduce && viableReduce {return true}
    } else if theLocation is Reserve {
        let viableReduce:Bool = touchedUnit.unitType == .Inf || touchedUnit.unitType == .Grd
        if canReduce && viableReduce {return true}
    }
    return false
}

// Returns whether retreat state is ready (on) or still requires action (option)
func CheckRetreatViable(retreatGroup:[Group]) -> SelState {
    
    for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
    let retreatSelection = GroupSelection(theGroups: retreatGroup)
    if retreatSelection.blocksSelected == 0 {return .Option}
    
    // Check if reductions are finished for selected units locations
    for eachGroup in retreatGroup {
        for eachUnit in eachGroup.units {
            if eachUnit.selected == .Selected && activeGroupConflict!.damageDelivered[eachGroup.command.currentLocation!] < activeGroupConflict!.damageRequired[eachGroup.command.currentLocation!] {return .Option}
            if eachUnit.selected == .Selected && activeGroupConflict!.destroyDelivered[eachGroup.command.currentLocation!] < activeGroupConflict!.destroyRequired[eachGroup.command.currentLocation!] {return .Option}
        }
    }
    
    // Load attacked reserves
    let attackedReserve = activeConflict!.attackReserve
    
    // Load reserves where available area is sufficient
    var adjReservesWithSpace:[Reserve] = []
    var spaceRequired = retreatSelection.blocksSelected
    if retreatSelection.containsLeader {spaceRequired--}
    for eachReserve in activeGroupConflict!.defenseReserve.adjReserves {
        if eachReserve.availableSpace >= spaceRequired && eachReserve.localeControl != manager!.actingPlayer.Other() {adjReservesWithSpace += [eachReserve]}
    }
    
    // Reveal available retreat reserves
    var returnOn:Bool = false
    manager!.selectionRetreatReserves = Array(Set(adjReservesWithSpace).subtract(Set([attackedReserve])))
    for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = false; returnOn = true}

    if returnOn {return .On} else {return .NotAvail}
}

// Returns "TurnOnRetreat", "TurnOnSurrender" or "TurnOnDefend" plus sets selectable group
func ConflictSelectDuringDefensePhase() -> String {
    
    if activeConflict == nil {return "TurnOnNothing"}
    
    // Grey-out all commands
    ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelection: .NotSelectable)
    
    // Must defend? (already gave a defense order)
    if activeGroupConflict!.mustDefend {
        activeGroupConflict!.retreatMode = false
        
        return "TurnOnDefendOnly"
    }
    
    // Space available? (retreat or no order) - this will return the destroy case (true, true)
    var spaceAvailable:Bool = false
    for eachReserve in activeGroupConflict!.defenseReserve.adjReserves {
        if eachReserve.availableSpace > 0 && eachReserve.localeControl != manager!.phasingPlayer {spaceAvailable = true; break}
    }

    // No space available case
    if !spaceAvailable {
        
        // No space, must-retreat (no-one to defend with)
        if activeGroupConflict!.mustRetreat {
            activeGroupConflict!.retreatMode = true
            return "TurnOnSurrender"
        }
        
        // Not in must-retreat mode
        else {
            activeGroupConflict!.retreatMode = false
            return "TurnOnDefendOnly"
        }
    }
    
    // No command was given, check if there is any unresolved approaches
    //if activeGroupConflict!.unresolvedApproaches.count == 0 && manager!.phaseNew != .PostCombatRetreatAndVictoryResponseMoves {
    //    return (false, true)
    //}
    
    // Retreat command was given and space exists
    if activeGroupConflict!.mustRetreat {
        activeGroupConflict!.retreatMode = true
        return "TurnOnRetreatOnly"
    }
    
    // No command was given, check if there is enough defenders available
    //if activeGroupConflict!.unresolvedApproaches.count > theThreat.defenseReserve.defendersAvailable {return (true, false)}
    //print(theThreat.madeReductions)
    
    // If you make it through, neither is forced (no command given)
    return "TurnOnBoth"
}

// Returns true if endTurn is viable
func CheckEndTurnStatusInRetreatOrDefenseSelection() -> Bool {
    
    var endTurnViable = true
    for eachLocaleThreat in manager!.localeThreats {
     
        if eachLocaleThreat.retreatMode {
            if eachLocaleThreat.defenseReserve.currentFill > 0 {
                endTurnViable = false
                for eachConflict in eachLocaleThreat.conflicts {
                    eachConflict.defenseApproach.approachSelector!.selected = .NotAvail
                }
            } else {
                for eachConflict in eachLocaleThreat.conflicts {
                    eachConflict.defenseApproach.approachSelector!.selected = .On
                }
            }
        } else {
            if eachLocaleThreat.unresolvedApproaches.count > 0 && eachLocaleThreat.defenseReserve.defendersAvailable > 0 {
                endTurnViable = false
            }
            for eachConflict in eachLocaleThreat.conflicts {
                if eachConflict.approachDefended {
                    eachConflict.defenseApproach.approachSelector!.selected = .On
                } else {
                    eachConflict.defenseApproach.approachSelector!.selected = .NotAvail
                }
            }
        }
        
    }
    return endTurnViable
}

func AdjacentThreatPotentialCheck (touchedNodePassed:SKNode, commandOrdersAvailable:Bool, independentOrdersAvailable:Bool) -> Bool {
    guard let approachAttacked = touchedNodePassed as? Approach else {return false}
    
    for eachCommand in approachAttacked.oppApproach!.occupants {
        if eachCommand.hasLeader && commandOrdersAvailable {return true}
        if !eachCommand.hasLeader && independentOrdersAvailable {return true}
    }
    for eachCommand in approachAttacked.oppApproach!.ownReserve!.occupants {
        if eachCommand.hasLeader && commandOrdersAvailable {return true}
        if !eachCommand.hasLeader && independentOrdersAvailable {return true}
    }
    
    return false
}

// MARK: Commit Logic

func SelectableGroupsForAttackByRoad (theConflict:Conflict) -> [Group]  {
    
    // Catches rare case of a repeat attack along the road
    //if manager!.repeatAttackGroup != nil {
    //    return [manager!.repeatAttackGroup!]
    //}
    
    var theCommandGroups:[Group] = []
    //let corpsMovesAvailable = manager!.indCommandsAvail > 0
    //let independentMovesAvailable = manager!.corpsCommandsAvail > 0

    for (eachCommand, _) in theConflict.potentialRdAttackers {
        
        let availableCavUnits = eachCommand.cavUnits.filter{$0.hasMoved == false}
        
        if availableCavUnits.count > 0 {
            if eachCommand.hasLeader {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableCavUnits + [eachCommand.theLeader!])]}
            else {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableCavUnits)]}
        }
        /*
        // Leader case
        if corpsMovesAvailable && eachCommand.hasLeader && eachCommand.cavUnits.count > 0 && !eachCommand.finishedMove {
            let availableCavUnits = eachCommand.cavUnits.filter{$0.hasMoved == false}
            if availableCavUnits.count > 0 {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableCavUnits + [eachCommand.theLeader!])]}
        }
        // Ind case (highlight the cav)
        else if independentMovesAvailable && eachCommand.cavUnits.count > 0 {
            let availableCavUnits = eachCommand.cavUnits.filter{$0.hasMoved == false}
            if availableCavUnits.count > 0 && eachCommand.activeUnits.count != 2 {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableCavUnits + [eachCommand.theLeader!])]}
        }
    }
        */
    }
    return theCommandGroups
}

func SelectableGroupsForAttackAdjacent(theConflict:Conflict) -> [Group] {
    
    // Catches rare case of a repeat attack along the road
    //if manager!.repeatAttackGroup != nil {
    //    return []
    //}
    
    var theCommandGroups:[Group] = []
    //let corpsMovesAvailable = manager!.indCommandsAvail > 0
    //let independentMovesAvailable = manager!.corpsCommandsAvail > 0

    for eachCommand in (theConflict.attackApproach.occupants + theConflict.attackReserve.occupants) {
        
        let availableUnits = eachCommand.nonLeaderUnits.filter{$0.hasMoved == false}
        
        if availableUnits.count > 0 {
            if eachCommand.hasLeader {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableUnits + [eachCommand.theLeader!])]}
            else {theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableUnits)]}
        }
        
        /*
        // Leader case
        if corpsMovesAvailable && eachCommand.hasLeader && !eachCommand.finishedMove {
            
            if availableUnits.count > 0 {
                theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableUnits + [eachCommand.theLeader!])]
            }
        }
        // Ind case (highlight the units)
        else if independentMovesAvailable {
            let availableUnits = eachCommand.nonLeaderUnits.filter{$0.hasMoved == false}
            if availableUnits.count > 0 && eachCommand.activeUnits.count != 2 {
                theCommandGroups += [Group(theCommand: eachCommand, theUnits: availableUnits + [eachCommand.theLeader!])]
            }
        }
        */
    }
    return theCommandGroups
}

func OrdersAvailableOnAttack (groupsSelected:[Group], ordersLeft:(Int, Int), theConflict:Conflict) -> (SelState, SelState, SelState, SelState) {
    
    // Safety drill
    if groupsSelected.isEmpty {return (.Off, .Off, .Off, .Off)}
    if groupsSelected[0].command.moveNumber > 0 {
        switch (groupsSelected[0].command.movedVia) {
            case .CorpsMove: return (.On, .Off, .Off, .Off)
            case .IndMove: return (.Off, .Off, .Off, .On)
            default: return (.On, .Off, .Off, .Off)
        }
    }
    
    var corpsMove:SelState = .On
    var detachMove:SelState = .On
    var independent:SelState = .On
    
    if groupsSelected[0].command.finishedMove {
        corpsMove = .Off
        detachMove = .Off
    }
    
    // Deals with reinforcement free-moves
    var freeCorps = 0
    var freeInd = 0
    for eachGroup in groupsSelected {
        if eachGroup.command.freeMove && eachGroup.command.turnEnteredMap == manager!.turn && eachGroup.command.moveNumber == 0 {
            if eachGroup.leaderInGroup {freeCorps++}
            if eachGroup.nonLdrUnitCount == 1 && eachGroup.command.activeUnits.count != 2 {freeInd++}
        }
    }
    
    let corpsOrders = ordersLeft.0 + freeCorps
    let indOrders = ordersLeft.1 + freeInd
    
    if groupsSelected.count > 1 { // Attack mode, multi selections
        
        if groupsSelected[0].fullCommand && groupsSelected[0].units[0].unitType == .Art {
            return (.Off, .Off, .Off, independent)
        } else {
            return (corpsMove, .Off, .Off, .Off)
        }
        
    // Usual case (1 group)
    } else if groupsSelected.count == 1 {
        
        // Order constraints
        if corpsOrders < 1 {corpsMove = .NotAvail; detachMove = .NotAvail}
        if indOrders < 1 {independent = .NotAvail}
        let theGroup = groupsSelected[0]
        
        let theLocation = theGroup.command.currentLocation
        var adjacentLocation = false
        if theLocation is Approach {
            adjacentLocation = true
        } else {
            if (theLocation as! Reserve) == theConflict.attackReserve {adjacentLocation = true}
        }
        
        // Capacity constraints
        if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
            
            if theGroup.nonLdrUnits.count > theConflict.attackReserve.availableSpace {return (.Off, .Off, .Off, .Off)}
            
        } else {
        
            if theGroup.nonLdrUnits.count > theConflict.defenseReserve.capacity {return (.Off, .Off, .Off, .Off)}
        
        }
        
        if theGroup.nonLdrUnits.count > 1 {
            
            switch (theGroup.leaderInGroup, adjacentLocation) {
                
            case (true, false):
                
                var rdBlocked = true
                if !adjacentLocation {rdBlocked = AttackByRdPossible(theConflict.RdCommandPathToConflict(theGroup.command), twoPlusCorps: true)}
                
                if !rdBlocked {return (corpsMove, .Off, .Off, .Off)}
                else {return (.Off, .Off, .Off, .Off)}
                
            case (false, false): return (.Off, .Off, .Off, .Off)
                
            case (true, true): return (corpsMove, .Off, .Off, .Off)
                
            case (false, true): return (.Off, detachMove, .Off, .Off)
                
            }
            
        } else {
            
            var rdBlocked = true
            if !adjacentLocation {rdBlocked = AttackByRdPossible(theConflict.RdCommandPathToConflict(theGroup.command), twoPlusCorps: false)}
            
            if theGroup.fullCommand {return (.Off, .Off, .Off, independent)}
            
            switch (theGroup.leaderInGroup, adjacentLocation) {
                
            case (true, false):
                
                if !rdBlocked {return (corpsMove, .Off, .Off, .Off)}
                else {return (.Off, .Off, .Off, .Off)}
                
            case (false, false):
                
                if !rdBlocked {return (.Off, .Off, .Off, independent)}
                else {return (.Off, .Off, .Off, .Off)}
                
            case (true, true): return (corpsMove, .Off, .Off, .Off)
                
            case (false, true):
                
                if indOrders > 0 && corpsOrders > 0 && detachMove != .Off {detachMove = .Option}
                return (.Off, detachMove, .Off, independent)
                
            }
        }
    }
    return (.Off, .Off, .Off, .Off)
}

func AttackMoveLocationsAvailable(theGroup:Group, selectors:(SelState, SelState, SelState, SelState), feint:Bool, theConflict:Conflict, undoOrAct:Bool = false) -> [SKNode] {
    
    // Safety drill
    let (moveOnS, detachOnS, _, indOnS) = selectors
    if moveOnS != .On && detachOnS != .On && indOnS != .On {return []}
    
    // Establish whether the group is adjacent
    let moveNumber = theGroup.command.moveNumber
    let theLocation = theGroup.command.currentLocation
    var adjacentLocation = false
    var onApproach = false
    var theReserve:Reserve?
    
    if theLocation is Approach {
        adjacentLocation = true
        onApproach = true
    } else {
        theReserve = (theLocation as! Reserve)
        if theReserve == theConflict.attackReserve {adjacentLocation = true}
        if moveNumber == 0 {theConflict.rdAttackerMultiPaths = theReserve!.rdReserves} // Sets the pathways
    }
    
    let theReserveAsSKNode = theConflict.attackReserve as SKNode
    let theApproachAsSKNode = theConflict.attackApproach as SKNode
    
    switch (adjacentLocation, feint, false) { // Elminate 3rd piece
        
    case (true, true, false):
        
        if theGroup.command.finishedMove && moveNumber == 0 && !(theGroup.units.count == 1 && !theGroup.units[0].hasMoved) {
            return []
        } // Made an in-place move
        else if moveNumber == 0 && !onApproach {return [theReserveAsSKNode, theApproachAsSKNode]}
        else if moveNumber == 0 && onApproach {return [theApproachAsSKNode]} // Hasn't moved
        else if !theGroup.command.finishedMove {return [theApproachAsSKNode]} // Moved in from outside
        else {return []} // Should never get here...
        
    case (true, false, false):
        
        // Allows artillery to stay still
        if (detachOnS == .On || indOnS == .On) && theGroup.artOnly && onApproach {return [theConflict.defenseReserve, theApproachAsSKNode]}
        else {return [theConflict.defenseReserve as SKNode]} // the normal case
        
    case (false, _, false):
        
        let thePath:[Reserve]!
        if theGroup.command.moveNumber == 0 {
            thePath = theConflict.potentialRdAttackers[theGroup.command]!
            theConflict.rdAttackerPath = thePath
        }
        else {thePath = theConflict.rdAttackerPath}
        
        let theEnd = thePath.count - 1
        var theMoveOptions:[SKNode] = []
        
        if feint && (theEnd - moveNumber <= 1) { // Final step in feint-mode
            return [theApproachAsSKNode as SKNode]
        } else if !feint && (theEnd - moveNumber <= 0) { // Final step in feint-mode
            return []
        } else {
            
            if thePath[moveNumber] != theGroup.command.currentLocation {break}
            theMoveOptions += [thePath[moveNumber+1] as SKNode]
            
            return theMoveOptions // Add something to show it isn't at the end yet?
        }
        
    case (false, false, true):
        
        // Possible move locations after moving into a retreat locale
        var theMoveOptions:[SKNode] = []
        let (theReserves, theApproaches, rdBlock) = GroupMayMoveByRd(theGroup, twoPlusCorps:(theGroup.nonLdrUnitCount > 1), mustBeCav: true)
        
        if !rdBlock {
            theMoveOptions += EnemyRdTargets(theGroup, twoPlusCorps:(theGroup.nonLdrUnitCount > 1)) as [SKNode]
            theMoveOptions += CavApproaches(theGroup.command.rdMoves[moveNumber-1] as! Reserve, currentReserve:theReserve!) as [SKNode]
        }
        
        return theReserves as [SKNode] + theApproaches as [SKNode] + theMoveOptions
        
    case (false, true, true):
        
        // Possible final moves for a continuation attack
        var theMoveOptions:[SKNode] = []
        if theReserve == theConflict.attackReserve {
            theMoveOptions = [theConflict.attackApproach as SKNode]
        } else {
            theMoveOptions = [theConflict.attackReserve as SKNode]
        }
        
        return theMoveOptions
        
    default: break
        
    }
    return []
    
}

// Pass it a 2D array of reserve pathways, returns true if 2Plus Corps can rd move with it (checks the three rd conditions plus whether enemy occupied)
func AttackByRdPossible(thePath:[Reserve], twoPlusCorps:Bool) -> Bool {

    if thePath.isEmpty {return false}
    var rdBlocked = false
    
    for var i = 1; i < thePath.count-1; i++ {
        
        if twoPlusCorps {
            if thePath[i].commandsEntered.count > 0 || thePath[i].containsAdjacent2PlusCorps == .Both || thePath[i].containsAdjacent2PlusCorps == thePath.last?.localeControl || thePath[i].has2PlusCorpsPassed || thePath[i].localeControl == thePath.last?.localeControl {
                rdBlocked = true
                break
            }
        } else {
            if thePath[i].has2PlusCorpsPassed || thePath[i].localeControl == thePath.last?.localeControl {
                rdBlocked = true
                break
            }
        }

    }
    
    return rdBlocked
}

// Returns true if endTurn is viable
func CheckTurnEndViableInCommitMode(theThreat:Conflict, endLocation:Location) -> Bool {
    
    let targetReserve:Reserve!
    let targetApproach:Approach!
    
    switch (manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare, true) {
        
    case (true, true):
        
        return false
        
    case (true, false):
        
        return true
        
    case (false, _):
        
        targetReserve = theThreat.attackReserve; targetApproach = theThreat.attackApproach
        if endLocation is Reserve && (endLocation as! Reserve) == targetReserve {return true}
        if endLocation is Approach && (endLocation as! Approach) == targetApproach {return true}
        
    default: break
        
    }
    
    return false
}

// MARK: Defense Logic

func SelectableGroupsForFeintDefense (theThreat:Conflict) {
    
    // Safety drill
    if theThreat.defenseGroup!.groups.isEmpty {return}
    ToggleGroups(GroupsIncludeLeaders(theThreat.defenseGroup!.groups), makeSelection: .Normal)
}

// Order to defend

func SaveDefenseGroup(theGroupThreat:GroupConflict) {
    
    // Safety drill
    
    if activeConflict == nil {return} // Approach conflicts do not get extra defenders
    
    let defenseSelection = GroupSelection(theGroups: manager!.groupsSelectable)
    
    activeConflict!.defenseGroup = defenseSelection
    activeConflict!.parentGroupConflict!.defendedApproaches += [activeConflict!.defenseApproach]
    defenseSelection.SetGroupSelectionPropertyUnitsHaveDefended(true, approachDefended: activeConflict!.defenseApproach)
    
    activeConflict!.parentGroupConflict!.defenseOrders++
    activeConflict!.parentGroupConflict!.mustDefend = true
    
    //manager!.ResetRetreatDefenseSelection()
    
}

// Returns true if endTurn is viable
func CheckTurnEndViableInDefenseMode(theThreat:Conflict) -> Bool {
    
    //print(theThreat.defenseApproach.occupantCount)
    return theThreat.defenseApproach.occupantCount > 0
}

// MARK: Leading Units Logic

func SelectableLeadingGroups (theConflict:Conflict, thePhase:newGamePhase, resetState:Bool = false) -> [Unit] {
    
    var theGroups:[Group] = []
    switch thePhase {
    case .SelectDefenseLeading: theGroups = theConflict.defenseGroup!.groups
    case .SelectAttackLeading:
        if theConflict.guardAttack {theGroups = theConflict.guardAttackGroup!.groups}
        else {theGroups = theConflict.attackGroup!.groups}
    case .SelectCounterGroup: theGroups = theConflict.counterAttackGroup!.groups
    default: break
    }
    
    // Sequence removes the cav in the case of an obstructed defense approach
    if theConflict.defenseApproach.obstructedApproach {
        var newGroups:[Group] = []
        for eachGroup in theGroups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                if eachUnit.unitType != .Cav {
                    theUnits += [eachUnit]
                }
            }
            if !theUnits.isEmpty {newGroups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]}
        }
        theGroups = newGroups
    }
    
    // Safety drill
    if theGroups.isEmpty {return []}
    
    let selectedLeadingGroups:GroupSelection!
    if resetState {
        selectedLeadingGroups = GroupSelection(theGroups: [])
    } else {
        selectedLeadingGroups = GroupSelection(theGroups: theGroups)
    }
    
    ToggleGroups(theGroups, makeSelection: .Normal)
    
    switch thePhase {
        
    case .SelectDefenseLeading: theConflict.defenseLeadingUnits = selectedLeadingGroups
    case .SelectAttackLeading: theConflict.attackLeadingUnits = selectedLeadingGroups
    case .SelectCounterGroup: theConflict.counterAttackLeadingUnits = selectedLeadingGroups
    
    default: break
    }
    
    var attackLeadingArtPossible = false
    if (theGroups[0].command.currentLocation == theConflict.attackApproach) && theConflict.attackMoveType != .CorpsMove && (theConflict.attackApproach.turnOfLastArtVolley < manager!.turn - 1 || (theConflict.attackApproach.hillApproach && !theConflict.defenseApproach.hillApproach)) && theConflict.defenseApproach.mayArtAttack {attackLeadingArtPossible = true}

    // Three scenarios: Defense Leading, Attack Leading and Counter Attacking
    // APPROACH?, # BLOCKS SELECTED, WIDE?, LEADING D - LEADING A OR COUNTERATTACK?
    // .SelectDefenseLeading, .DeclaredAttackers, .SelectCounterGroup
    switch (theConflict.approachConflict, selectedLeadingGroups.blocksSelected, theConflict.wideBattle, manager!.phaseNew) {
        
    case (_, 1, false, .SelectDefenseLeading), (_, 1, false, .SelectAttackLeading):
        
        ToggleGroups(theGroups, makeSelection: .NotSelectable)
        
    case (_, 2, _, _):
        
        ToggleGroups(theGroups, makeSelection: .NotSelectable)
        
    case (true, 0...1, true, .SelectDefenseLeading): break
        
    case (false, 0, _, .SelectDefenseLeading),(_, 0, _, .SelectCounterGroup):
        
        for eachGroup in theGroups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitStrength == 1 || (manager!.phaseNew == .SelectCounterGroup && theConflict.conflictInitialWinner == theConflict.defenseSide && eachUnit.unitType != .Cav) {
                    eachUnit.selected = .NotSelectable
                }
            }
        }
        
    case (_, 0, _, .SelectAttackLeading):
        
        for eachGroup in theGroups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitStrength == 1 {
                    if !(eachUnit.unitType == .Art && attackLeadingArtPossible) {eachUnit.selected = .NotSelectable}
                }
            }
        }
        
    case (false, 1, true, .SelectDefenseLeading):
            
        let selectedGroup = selectedLeadingGroups.groups[0]
        
        for eachGroup in theGroups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitStrength == 1 || eachUnit.parentCommand! != selectedGroup.command {
                    eachUnit.selected = .NotSelectable
                } else if selectedGroup.units[0].unitType == .Inf || selectedGroup.units[0].unitType == .Grd {
                    if !(eachUnit.unitType == .Inf || eachUnit.unitType == .Grd) {eachUnit.selected = .NotSelectable}
                } else if eachUnit.unitType != selectedGroup.units[0].unitType {
                    eachUnit.selected = .NotSelectable
                }
            }
        }
        
    case (_, 1, true, .SelectAttackLeading):
        
        let selectedGroup = selectedLeadingGroups.groups[0]
        
        for eachGroup in theGroups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitType == .Art && attackLeadingArtPossible && (eachUnit.unitType == selectedGroup.units[0].unitType) {
                    // Remains selectable
                } else if eachUnit.unitStrength == 1 {
                    eachUnit.selected = .NotSelectable
                } else if eachUnit.unitType != selectedGroup.units[0].unitType {
                    eachUnit.selected = .NotSelectable
                }
            }
        }
        
    case (_, 1, _, .SelectCounterGroup):
        
        let selectedGroup = selectedLeadingGroups.groups[0]
        
        for eachGroup in theGroups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitStrength == 1 || eachUnit.parentCommand! != selectedGroup.command || (manager!.phaseNew == .SelectCounterGroup && theConflict.conflictInitialWinner == theConflict.defenseSide && eachUnit.unitType != .Cav) {
                    eachUnit.selected = .NotSelectable
                } else if eachUnit.unitType != selectedGroup.units[0].unitType {
                    eachUnit.selected = .NotSelectable
                }
            }
        }
        
    default: break
        
    }
    
    ToggleGroups(selectedLeadingGroups.groups, makeSelection: .Selected)
    return SelectableUnits(theGroups)
}

// MARK: Toggle Selections

func ToggleCommands(theCommands:[Command], makeSelection:SelectType = .Normal) {
    
    for eachCommand in theCommands {
        //eachCommand.selectable = makeSelectable
        for eachUnit in eachCommand.activeUnits {eachUnit.selected = makeSelection}
    }
}

func ToggleGroups(theGroups:[Group], makeSelection:SelectType = .Normal) {
    
    for eachGroup in theGroups {
        if makeSelection == .Normal || makeSelection == .Selected {eachGroup.command.selectable = true} else {eachGroup.command.selectable = false}
        for eachUnit in eachGroup.units {if eachGroup.command.selectable {eachUnit.selected = makeSelection} else {eachUnit.selected = makeSelection}}
    }
}

func ActivateDetached(theReserve:Reserve, theGroups:[Group], makeSelection:SelectType = .Normal) {
    for eachGroup in theGroups {
        if !eachGroup.command.hasLeader && eachGroup.command.currentLocation == theReserve {ToggleGroups([eachGroup], makeSelection: makeSelection)}
    }
}

// MARK: Road Movement Support

func CavApproaches(previousReserve:Reserve, currentReserve:Reserve) -> [Approach] {
    
    var targetApproaches:[Approach] = []
    
    for eachPath in previousReserve.rdReserves {
        
        if eachPath[1] == currentReserve {
            //var moveFromApproach:Approach
            if let moveFromApproach = ApproachesFromReserves(eachPath[1], reserve2: eachPath[2]) {targetApproaches += [moveFromApproach.0]}
            if let moveFromApproach2 = ApproachesFromReserves(eachPath[1], reserve2: eachPath[0]) {targetApproaches += [moveFromApproach2.0]}
        }
    }
    return Array(Set(targetApproaches))
}

// Returns the active paths of a command and where it is on those paths
func ActivePaths(commandSelected:Command) -> ([[Reserve]],[Int]) {
    
    var rdIndices:[Int] = []
    var currentPath:[Reserve] = []
    var paths:[[Reserve]] = []
    let moveSteps:Int = commandSelected.moveNumber
    
    // Handles the approach case and hasn't moved yet case
    if commandSelected.currentLocationType != .Reserve {return ([],[])}
    else if moveSteps == 0 {
        let theRdReserves = (commandSelected.currentLocation as! Reserve).rdReserves
        var theRdReserveIndices:[Int] = []
        for _ in theRdReserves {theRdReserveIndices += [0]}
        return (theRdReserves, theRdReserveIndices)
    }
    
    // Return empty if any approaches, otherwise turn rdMoves into an array of reserves
    for each in commandSelected.rdMoves {
        //print(each.name!)
        if each is Reserve {currentPath += [each as! Reserve]} else {return ([],[])}
    }
    
    let rdAvailableReserves = currentPath[0].rdReserves
    
    for eachPath in rdAvailableReserves {
        
        var rdIndex:Int = 0
        
        for var i = 1; i <= moveSteps; i++ {
            
            if rdIndex == 0 && i == 1 {
                if currentPath[i] == eachPath[i] {rdIndex++}
                else {break}
            }
            if rdIndex == 1 && i == 2 {
                if currentPath[i] == eachPath[i-2] {rdIndex--}
                else if currentPath[i] == eachPath[i] {rdIndex++}
                else {rdIndex = 0; break}
            }
            if rdIndex == 0 && i == 3 {
                if currentPath[i] == eachPath[i-2] {rdIndex++}
                else {rdIndex = 0; break}
            }
            if rdIndex == 2 && i == 3 {
                if currentPath[i] == eachPath[i-2] {rdIndex--}
                else if currentPath[i] == eachPath[i] {rdIndex++}
                else {rdIndex = 0; break}
            }
            
            if moveSteps < eachPath.count {paths += [eachPath]; rdIndices += [rdIndex]} // if it makes it through the gauntlet, add it to the paths array
        }
    }
    return (paths, rdIndices)
}

func EnemyRdTargets(theGroup:Group, twoPlusCorps:Bool = false) -> [Approach] {
    
    var targetApproaches:[Approach] = []

    let (thePaths, thePathPositions) = ActivePaths(theGroup.command)
    if thePaths.isEmpty {return []}
    
    let moveNumber = theGroup.command.moveNumber
    
    for (index, eachPath) in thePaths.enumerate() {
        var count = 0
        for var i = thePathPositions[index] + 1; i < eachPath.count; i++ {
            count++
            if moveNumber + count >= eachPath.count {continue}

            if eachPath[i].localeControl == manager!.actingPlayer.Other() {
                
                // Found a potential enemy to rd feint
                if let attackToApproach = ApproachesFromReserves(eachPath[i-1], reserve2: eachPath[i]) {
                
                    if (eachPath[i-1].currentFill + theGroup.nonLdrUnitCount > eachPath[i-1].capacity && eachPath[i].defendersAvailable > 0) {break}
                    if attackToApproach.1.occupantCount > 0 || attackToApproach.1.threatened {break}
                    targetApproaches += [attackToApproach.1]
                }
                break // Must break after finding an enemy (path can't go any further)
                
            } else if (!twoPlusCorps && eachPath[i].has2PlusCorpsPassed) || (twoPlusCorps && (eachPath[i].has2PlusCorpsPassed || eachPath[i].haveCommandsEntered || eachPath[i].containsAdjacent2PlusCorps == manager?.actingPlayer.Other())) {break}
            
        }
    }
    
    return targetApproaches
}

// Returns the viable reserves that the group can move to and the approaches of enemy occupied locations which would otherwise be rd-move worthy
func GroupMayMoveByRd(theGroup:Group, twoPlusCorps:Bool = false, mustBeCav:Bool = false) -> ([Reserve],[Approach],Bool) {
    
    // Safety check
    if (!theGroup.allCav && mustBeCav) || theGroup.command.finishedMove {return ([],[], true)}
    let (thePaths, pathIndices) = ActivePaths(theGroup.command)
    if thePaths.isEmpty {return([],[], true)}
    let moveNumber = theGroup.command.moveNumber
    //if moveNumber == 0 {return([],[], false)}
    if theGroup.command.currentLocationType == .Approach {return ([],[], false)}
    
    var rdAvailableReserves:[Reserve] = []
    var enemyRdAvailableApproaches:[Approach] = []
    var rdBlock = false
    
    for (i,eachPath) in thePaths.enumerate() {
        
        let pathIndex = pathIndices[i]
        
        if moveNumber < (eachPath.count-1) { // Still have moves remaining
            
            switch (twoPlusCorps) {
                
            case false:
                
                if eachPath[pathIndex].has2PlusCorpsPassed {rdBlock = true; break}
                
                if pathIndex == (eachPath.count-1) {continue} // End of path, no moves left
                else if pathIndex == 0 {  // Can go right only
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed) && !eachPath[pathIndex+1].offMap {rdAvailableReserves += [eachPath[pathIndex+1]]}
                }
                else { // Normal case
                    if !(eachPath[pathIndex-1].has2PlusCorpsPassed) && !eachPath[pathIndex-1].offMap {rdAvailableReserves += [eachPath[pathIndex-1]]}
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed) && !eachPath[pathIndex+1].offMap {rdAvailableReserves += [eachPath[pathIndex+1]]}
                }
                
            case true:
                
                if (eachPath[pathIndex].has2PlusCorpsPassed || eachPath[pathIndex].numberCommandsEntered > 1 || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex].containsAdjacent2PlusCorps)) {rdBlock = true; continue}
                
                if pathIndex == (eachPath.count-1) {continue} // End of path, no moves left
                else if pathIndex == 0 { // Can go right only
                    
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || eachPath[pathIndex+1].numberCommandsEntered > 0) && !eachPath[pathIndex+1].offMap {rdAvailableReserves += [eachPath[pathIndex+1]]}
                }
                else { // Normal case
                    
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || eachPath[pathIndex+1].numberCommandsEntered > 0) && !eachPath[pathIndex+1].offMap {rdAvailableReserves += [eachPath[pathIndex+1]]}
                    
                    if !(eachPath[pathIndex-1].has2PlusCorpsPassed || eachPath[pathIndex-1].numberCommandsEntered > 0) && !eachPath[pathIndex-1].offMap {rdAvailableReserves += [eachPath[pathIndex-1]]}
                }
                
            }
        }
    }
    
    // Convert occupied reserves to approaches for threat purposes
    for eachReserve in rdAvailableReserves {
        if manager!.actingPlayer.ContainsEnemy(eachReserve.localeControl) {
            rdAvailableReserves.removeObject(eachReserve)
            if let theApproach = ApproachesFromReserves(theGroup.command.currentLocation as! Reserve, reserve2: eachReserve) {
                enemyRdAvailableApproaches += [theApproach.0]
            }
        }
    }
    
    return (rdAvailableReserves, enemyRdAvailableApproaches, rdBlock)
}

// MARK: Support Functions

func DistanceBetweenTwoCGPoints(Position1:CGPoint, Position2:CGPoint) -> CGFloat {
    
    let x1 = Position1.x
    let y1 = Position1.y
    let x2 = Position2.x
    let y2 = Position2.y
    
    return sqrt(pow(x1-x2, 2)+pow(y1-y2, 2))
}

// Returns tuple of two neighboring approaches given two reserves (nil if no common exists)
func ApproachesFromReserves(reserve1:Reserve, reserve2:Reserve) -> (Approach,Approach)? {
    
    if reserve1.ownApproaches.isEmpty || reserve2.ownApproaches.isEmpty {return nil}
    
    for each1 in reserve1.ownApproaches {
        for each2 in reserve2.ownApproaches {
            if each1 == each2.oppApproach {return (each1, each2)}
        }
    }
    return nil // theoretically should never make it through there
}

func GroupsFromCommands(theCommands:[Command], includeLeader:Bool = false) -> [Group] {
    var theGroups:[Group] = []
    for eachCommand in theCommands {
        if includeLeader {
            let theGroup = Group(theCommand: eachCommand, theUnits: eachCommand.activeUnits)
            theGroups += [theGroup]
        } else {
            let theGroup = Group(theCommand: eachCommand, theUnits: eachCommand.nonLeaderUnits)
            theGroups += [theGroup]
        }
    }
    return theGroups
}

func GroupsIncludeLeaders(originalGroups:[Group]) -> [Group] {
    
    var theGroups:[Group] = []
    
    for eachGroup in originalGroups {
        var theUnits:[Unit] = []
        if eachGroup.command.hasLeader {
            theUnits += eachGroup.units + [eachGroup.command.theLeader!]
        } else {
            theUnits = eachGroup.units
        }
        theGroups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]
    }
    return theGroups
}

func PriorityLoss(potentialUnits:[Unit], unitLossPriority:[Int]) -> Unit? {
    
    if potentialUnits.isEmpty {return nil}
    var theLowestIndex = 7
    var indexOfTheLowestIndex = 0
    for (i, eachUnit) in potentialUnits.enumerate() {
        let theCode = eachUnit.backCodeFromStrengthAndType()
        guard let theIndex = unitLossPriority.indexOf(theCode) else {continue}
        if theIndex < theLowestIndex {theLowestIndex = theIndex; indexOfTheLowestIndex = i}
    }
    
    return potentialUnits[indexOfTheLowestIndex]
}

func SelectableUnits(theGroups:[Group]) -> [Unit] {
    
    var theUnits:[Unit] = []
    for eachGroup in theGroups {
        for eachUnit in eachGroup.units {
            if eachUnit.selected == .Normal {theUnits += [eachUnit]}
        }
    }
    return theUnits
}

// Returns the lone unit if the leader has moved and the unit did not
func CheckForOneBlockCorps(theCommand:Command?) -> Unit? {
    
    if theCommand == nil {return nil}
    var potentialUnit:Unit?
    if theCommand!.hasLeader && theCommand!.theLeader!.hasMoved && theCommand!.unitCount == 1 {
        potentialUnit = theCommand!.activeUnits.filter{$0.unitType != .Ldr}[0]
        if !potentialUnit!.hasMoved {potentialUnit!.hasMoved = true; return potentialUnit}
    }
    return nil
}


/*
func UnitsHaveLeader(units:[Unit]) -> Bool {
    for each in units {if each.unitType == .Ldr {return true}}
    return false
}
*/



