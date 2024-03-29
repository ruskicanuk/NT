
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
    if groupSelected.nonLdrUnitCount == 0 {return (.Off, .Off, .Off, .Off)}
    
    var adjustCorps:Int
    var adjustInd:Int

    // If we are in commit mode, account for phantom commands
    if manager!.phaseNew == .Commit {
        (adjustCorps, adjustInd) = (manager!.phantomCorpsCommand, manager!.phantomIndCommand)
    }
    else {(adjustCorps, adjustInd) = (0, 0)}
    
    // Repeat attack with full command may always attack or move
    if groupSelected.command!.repeatMoveNumber > 0 && groupSelected.fullCommand {(adjustCorps, adjustInd) = (-1, -1)}

    var corpsOrders = ordersLeft.0 - adjustCorps
    var indOrders = ordersLeft.1 - adjustInd
    
    // Check for unique unit combinations (leader assigned or single unassigned unit)
    if groupSelected.command.hasLeader {
        if groupSelected.command.theLeader!.assigned != "None" || groupSelected.command.finishedMove {corpsOrders = 0}
        else if groupSelected.command.theLeader!.selected != .Selected && groupSelected.command.theLeader!.assigned == "None" && groupSelected.command.OneSelectableOnlyWithLeader() {corpsOrders = 0; indOrders = 0}
    }
    
    var attachMove:SelState = .Off
    var corpsMove:SelState = .Off
    var detachMove:SelState = .Off
    var independent:SelState = .Off
    
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
    if commandSelected.currentLocationType == .Reserve && (commandSelected.currentLocation! as! Reserve).offMap {detachMove = .Off; attachMove = .Off}
    
    // Has moved case - in which case either independent move / corps move again (or attach if there is a viable attach)
    if commandSelected.hasMoved {
        
        if commandSelected.movedVia == .IndMove {return (.Off, .Off, .Off, .On)}
        else if commandSelected.movedVia == .CorpsMove && groupSelected.fullCommand {return (.On, .Off, .Off, .Off)}
        //else {return (.Off, .Off, attachMove, .Off)}
    }
    
    let unitsHaveLeader:Bool = groupSelected.leaderInGroup
    
    // Case: 1 unit selected (most ambiguity is here)
    if unitsSelected.count <= 1 {
        
        if !commandSelected.hasLeader {return (.Off, .Off, .Off, independent)} // Independent
        else {return (.Off, detachMove, .Off, independent)}
        
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
func MoveLocationsAvailable (groupSelected:Group, selectors:(SelState, SelState, SelState, SelState), undoOrAct:Bool = false) -> ([Location], [Approach], [Approach]) {
    
    // Safety Check 
    guard let commandSelected = groupSelected.command else {return ([], [], [])}
    if groupSelected.nonLdrUnitCount == 0 {return ([], [], [])}
    if commandSelected.currentLocationType == .Start {return ([], [], [])}
    
    // Check has moved restrictions
    if groupSelected.someUnitsHaveMoved && !groupSelected.fullCommand {return ([], [], [])} // Return if some units moved (breaking up new commands must be done from 0-moved units)
    else if commandSelected.finishedMove && groupSelected.fullCommand == true {return ([], [], [])} // Command finished move - disable further movement
    
    // Determine unit size (1 or 2+)
    let unitSize:Int!
    if groupSelected.nonLdrUnitCount > 1 {unitSize = 2} else {unitSize = 1}

    // Set the scenario
    var scenario:Int = 0
    let (moveOnS, detachOnS, _, indOnS) = selectors
    let moveOn = (moveOnS == .On); let detachOn = (detachOnS == .On); let indOn = (indOnS == .On)
    
    if !(moveOn || detachOn || indOn) {return ([], [], [])}
    
    var isReserve:Bool = false
    var reinforcement:Bool = false
    if commandSelected.currentLocationType == .Reserve {
        isReserve = true
        reinforcement = (commandSelected.currentLocation as! Reserve).offMap
    }
    let moveNumber = commandSelected.moveNumber
    let relativeRepeatNumber = commandSelected.moveNumber - commandSelected.repeatMoveNumber
    
    if !isReserve {scenario = 1}
    else if detachOn {scenario = 2}
    else if moveNumber == 0 && unitSize == 1 {scenario = 3}
    else if moveNumber == 0 && unitSize == 2 {scenario = 4}
    else if moveNumber > 0 && unitSize == 1 {scenario = 5}
    else if moveNumber > 0 && unitSize == 2 {scenario = 6}
    else {return ([], [], [])}
    
    // Ensures that reinforcements are in rd-move mode
    if reinforcement && scenario == 3 {scenario = 5}
    else if reinforcement && scenario == 4 {scenario = 6}
    
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
        
    case 3: // 1-unit case
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(groupSelected, twoPlusCorps: false)}
        
    case 4: //multi-unit case, no movement
        if groupSelected.cavCount > 0 {enemyOccupiedMustFeintApproaches = EnemyRdTargets(groupSelected, twoPlusCorps: false)}

    case 5: // 1-unit case
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(groupSelected, twoPlusCorps: false)}
        
    default: break
        
    }
    
    // Load rd-move options
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
                if eachReservePath.contains(eachAdjReserve) && moveNumber < eachReservePath.count-2 {
                    finalReserveMoves += [eachAdjReserve]
                }
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
    
    // Allows Cav to move into the approach of a moved-into locale
    if !rdBlock && !(scenario == 1) && (scenario == 5 || (scenario == 6 && !manager!.actingPlayer.ContainsEnemy(currentReserve!.containsAdjacent2PlusCorps) ) ) && !currentReserve!.offMap {
        
        if groupSelected.allCav && !undoOrAct {
            if let reserve1 = commandSelected.rdMoves[moveNumber-1] as? Reserve {
                if let reserve2 = commandSelected.rdMoves[moveNumber] as? Reserve {
                    rdAvailableApproaches = CavApproaches(reserve1, currentReserve: reserve2)
                }
            }
        }
    }
    
    // Road move / threat
    if moveNumber > 0 || reinforcement {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units (approaches too)
        // Replaced "groupSelected.nonLdrUnitCount" with "1"
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(rdAvailableReserves))) {
            if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {
                rdAvailableReserves.removeObject(eachReserve)
                for eachApproach in eachReserve.ownApproaches {rdAvailableApproaches.removeObject(eachApproach)}
            }
        }

        let rdMoves = rdAvailableReserves as [Location] + rdAvailableApproaches as [Location]
        
        // removed "groupSelected.nonLdrUnitCount > 1"
        if (reinforcement || relativeRepeatNumber == 0) && !(manager!.night || manager!.generalThreatsMade >= 2 || detachOn) {
        
            let mustFeintThreats = enemyOccupiedMustFeintApproaches
            
            for each in mustFeintThreats {RevealLocation(each)}
            if manager!.phaseNew == .Commit {
                return ([], [], mustFeintThreats)
            } else {
                for each in rdMoves {RevealLocation(each)}
                return (rdMoves, [], mustFeintThreats)
            }
            
        } else {
            for each in rdMoves {RevealLocation(each)}
            return (rdMoves, [], [])
        }
        
    // Adjacent move / threat
    } else {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(adjAvailableReserves))) {
            if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {
                adjAvailableReserves.removeObject(eachReserve)
            }
        }
        
        let adjMoves = adjAvailableReserves as [Location] + adjAvailableApproaches as [Location]
        
        // Remove approaches already attacked by normal attack
        for eachApproach in enemyOccupiedAttackApproaches {if !eachApproach.mayNormalAttack {enemyOccupiedAttackApproaches.removeObject(eachApproach)}}
        for eachApproach in enemyOccupiedMustFeintApproaches {if !eachApproach.mayNormalAttack {enemyOccupiedMustFeintApproaches.removeObject(eachApproach)}}
        
        // Night turn or all general attacks made no attacks allowed
        // removed "groupSelected.nonLdrUnitCount > 1"
        if manager!.night || manager!.generalThreatsMade >= 2 || detachOn {
            if manager!.phaseNew == .Commit || groupSelected.someUnitsFixed {
                return ([], [], [])
            } else {
                return (adjMoves, [], [])
            }
        }
        
        let attackThreats = enemyOccupiedAttackApproaches
        let mustFeintThreats = Array(Set(enemyOccupiedMustFeintApproaches).subtract(Set(enemyOccupiedAttackApproaches)))
        
        // Commit phase or fixed art, only attacks allowed
        if manager!.phaseNew == .Commit || groupSelected.someUnitsFixed {
            return ([],  attackThreats, mustFeintThreats)
            
        // Move phase, both attacks and moves allowed
        } else {
            return (adjMoves, attackThreats, mustFeintThreats)
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
    
    // Check if selected command is viable
    if groupSelected.fullCommand && differentCommandSameLocation && groupSelected.leaderInGroup {return true} else {return false}
}

func CheckIfGuardAttackViable(theGroup:Group, theApproach:Approach) -> Bool {
    
    if !theGroup.guardInGroup {return false}
    if theApproach.obstructedApproach {return false}
    if manager!.guardFailed[manager!.actingPlayer]! {return false}
    return true
}

// MARK: Feint & Retreat Logic

// Returns groups available to defend (in reserve) and true if there are selectable defenders (false if something is on the approach or no defenders available)
func SelectableGroupsForDefense (theConflict:Conflict) -> [Group] {
    
    var theCommandGroups:[Group] = []

    if (theConflict.defenseApproach.occupantCount > 0) || !(theConflict.defenseReserve.defendersAvailable(theConflict.parentGroupConflict!) > 0) {return theCommandGroups}
    
    for eachReserveOccupant in theConflict.defenseReserve.occupants {
        
        let potDefenders = eachReserveOccupant.conflictAvailableToDefend(theConflict)
        if potDefenders.count > 0 {

            // Commanded units
            if eachReserveOccupant.hasLeader {

                let selectedUnits = potDefenders + [eachReserveOccupant.theLeader!]
                if selectedUnits.count > 0 {theCommandGroups += [Group(theCommand: eachReserveOccupant, theUnits: selectedUnits)]}

            // Detached units
            } else {
                theCommandGroups += [Group(theCommand: eachReserveOccupant, theUnits: potDefenders)]
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

// Called from the Hold Touch command
func ReduceStrengthIfRetreat(touchedUnit:Unit, theLocation:Location, theGroupConflict:GroupConflict, retreatMode:Bool) -> Bool {
    
    if !retreatMode {return false} // Not in retreat mode
    if touchedUnit.selected != .Selected {return false} // Not selected

    // Artillery Check
    var canDestroy:Bool = false
    if theGroupConflict.destroyRequired[theLocation] > theGroupConflict.destroyDelivered[theLocation] {canDestroy = true}
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
    
    for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: false)}
    let retreatSelection = GroupSelection(theGroups: retreatGroup)
    if retreatSelection.blocksSelected == 0 {return .Option}
    
    // Check if reductions are finished for selected units locations
    for eachGroup in retreatGroup {
        if eachGroup.nonLdrUnitCount == 0 {return .NotAvail}
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
    if retreatSelection.containsLeader {spaceRequired -= 1}
    for eachReserve in activeGroupConflict!.defenseReserve.adjReserves {
        if eachReserve.availableSpace >= spaceRequired && eachReserve.localeControl != manager!.actingPlayer.Other() {adjReservesWithSpace += [eachReserve]}
    }
    
    // Reveal available retreat reserves
    var returnOn:Bool = false
    manager!.selectionRetreatReserves = Array(Set(adjReservesWithSpace).subtract(Set([attackedReserve])))
    for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: true); returnOn = true}

    if returnOn {return .On} else {return .NotAvail}
}

// Returns "TurnOnRetreat", "TurnOnSurrender" or "TurnOnDefend" plus sets selectable group
func ConflictSelectDuringDefensePhase() -> String {
    
    if activeConflict == nil {return "TurnOnNothing"}
    
    // Must defend? (already gave a defense order)
    if activeGroupConflict!.mustDefend {
        activeGroupConflict!.retreatMode = false
        
        return "TurnOnDefendOnly"
    }
    
    // Space available? (retreat or no order) - this will return the destroy case (true, true)
    var spaceAvailable:Bool = false
    for eachReserve in activeGroupConflict!.defenseReserve.adjReserves {
        if eachReserve.availableSpace > 0 && eachReserve.localeControl != manager!.phasingPlayer && activeConflict!.attackReserve != eachReserve {spaceAvailable = true; break}
    }
    
    let noDefendersAvailable = activeConflict!.defenseReserve.defendersAvailable(activeGroupConflict!) < 1
    let unDefendedApproaches = activeGroupConflict!.unresolvedApproaches.count > 0

    // No space available case
    if !spaceAvailable {
        
        // No space, must-retreat (no-one to defend with)
        if (noDefendersAvailable && unDefendedApproaches) {
            activeGroupConflict!.retreatMode = true
            activeGroupConflict!.mustRetreat = true
            return "TurnOnSurrender"
        }
        
        // Must defend mode
        else {
            activeGroupConflict!.retreatMode = false
            activeGroupConflict!.mustDefend = true
            return "TurnOnDefendOnly"
        }
    }

    // Retreat command was given and space exists
    if activeGroupConflict!.mustRetreat || (noDefendersAvailable && unDefendedApproaches) {
        activeGroupConflict!.retreatMode = true
        activeGroupConflict!.mustRetreat = true
        return "TurnOnRetreatOnly"
    }
    
    // If you make it through, neither is forced (no command given)
    return "TurnOnBoth"
}

func RetreatPreparation() {
    
    ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: true, otherSelectors: false)

    switch ConflictSelectDuringDefensePhase() {
        
    case "TurnOnDefendOnly":
        
        manager!.groupsSelectable = SelectableGroupsForDefense(activeConflict!)
        retreatButton.buttonState = .Off
        
    case "TurnOnRetreatOnly":
        
        manager!.groupsSelectable = SelectableGroupsForRetreat(activeConflict!)
        retreatButton.buttonState = .Option
        
    case "TurnOnBoth":
        
        if activeGroupConflict!.retreatMode {
            manager!.groupsSelectable = SelectableGroupsForRetreat(activeConflict!)
            retreatButton.buttonState = .Option
        } else {
            manager!.groupsSelectable = SelectableGroupsForDefense(activeConflict!)
            retreatButton.buttonState = .Possible
        }
        
    case "TurnOnSurrender":
        
        let newOrder = Order(passedConflict: activeConflict!, orderFromView: .Surrender)
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        manager!.groupsSelectable = []
        retreatButton.buttonState = .Off
        
    default: break
        
    }
    
    ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
}

// MARK: Move After Threat Logic

func SelectableGroupsForAttack (byRd:Bool) -> [Group]  {
    
    //if !manager!.groupsSelected.isEmpty{return []}
    if activeConflict == nil {return []}
    
    var theCommandGroups:[Group] = []
    
    let (corpsMovesAvailable, independentMovesAvailable) = manager!.PhantomOrderCheck(activeConflict!.phantomCorpsOrder!, addExistingOrderToPool: true)
    
    let potentialAttackers:[Command]
    if byRd {
        potentialAttackers = Array(activeConflict!.potentialRdAttackers.keys)
    } else {
        potentialAttackers = activeConflict!.attackApproach.occupants + activeConflict!.attackReserve.occupants
    }

    for eachCommand in potentialAttackers {
        
        let selectableUnits:[Unit]
        
        if byRd {
            selectableUnits = eachCommand.cavPlusLdrUnits.filter{$0.threatenedConflict == nil || $0.threatenedConflict!.defenseApproach == activeConflict!.defenseApproach}
        } else {
            selectableUnits = eachCommand.activeUnits.filter{$0.threatenedConflict == nil || $0.threatenedConflict!.defenseApproach == activeConflict!.defenseApproach}
        }
        var movableSelectableUnits = selectableUnits.filter{$0.hasMoved == false || $0.parentCommand!.repeatMoveNumber > 0}
            
        if movableSelectableUnits.isEmpty || (movableSelectableUnits.count == 1 && movableSelectableUnits[0].unitType == .Ldr) {continue}

        // Leader case
        if corpsMovesAvailable > 0 && eachCommand.hasLeader && !eachCommand.finishedMove {
            theCommandGroups += [Group(theCommand: eachCommand, theUnits: movableSelectableUnits)]
        }
        // Ind case (highlight the cav) - algo determines if there are remaining units for any hanging leader
        else if independentMovesAvailable > 0 {

            movableSelectableUnits = selectableUnits.filter{$0.unitType != .Ldr}
            var unAssignedUnits:Bool = false
            if eachCommand.hasLeader {
                for eachUnit in eachCommand.nonLeaderUnits {
                    if eachUnit.threatenedConflict == nil {
                        unAssignedUnits = true
                    } else {
                        if activeConflict!.phantomCorpsOrder! || eachUnit.threatenedConflict!.defenseApproach == activeConflict!.defenseApproach {
                            unAssignedUnits = true
                        }
                    }
                }
            } else {unAssignedUnits = true}
            
            if unAssignedUnits {
                theCommandGroups += [Group(theCommand: eachCommand, theUnits: movableSelectableUnits)]
            }
        }
    }
    return theCommandGroups
}

func OrdersAvailableOnAttack (groupsSelected:[Group], theConflict:Conflict) -> (SelState, SelState, SelState, SelState) {
    
    // Safety drill
    if groupsSelected.isEmpty {return (.Off, .Off, .Off, .Off)}
    else {
        for eachGroup in groupsSelected {
            if eachGroup.nonLdrUnitCount == 0 {return (.Off, .Off, .Off, .Off)}
        }
    }
    
    if groupsSelected[0].command.moveNumber > 0 {
        if groupsSelected[0].command.moveNumber - groupsSelected[0].command.repeatMoveNumber == 0 || undoOrAct {
            switch (groupsSelected[0].command.movedVia) {
            case .CorpsMove: return (.On, .Off, .Off, .Off)
            case .IndMove: return (.Off, .Off, .Off, .On)
            default: return (.Off, .Off, .Off, .Off)
            }
        } else {
            switch (groupsSelected[0].command.movedVia) {
            case .CorpsMove: return (.NotAvail, .Off, .Off, .Off)
            case .IndMove: return (.Off, .Off, .Off, .NotAvail)
            default: return (.Off, .Off, .Off, .Off)
            }
        }
    }
    
    var corpsMove:SelState = .On
    var detachMove:SelState = .On
    var independent:SelState = .On
    
    // Determine if the defense reserve is large enough to hold all the potential attackers
    var potAttackers = 0
    for eachGroup in groupsSelected {
        potAttackers += eachGroup.nonLdrUnitCount
        
        // Check if the commander is finished its move
        if eachGroup.command.hasLeader && eachGroup.command.finishedMove {
            corpsMove = .NotAvail
            detachMove = .NotAvail
        }
    }
    for eachConflict in theConflict.parentGroupConflict!.conflicts {
        if eachConflict.attackGroup != nil {
            potAttackers += eachConflict.attackGroup!.nonLeaderBlocksSelected
        }
    }
    if potAttackers > theConflict.defenseReserve.capacity {
        corpsMove = .NotAvail
        detachMove = .NotAvail
        independent = .NotAvail
    }
    
    if groupsSelected[0].command.finishedMove {
        corpsMove = .Off
        detachMove = .Off
    }
    
    // Deals with reinforcement free-moves
    var freeCorps = 0
    for eachGroup in groupsSelected {
        if eachGroup.command.freeCorpsMove && eachGroup.command.turnEnteredMap == manager!.turn && eachGroup.command.moveNumber == 0 {
            if eachGroup.leaderInGroup {freeCorps += 1}
        }
    }
    var (corpsOrders, indOrders) = manager!.PhantomOrderCheck(theConflict.phantomCorpsOrder!, addExistingOrderToPool: true)
    
    corpsOrders += freeCorps
    
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
                if !adjacentLocation {rdBlocked = !AttackByRdPossible(theConflict.RdCommandPathToConflict(theGroup.command), twoPlusCorps: true)}
                
                if !rdBlocked {return (corpsMove, .Off, .Off, .Off)}
                else {return (.Off, .Off, .Off, .Off)}
                
            case (false, false): return (.Off, .Off, .Off, .Off)
                
            case (true, true): return (corpsMove, .Off, .Off, .Off)
                
            case (false, true): return (.Off, detachMove, .Off, .Off)
                
            }
            
        } else {
            
            var rdBlocked = true
            if !adjacentLocation {rdBlocked = !AttackByRdPossible(theConflict.RdCommandPathToConflict(theGroup.command), twoPlusCorps: false)}
            
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
    let repeatMoveNumber = theGroup.command.repeatMoveNumber
    let realMoveNumber = moveNumber - repeatMoveNumber
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
        else if theReserve == theConflict.defenseReserve {return []}
        if realMoveNumber == 0 {theConflict.rdAttackerMultiPaths = theReserve!.rdReserves} // Sets the pathways
    }
    
    let theReserveAsSKNode = theConflict.attackReserve as SKNode
    let theApproachAsSKNode = theConflict.attackApproach as SKNode
    
    switch (adjacentLocation, feint) { // Elminate 3rd piece
        
    case (true, true):
        
        if theGroup.command.finishedMove && realMoveNumber == 0 && !(theGroup.units.count == 1 && !theGroup.units[0].hasMoved) {
            return []
        } // Made an in-place move
        else if realMoveNumber == 0 && !onApproach {return [theReserveAsSKNode, theApproachAsSKNode]}
        else if realMoveNumber == 0 && onApproach {return [theApproachAsSKNode]} // Hasn't moved
        else if !theGroup.command.finishedMove {return [theApproachAsSKNode]} // Moved in from outside
        else {return []} // Should never get here...
        
    case (true, false):
        
        // Allows artillery to stay still
        if (detachOnS == .On || indOnS == .On) && theGroup.artOnly && onApproach {return [theConflict.defenseReserve, theApproachAsSKNode]}
        else {return [theConflict.defenseReserve as SKNode]} // the normal case
        
    case (false, _):
        
        let thePath:[Reserve]!
        if realMoveNumber == 0 {
            thePath = theConflict.potentialRdAttackers[theGroup.command]!
            theConflict.rdAttackerPath = thePath
        }
        else {thePath = theConflict.rdAttackerPath}
        
        if !AttackByRdPossible(thePath, twoPlusCorps: theGroup.groupIsTwoPlusCorps) {return []}
        
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

    default: break
        
    }
    return []
    
}

// Pass it a 2D array of reserve pathways, returns true if 2Plus Corps can rd move with it (checks the three rd conditions plus whether enemy occupied)
func AttackByRdPossible(thePath:[Reserve], twoPlusCorps:Bool) -> Bool {

    if thePath.isEmpty {return false}
    var rdNotBlocked = true
    
    for i in 1 ..< thePath.count-1 {
        
        if twoPlusCorps {  // Removes ability of 2+ corps to attack by rd (unique to app)
            if thePath[i].has2PlusCorpsPassed || thePath[i].haveCommandsEntered || manager!.actingPlayer.ContainsEnemy(thePath[i].containsAdjacent2PlusCorps) || thePath[i].localeControl == manager!.actingPlayer.Other() {
                rdNotBlocked = false
                break
            }
        } else {
            if thePath[i].has2PlusCorpsPassed || thePath[i].localeControl == manager!.actingPlayer.Other() {
                rdNotBlocked = false
                break
            }
        }

    }
    
    return rdNotBlocked
}

// Function takes an array of units and returns and array of units that should be selected to adjust for leader-abandonment rules
func AdjustSelectionForLeaderRulesActiveThreat(theUnits:[Unit]) -> [Unit] {
    
    // Safety check
    if activeConflict == nil {return []}
    if theUnits.isEmpty {return []}
    let theCommand = theUnits[0].parentCommand!
    if !theCommand.hasLeader {return theUnits}
    
    let theOtherUnits = Array(Set(theCommand.activeUnits).subtract(Set(theUnits)))
    var leaderSelected:Bool = false
    var theLeader:Unit?
    for eachUnit in theUnits {if eachUnit.unitType == .Ldr {theLeader = eachUnit; leaderSelected = true; break}}
    if !leaderSelected {
        for eachUnit in theOtherUnits {if eachUnit.unitType == .Ldr {theLeader = eachUnit; leaderSelected = false; break}}
    }
    
    if leaderSelected {
        if theUnits.count == 1 {theLeader!.selected = .Normal; return []}
    } else {
        var alreadyAssignedUnits = 0 // Units which are unassigned (could be assigned to a leader for instance)
        var leaderAssignedElsewhere = false
        for eachUnit in theOtherUnits {
            if eachUnit.unitType != .Ldr && eachUnit.selected == .NotSelectable && eachUnit.threatenedConflict != nil && eachUnit.threatenedConflict!.defenseApproach != activeConflict!.defenseApproach {
                alreadyAssignedUnits += 1
            }
            else if eachUnit.unitType == .Ldr && eachUnit.selected == .NotSelectable && eachUnit.threatenedConflict != nil && eachUnit.threatenedConflict!.defenseApproach != activeConflict!.defenseApproach {
                leaderAssignedElsewhere = true
            }
        }
        if leaderAssignedElsewhere {return theUnits}
        else if theOtherUnits.count - alreadyAssignedUnits <= 1 {theLeader!.selected = .Selected; return theUnits + [theLeader!]}
    }
    return theUnits
}

// MARK: Battle Logic

func InitialBattleProcessing(theConflict:Conflict) {
    
    ToggleGroups(theConflict.attackLeadingUnits!.groups, makeSelection: .NotSelectable)
    ToggleGroups(theConflict.defenseLeadingUnits!.groups, makeSelection: .NotSelectable)
    
    // INITIAL RESULT
    let newOrder = Order(passedConflict: theConflict, orderFromView: .InitialBattle)
    newOrder.ExecuteOrder()
    newOrder.unDoable = false // Can't undo initial result
    manager!.orders += [newOrder]
}

func FinalBattleProcessing(theConflict:Conflict) {
    
    ToggleGroups(theConflict.attackLeadingUnits!.groups, makeSelection: .NotSelectable)
    ToggleGroups(theConflict.defenseLeadingUnits!.groups, makeSelection: .NotSelectable)
    ToggleGroups(theConflict.counterAttackLeadingUnits!.groups, makeSelection: .NotSelectable)
    
    // FINAL RESULT
    let newOrder = Order(passedConflict: theConflict, orderFromView: .FinalBattle)
    newOrder.ExecuteOrder()
    newOrder.unDoable = false // Can't undo final result
    manager!.orders += [newOrder]
}

func ProcessDefenderWin(theConflict:Conflict) {
    
    // Attacker Retreat (if there is a leader, then the whole command effectively retreats - otherwise just the sent unit(s))
    
    for eachGroup in theConflict.attackGroup!.groups {
        
        var retreatGroup:GroupSelection!
        var remainGroup:GroupSelection!
        
        if eachGroup.leaderInGroup {
            
            let theRetreatUnits = eachGroup.units
            let theRemainUnits = Array(Set(eachGroup.command.activeUnits).subtract(Set(theRetreatUnits)))
            
            let theRetreatGroup = Group(theCommand: eachGroup.command, theUnits: theRetreatUnits)
            let theRemainGroup = Group(theCommand: eachGroup.command, theUnits: theRemainUnits)
            
            retreatGroup = GroupSelection(theGroups: [theRetreatGroup], selectedOnly: false)
            remainGroup = GroupSelection(theGroups: [theRemainGroup], selectedOnly: false)
            
        } else {
            
            retreatGroup = GroupSelection(theGroups: [eachGroup], selectedOnly: false)
            remainGroup = GroupSelection(theGroups: [], selectedOnly: false)
        }
        
        if !retreatGroup.groups.isEmpty && retreatGroup.groupSelectionStrength > 0 {
            
            let newOrder = Order(passedConflict:theConflict, theGroupSelection: retreatGroup!, touchedReserveFromView: theConflict.attackReserve as Location, orderFromView: .Retreat)
            newOrder.ExecuteOrder()
            manager!.orders += [newOrder]
            
            // Need to set the units as having moved (no need to store order as not undoable)
            for (_, commandGroup) in newOrder.moveCommands {
                for eachCommand in commandGroup {
                    eachCommand.movedVia = theConflict.attackMoveType!
                    eachCommand.finishedMove = true
                }
            }
        }
        
        if !remainGroup.groups.isEmpty && remainGroup.groupSelectionStrength > 0 {
            
            let newOrder = Order(passedConflict:theConflict, theGroupSelection: remainGroup!, touchedReserveFromView: remainGroup.groups[0].command.currentLocation!, orderFromView: .Retreat)
            newOrder.ExecuteOrder()
            manager!.orders += [newOrder]
            
            if theConflict.attackMoveType == .CorpsDetach {
                remainGroup.groups[0].command.movedVia = .CorpsActed
            }
        }
    }
    
    // Morale reductions (guard-attack failed)
    if theConflict.guardAttack {
        manager!.guardFailed[theConflict.defenseSide.Other()!] = true
        manager!.ReduceMorale(manager!.guardFailedCost, side: theConflict.defenseSide.Other()!, mayDemoralize: false)
    }
}

func PostBattleMove(theConflict:Conflict, artAttack:Bool = false) {
    
    let moveToNode:SKNode!
    let continuePossible = !theConflict.parentGroupConflict!.someEmbattledAttackersWon
    
    if artAttack {
        moveToNode = theConflict.attackApproach
    }
    else if continuePossible {
        moveToNode = theConflict.defenseReserve
    } else {
        moveToNode = theConflict.defenseReserve
        theConflict.defenseReserve.has2PlusCorpsPassed = true // This ensures that the locale is blocked to all further movement
        theConflict.defenseReserve.unitsEnteredPostBattle = true
    }
    
    // Attack moves
    for eachGroup in theConflict.attackGroup!.groups {
        
        let newOrder = Order(groupFromView: eachGroup, touchedNodeFromView: moveToNode, orderFromView: .Move, corpsOrder: nil, moveTypePassed: theConflict.attackMoveType!)
        newOrder.ExecuteOrder()
        newOrder.unDoable = false
        manager!.orders += [newOrder]
        
        // Sets the moved commands to "finished moved"
        for (_, eachCommandArray) in newOrder.moveCommands {
            for eachCommand in eachCommandArray {
                
                eachCommand.movedVia = theConflict.attackMoveType!
                
                if continuePossible && (newOrder.moveType == .IndMove || newOrder.moveType == .CorpsMove) {
                    eachCommand.repeatMoveNumber = eachCommand.moveNumber
                } else {
                    eachCommand.finishedMove = true
                }
            }
        }
    }
}

// MARK: Defense Logic

func SelectableGroupsForFeintDefense(theThreat:Conflict) -> [Group] {
    
    // Safety drill
    if theThreat.defenseGroup!.groups.isEmpty {return []}
    return GroupsIncludeLeaders(theThreat.defenseGroup!.groups)
}

// MARK: Leading Units Logic

func SelectableLeadingGroups (theConflict:Conflict, thePhase:newGamePhase, resetState:Bool = false) -> ([Group],[Group]) {
    
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
    if theGroups.isEmpty {return ([], [])}
    
    let selectedLeadingGroups:GroupSelection!
    if resetState {
        selectedLeadingGroups = GroupSelection(theGroups: [])
    } else {
        selectedLeadingGroups = GroupSelection(theGroups: theGroups)
    }
    
    ToggleGroups(theGroups, makeSelection: .Normal)
    
    var attackLeadingArtPossible = false
    if (theGroups[0].command.currentLocation == theConflict.attackApproach) && theConflict.attackMoveType != .CorpsMove && (theConflict.attackApproach.turnOfLastArtVolley < manager!.turn - 1 || (theConflict.attackApproach.hillApproach && !theConflict.defenseApproach.hillApproach)) && theConflict.defenseApproach.mayArtAttack {attackLeadingArtPossible = true}

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
    return (selectedLeadingGroups.groups, theGroups)
}

// MARK: Toggle Selections

func ResetActiveConflict(theThreat:Conflict) {
    
    if activeConflict != nil {
        
        // Routine unselects the defense leading units
        if manager!.phaseNew == .SelectAttackGroup && activeConflict!.defenseLeadingUnits != nil {
            if activeConflict!.counterAttackLeadingUnits == nil {
                ToggleGroups(activeConflict!.defenseLeadingUnits!.groups, makeSelection: .NotSelectable)
            } else {
                ToggleGroups(activeConflict!.counterAttackLeadingUnits!.groups, makeSelection: .NotSelectable)
            }
        }
        activeConflict!.defenseApproach.zPosition = 200; activeConflict = nil
    }
    theThreat.defenseApproach.zPosition = 200
    ToggleGroups(manager!.groupsSelectable, makeSelection: .NotSelectable)
    ToggleGroups(manager!.groupsSelected, makeSelection: .NotSelectable)
    manager!.groupsSelectable = []
    manager!.groupsSelected = []
}

func SetupActiveConflict() {
    
    // Safety check
    if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .Off {return}
    
    // Setup new conflict
    activeConflict!.defenseApproach.zPosition = 50
    
    if activeConflict!.guardAttack {guardButton.buttonState = .On} else {guardButton.buttonState = .Off}
    if activeConflict!.realAttack {commitButton.buttonState = .On} else {commitButton.buttonState = .Off}
    
    // Function determines what retreat mode we are in (defense only, retreat only, etc)
    switch manager!.phaseNew {
        
    case .RetreatOrDefenseSelection:
        
        if activeConflict!.defenseGroup != nil && !activeGroupConflict!.retreatMode {
            ToggleGroups(activeConflict!.defenseGroup!.groups, makeSelection: .Selected)
            manager!.groupsSelected = activeConflict!.defenseGroup!.groups
        }
        if activeConflict!.defenseApproach.approachSelector!.selected == .On {break} // Already defended
        
        RetreatPreparation()
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else {endTurnButton.buttonState = .Off}
        
    case .SelectDefenseLeading:
        
        if activeConflict!.defenseLeadingUnits == nil {
            (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(activeConflict!, thePhase: manager!.phaseNew)
            SelectLeadingUnits(activeConflict!)
        } else {
            ToggleGroups(activeConflict!.defenseLeadingUnits!.groups, makeSelection: .Selected)
            manager!.groupsSelected = activeConflict!.defenseLeadingUnits!.groups
        }
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else if activeConflict!.defenseLeadingUnits != nil {endTurnButton.buttonState = .Off}
        else {endTurnButton.buttonState = .Option}
        
    case .PreRetreatOrFeintMoveOrAttackDeclare:
        
        if activeConflict!.defenseApproach.approachSelector!.selected == .On {break} // Already committed approach or made feint-move
        
        // Setup buttons
        if activeGroupConflict!.retreatMode || activeConflict!.mustFeint {commitButton.buttonState = .Off}
        else if activeConflict!.guardAttack {guardButton.buttonState = .On; commitButton.buttonState = .Option}
        else {commitButton.buttonState = .Option}
        
        manager!.groupsSelectableByRd = SelectableGroupsForAttack(true)
        manager!.groupsSelectableAdjacent = SelectableGroupsForAttack(false)
        manager!.groupsSelectable = manager!.groupsSelectableByRd + manager!.groupsSelectableAdjacent
        ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
        
    case .SelectAttackGroup:
        
        if activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
        
        manager!.groupsSelectable = SelectableGroupsForAttack(false)
        ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
        ToggleGroups(activeConflict!.defenseLeadingUnits!.groups, makeSelection: .Selected)
        
    case .SelectAttackLeading:
        
        if activeConflict!.attackLeadingUnits == nil {
            (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(activeConflict!, thePhase: manager!.phaseNew)
            SelectLeadingUnits(activeConflict!)
        } else {
            ToggleGroups(activeConflict!.attackLeadingUnits!.groups, makeSelection: .Selected)
            manager!.groupsSelected = activeConflict!.attackLeadingUnits!.groups
        }
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else if activeConflict!.attackLeadingUnits != nil {endTurnButton.buttonState = .Off}
        else {endTurnButton.buttonState = .Option}
        
    case .FeintResponse:
        
        if activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
        
        manager!.groupsSelectable = SelectableGroupsForFeintDefense(activeConflict!)
        manager!.groupsSelected = []
        ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else {endTurnButton.buttonState = .Off}
        
    case .SelectCounterGroup:
        
        if activeConflict!.counterAttackLeadingUnits == nil {
            (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(activeConflict!, thePhase: manager!.phaseNew)
            SelectLeadingUnits(activeConflict!)
        } else {
            ToggleGroups(activeConflict!.counterAttackLeadingUnits!.groups, makeSelection: .Selected)
            manager!.groupsSelected = activeConflict!.counterAttackLeadingUnits!.groups
        }
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else if activeConflict!.counterAttackLeadingUnits != nil {endTurnButton.buttonState = .Off}
        else {endTurnButton.buttonState = .Option}
        
    case .PostCombatRetreatAndVictoryResponseMoves:
        
        if activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
        
        if activeConflict!.parentGroupConflict!.retreatMode {
            
            activeConflict!.parentGroupConflict!.SetupRetreatRequirements() // Re-seeds the reduce requirements for retreating
            RetreatPreparation()
            
        } else {
        
            manager!.groupsSelectable = SelectableGroupsForFeintDefense(activeConflict!)
            ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
        }
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
        else {endTurnButton.buttonState = .Off}
        
    default: break
        
    }
}

// Returns true if endTurn is viable
func CheckEndTurnStatus() -> Bool {
    
    var endTurnViable = true
    
    switch manager!.phaseNew {
        
    case .RetreatOrDefenseSelection:
        
        for eachLocaleThreat in manager!.localeThreats {
            
            if eachLocaleThreat.retreatMode {
                if eachLocaleThreat.defenseReserve.currentFill > 0 {
                    endTurnViable = false
                    for eachConflict in eachLocaleThreat.conflicts {
                        eachConflict.defenseApproach.approachSelector!.selected = .Option
                    }
                } else {
                    for eachConflict in eachLocaleThreat.conflicts {
                        eachConflict.defenseApproach.approachSelector!.selected = .On
                    }
                }
            } else {
                if eachLocaleThreat.unresolvedApproaches.count > 0 && eachLocaleThreat.defenseReserve.defendersAvailable(eachLocaleThreat) > 0 {
                    endTurnViable = false
                }
                for eachConflict in eachLocaleThreat.conflicts {
                    if eachConflict.approachDefended {
                        eachConflict.defenseApproach.approachSelector!.selected = .On
                    } else if endTurnViable {
                        eachConflict.defenseApproach.approachSelector!.selected = .NotAvail
                    } else {
                        eachConflict.defenseApproach.approachSelector!.selected = .Option
                    }
                }
            }
        }
        
    case .SelectDefenseLeading, .SelectAttackLeading, .SelectCounterGroup:
        
        for eachLocaleThreat in manager!.localeThreats {
            if eachLocaleThreat.retreatMode {continue}
            for eachConflict in eachLocaleThreat.conflicts {
                if eachConflict.defenseApproach.approachSelector!.selected == .Option {
                    endTurnViable = false
                    break
                }
            }
        }
        
    case .PreRetreatOrFeintMoveOrAttackDeclare:
        
        for eachLocaleThreat in manager!.localeThreats {
            for eachConflict in eachLocaleThreat.conflicts {
                if eachConflict.defenseApproach.approachSelector!.selected == .Option {
                    endTurnViable = false
                    break
                }
            }
        }
        
    case .SelectAttackGroup:
        
        for eachLocaleThreat in manager!.localeThreats {
            for eachConflict in eachLocaleThreat.conflicts {
                if (eachConflict.realAttack || !eachConflict.approachDefended) && eachConflict.defenseApproach.approachSelector!.selected == .Option {
                    endTurnViable = false
                    break
                }
            }
        }
        
    case .FeintResponse:
        
        for eachLocaleThreat in manager!.localeThreats {
            if eachLocaleThreat.retreatMode {continue}
            for eachConflict in eachLocaleThreat.conflicts {
                if !eachConflict.realAttack && eachConflict.defenseApproach.approachSelector!.selected == .Option {
                    endTurnViable = false
                    break
                }
            }
        }
        
    case .PostCombatRetreatAndVictoryResponseMoves:
        
        for eachLocaleThreat in manager!.localeThreats {
            
            if eachLocaleThreat.retreatMode {
                if eachLocaleThreat.defenseReserve.localeControl == eachLocaleThreat.conflicts[0].defenseSide {
                    endTurnViable = false
                    for eachConflict in eachLocaleThreat.conflicts {
                        if eachConflict.realAttack {
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                        } else {
                            eachConflict.defenseApproach.approachSelector!.selected = .Off
                        }
                    }
                } else {
                    for eachConflict in eachLocaleThreat.conflicts {
                        eachConflict.defenseApproach.approachSelector!.selected = .On
                    }
                }
            } else {

                for eachConflict in eachLocaleThreat.conflicts {
                    if eachConflict.defenseApproach.approachSelector!.selected == .Option {
                        endTurnViable = false
                    }
                }
            }
        }
        if endTurnViable {retreatButton.buttonState = .Off}
        
    default: break
        
    }
    if activeConflict != nil {activeConflict!.defenseApproach.approachSelector!.turnColor("Purple")}
    return endTurnViable
}

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

func ToggleBattleWidthUnitSelection(touchedUnit:Unit!, theThreat:Conflict) {
    
    let unitSelectedAlready = touchedUnit.selected == .Selected
    
    var unitsSelected = 0
    var theUnselectedUnit:Unit?
    for eachGroup in theThreat.defenseLeadingUnits!.groups {
        for eachUnit in eachGroup.units {
            if eachUnit.selected == .Selected {unitsSelected += 1}
            else {theUnselectedUnit = eachUnit}
        }
    }
    
    switch (unitsSelected, unitSelectedAlready) {
        
    case (1, true):
        if theUnselectedUnit != nil {
            touchedUnit.selected = .Normal
            theUnselectedUnit!.selected = .Selected
        }
        
    case (1, false): touchedUnit.selected = .Selected
        
    case (2, _): touchedUnit.selected = .Normal
        
    default: break
        
    }
}

// MARK: Road Movement Support

func CavApproaches(previousReserve:Reserve, currentReserve:Reserve) -> [Approach] {
    
    var targetApproaches:[Approach] = []
    
    for eachPath in previousReserve.rdReserves {
        
        if eachPath[1] == currentReserve {
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
        if each is Reserve {currentPath += [each as! Reserve]} else {return ([],[])}
    }
    
    let rdAvailableReserves = currentPath[0].rdReserves
    
    for eachPath in rdAvailableReserves {
        
        var rdIndex:Int = 0
        
        for i in 1...moveSteps {
            
            if rdIndex == 0 && i == 1 {
                if currentPath[i] == eachPath[i] {rdIndex += 1}
                else {break}
            }
            if rdIndex == 1 && i == 2 {
                if currentPath[i] == eachPath[i-2] {rdIndex -= 1}
                else if currentPath[i] == eachPath[i] {rdIndex += 1}
                else {rdIndex = 0; break}
            }
            if rdIndex == 0 && i == 3 {
                if currentPath[i] == eachPath[i-2] {rdIndex += 1}
                else {rdIndex = 0; break}
            }
            if rdIndex == 2 && i == 3 {
                if currentPath[i] == eachPath[i-2] {rdIndex -= 1}
                else if currentPath[i] == eachPath[i] {rdIndex += 1}
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
        for i in thePathPositions[index] + 1 ..< eachPath.count {
            count += 1
            if moveNumber + count >= eachPath.count {continue}

            if eachPath[i].localeControl == manager!.actingPlayer.Other() {
                
                // Found a potential enemy to rd feint
                // removed "theGroup.nonLdrUnitCount" and replaced with "1" as the test is whether 1 unit can enter
                if let attackToApproach = ApproachesFromReserves(eachPath[i-1], reserve2: eachPath[i]) {
                
                    if (eachPath[i-1].currentFill + 1 > eachPath[i-1].capacity && eachPath[i].defendersAvailable(nil) > 0) {break}
                    if attackToApproach.1.occupantCount > 0 || attackToApproach.1.threatened {break}
                    targetApproaches += [attackToApproach.1]
                }
                break // Must break after finding an enemy (path can't go any further)
                
            } else if (!twoPlusCorps && eachPath[i].has2PlusCorpsPassed) || (twoPlusCorps && (eachPath[i].has2PlusCorpsPassed || eachPath[i].haveCommandsEntered || manager!.actingPlayer.ContainsEnemy(eachPath[i].containsAdjacent2PlusCorps) ) ) {break}
            
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