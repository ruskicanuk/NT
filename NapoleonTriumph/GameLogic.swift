
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

// Returns true (if road move), first array are viable "peaceful" moves, second array are viable "attack" moves
func MoveLocationsAvailable (groupSelected:Group, selectors:(SelState, SelState, SelState, SelState), undoOrAct:Bool = false) -> ([SKNode], [SKNode], [SKNode]) {
    
    guard let commandSelected = groupSelected.command else {return ([], [], [])}
    if groupSelected.nonLdrUnitCount == 0 {return ([], [], [])}
    
    //var locationQueue:Array<SKNode> = [nil, [], []]
    if commandSelected.currentLocationType == .Start {return ([], [], [])} // Start Locations - skip game logic, eventually put in the initial location code here
    
    // Check has moved restrictions
    if groupSelected.someUnitsHaveMoved && !groupSelected.fullCommand {return ([], [], [])} // Return if some units moved (breaking up new commands must be done from 0-moved units)
    else if commandSelected.finishedMove && groupSelected.fullCommand == true {return ([], [], [])} // Command finished move - disable further movement
    
    // Determine unit size (1 or 2+)
    let unitSize:Int!
    if groupSelected.nonLdrUnitCount > 1 {unitSize = 2} else {unitSize = 1}
    //else if unitsSelected.count == 0 && (commandSelected.unitCount > 2 || (commandSelected.unitCount == 2 && !hasLeader)) {unitSize = 2}

    
    
    // Set the scenario
    var scenario:Int = 0
    let (moveOnS, detachOnS, _, indOnS) = selectors
    let moveOn = (moveOnS == .On); let detachOn = (detachOnS == .On); let indOn = (indOnS == .On)
    
    if !(moveOn || detachOn || indOn) {return ([], [], [])}
    
    var isReserve:Bool = false
    if commandSelected.currentLocationType == .Reserve {isReserve = true}
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
    else {return ([], [], [])}

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
   
    print("Move Scenario: \(scenario)")
    
    switch scenario {
        
    case 1:
        adjAvailableReserves += [currentApproach!.ownReserve!]
        if currentApproach!.adjReserve != nil {adjAvailableReserves += [currentApproach!.adjReserve!]}
        
    case 2:
        break // Handled below
        
    case 3:
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(commandSelected, TwoPlusCorps: false)}
        
    case 4:
        // Must feint by road options
        if groupSelected.allCav {enemyOccupiedMustFeintApproaches = EnemyRdTargets(commandSelected, TwoPlusCorps: true)}
        
    case 5:
        let (activePaths, pathIndices) = ActivePaths(commandSelected)
        if pathIndices == [] {rdBlock = true; break}

        for eachPath in activePaths {
    
            var i:Int = 0; let pathIndex = pathIndices[i]; i++
    
            if moveNumber < (eachPath.count-1) { // Still have moves remaining
                
                if eachPath[pathIndex].has2PlusCorpsPassed {rdBlock = true; continue}
                
                if pathIndex == (eachPath.count-1) {continue} // End of path, no moves left
                else if pathIndex == 0 {  // Can go right only
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex+1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex+1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                }
                else { // Normal case
                    if !(eachPath[pathIndex-1].has2PlusCorpsPassed || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex-1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex-1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex+1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex+1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                }
            }
        }
        finalReserveMoves = Array(Set(finalReserveMoves)) // Ensure the array is unique
        rdAvailableReserves = Array(Set(rdAvailableReserves)) // Ensure the array is unique
        
    case 6:
        let (activePaths, pathIndices) = ActivePaths(commandSelected)
        if pathIndices == [] {rdBlock = true; break}
        
        for eachPath in activePaths {
            
            var i:Int = 0; let pathIndex = pathIndices[i]; i++
            
            if moveNumber < (eachPath.count-1) { // Still have moves remaining
                
                if (eachPath[pathIndex].has2PlusCorpsPassed || eachPath[pathIndex].numberCommandsEntered > 1 || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex].containsAdjacent2PlusCorps)) {rdBlock = true; continue}
                
                if pathIndex == (eachPath.count-1) {continue} // End of path, no moves left
                else if pathIndex == 0 { // Can go right only

                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || eachPath[pathIndex+1].numberCommandsEntered > 0 || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex+1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex+1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                }
                else { // Normal case

                    if !(eachPath[pathIndex+1].has2PlusCorpsPassed || eachPath[pathIndex+1].numberCommandsEntered > 0 || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex+1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex+1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                    if !(eachPath[pathIndex-1].has2PlusCorpsPassed || eachPath[pathIndex-1].numberCommandsEntered > 0 || manager!.actingPlayer.ContainsEnemy(eachPath[pathIndex-1].localeControl)) {rdAvailableReserves += [eachPath[pathIndex-1]]; if (moveNumber == eachPath.count-2) {finalReserveMoves += [eachPath[pathIndex+1]]}}
                }
            }
        }
        
        finalReserveMoves = Array(Set(finalReserveMoves)) // Ensure the array is unique
        rdAvailableReserves = Array(Set(rdAvailableReserves)) // Ensure the array is unique
        
    default: break
        
    }
    
    // Reserve scenarios, all adjacent locations
    if scenario == 2 || scenario == 3 || scenario == 4 {
     
        for eachAdjReserve in currentReserve!.adjReserves {
            
            // This checks if it is a road (if
            for eachReservePath in currentReserve!.rdReserves {
                if eachReservePath[1] == eachAdjReserve {finalReserveMoves += [eachAdjReserve]}
            }
            
            if !eachAdjReserve.has2PlusCorpsPassed {adjAvailableReserves += [eachAdjReserve]}
        }
        
        // Need to take those without a road as the "final" group
        finalReserveMoves = Array(Set(adjAvailableReserves).subtract(Set(finalReserveMoves))) // Ensure the array is unique
        
        for each in currentReserve!.ownApproaches {adjAvailableApproaches += [each]}
        
    }
    
    // Move each enemy occupied adj move into the Attack bucket
    if (scenario == 1 || scenario == 2 || scenario == 3 || scenario == 4) {
        
        for each in adjAvailableReserves {if (manager!.actingPlayer.ContainsEnemy(each.localeControl)) {
            let (_, defenseApproach) = ApproachesFromReserves(currentReserve!, reserve2: each)!
            enemyOccupiedAttackApproaches += [defenseApproach]
            adjAvailableReserves.removeObject(each)
            }
        }
    }
    
    if !rdBlock && !(scenario == 1) && (scenario == 5 || (scenario == 6 && !(currentReserve!.containsAdjacent2PlusCorps == manager?.actingPlayer.Other()))) {
        
        // Allows Cav to move into the approach of a moved-into locale
        if groupSelected.allCav && !undoOrAct {
            if let reserve1 = commandSelected.rdMoves[moveNumber-1] as? Reserve {
                if let reserve2 = commandSelected.rdMoves[moveNumber] as? Reserve {
                    rdAvailableApproaches = CavApproaches(reserve1, currentReserve: reserve2)
                }
            }
        }
    }
    
    // Fill check
    //for each in rdAvailableReserves {if !((each.currentFill + unitCount) <= each.capacity) {rdAvailableReserves.removeObject(each)}}
    
    if moveNumber > 0 {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units (approaches too)
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(rdAvailableReserves))) {
            if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {
                rdAvailableReserves.removeObject(eachReserve)
                for eachApproach in eachReserve.ownApproaches {rdAvailableApproaches.removeObject(eachApproach)}
            }
        }
        
        let rdMoves = rdAvailableReserves as [SKNode] + rdAvailableApproaches as [SKNode]
        //let mustFeintMoves = enemyOccupiedMustFeintApproaches as [SKNode]
        for each in rdMoves {each.hidden = false; each.zPosition = 200}
        
        return (rdMoves, [], [])
        
    } else {
        
        // Remove adjacent reserves that would go beyond capacity with the move if it's the last move of the command / units
        for eachReserve in Array(Set(finalReserveMoves).intersect(Set(adjAvailableReserves))) {if (groupSelected.nonLdrUnitCount + eachReserve.currentFill) > eachReserve.capacity {adjAvailableReserves.removeObject(eachReserve)}}
        
        let adjMoves = adjAvailableReserves as [SKNode] + adjAvailableApproaches as [SKNode]
        let attackThreats = enemyOccupiedAttackApproaches as [SKNode]
        let mustFeintThreats = enemyOccupiedMustFeintApproaches as [SKNode]
        for each in (adjMoves + attackThreats + mustFeintThreats) {each.hidden = false; each.zPosition = 200}
        // "NEW" version would separate rd attacks from adj attacks
        return (adjMoves,  attackThreats, mustFeintThreats)
        
    }
}

func CavApproaches(previousReserve:Reserve, currentReserve:Reserve) -> [Approach] {
    
    var targetApproaches:[Approach] = []
    
    for eachPath in previousReserve.rdReserves {
        
        if eachPath[1] == currentReserve {
            var moveFromApproach:Approach
            (moveFromApproach, _) = ApproachesFromReserves(eachPath[1], reserve2: eachPath[2])!; targetApproaches += [moveFromApproach]
            (moveFromApproach, _) = ApproachesFromReserves(eachPath[1], reserve2: eachPath[0])!; targetApproaches += [moveFromApproach]
        }
    }
    return Array(Set(targetApproaches))
}

func ActivePaths(commandSelected:Command) -> ([[Reserve]],[Int]) {
    
    var rdIndices:[Int] = []
    var currentPath:[Reserve] = []
    var paths:[[Reserve]] = [[]]
    let moveSteps:Int = commandSelected.moveNumber
    
    // Return empty if any approaches, otherwise turn rdMoves into an array of reserves
    for each in commandSelected.rdMoves {
        //print(each.name!)
        if each is Reserve {currentPath += [each as! Reserve]} else {return (paths,rdIndices)}
    }
    
    let rdAvailableReserves = currentPath[0].rdReserves
    
    // Remove reserves where other units entered the reserve area this turn
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

func EnemyRdTargets(commandSelected:Command, TwoPlusCorps:Bool = false) -> [Approach] {

    var targetApproaches:[Approach] = []
    var theReserve:Reserve
    if commandSelected.currentLocation is Reserve {theReserve = commandSelected.currentLocation as! Reserve} else {return []}
    
    switch TwoPlusCorps {
        
    case false:
        
    for eachPath in theReserve.rdReserves {
        for var i = 1; i < eachPath.count; i++ {
            if i == 1 && (eachPath[i].has2PlusCorpsPassed || manager!.actingPlayer.ContainsEnemy(eachPath[i].localeControl))  {break}
            if i > 1 {
            
                if eachPath[i].localeControl == manager?.actingPlayer.Other() {
                    
                    // Found a potential enemy to rd feint
                    var attackToApproach:Approach
                    (_, attackToApproach) = ApproachesFromReserves(eachPath[i-1], reserve2: eachPath[i])!
                    
                    // Double checks that there is capacity if the enemy blocks the feint AND that the approach attacked is is clear
                    //print(eachPath[i-1].currentFill)
                    //print(eachPath[i-1].capacity)
                    //print(eachPath[i].defendersAvailable)
                    //print(eachPath[i])
                    if (eachPath[i-1].currentFill >= eachPath[i-1].capacity && eachPath[i].defendersAvailable) {break}
                    if attackToApproach.occupantCount > 0 {break}

                    targetApproaches += [attackToApproach]
                    break
                    
                } else if eachPath[i].has2PlusCorpsPassed {break}
            }
        }
    }
    
    case true:
    
        for eachPath in theReserve.rdReserves {
            for var i = 1; i < eachPath.count; i++ {
                if i == 1 && (eachPath[i].has2PlusCorpsPassed || eachPath[i].haveCommandsEntered || manager!.actingPlayer.ContainsEnemy(eachPath[i].containsAdjacent2PlusCorps) || manager!.actingPlayer.ContainsEnemy(eachPath[i].localeControl))  {break}
                if i > 1 {

                    if eachPath[i].localeControl == manager?.actingPlayer.Other() {

                        // Found a potential enemy to rd feint
                        var attackToApproach:Approach
                        (_, attackToApproach) = ApproachesFromReserves(eachPath[i-1], reserve2: eachPath[i])!
                        
                        // Double checks that there is capacity if the enemy blocks the feint AND that the approach attacked is is clear
                        if (eachPath[i-1].currentFill >= eachPath[i-1].capacity && eachPath[i].defendersAvailable) {break}
                        if attackToApproach.occupantCount > 0 {break}

                        targetApproaches += [attackToApproach]; break
                        
                    } else if eachPath[i].has2PlusCorpsPassed || eachPath[i].haveCommandsEntered || eachPath[i].containsAdjacent2PlusCorps == manager?.actingPlayer.Other() {break}
                }
            }
        }
    }
    
    return targetApproaches
}

func CheckIfViableAttach(touchedUnit:Unit, groupSelected:Group) -> Bool {
    
    guard let touchedCommand = touchedUnit.parent as? Command else {return false}
    guard let commandSelected = groupSelected.command else {return false}
    guard let unitsSelected = groupSelected.units else {return false}
    var viableCommandSelected:Bool = false
    var viableTouchedSelected:Bool = false
    
    // Check if selected command is viable
    if unitsSelected.count == 1 && unitsSelected[0].unitType != .Ldr {viableCommandSelected = true}
    else if commandSelected.unitCount == 1 && commandSelected.activeUnits[0].unitType != .Ldr {viableCommandSelected = true}
    
    //Check if touched command is viable
    if !((touchedCommand == commandSelected) || (touchedCommand.currentLocation != commandSelected.currentLocation) || touchedCommand.hasLeader == false || touchedCommand.finishedMove == true) {viableTouchedSelected = true}
    
    if viableCommandSelected && viableTouchedSelected {return true} else {return false}
    
}

// Function returns which command options are available
func OrdersAvailable (groupSelected:Group, ordersLeft:(Int, Int) = (1,1)) -> (SelState, SelState, SelState, SelState) {
    
    // Move, Detach, Attach, Independent
    
    guard let commandSelected = groupSelected.command else {return (.Off, .Off, .Off, .Off)}
    guard let unitsSelected = groupSelected.units else {return (.Off, .Off, .Off, .Off)}
    
    let (corpsOrders, indOrders) = ordersLeft
    var attachMove:SelState = .Off
    var corpsMove:SelState = .Off
    var detachMove:SelState = .Off
    var independent:SelState = .Off

    // Corps move verification
    if corpsOrders > 0 {
    
        for each in commandSelected.currentLocation!.occupants {
            each.selector?.selected = .Off
            if each == commandSelected {continue}
            if CheckIfViableAttach(each.units[0], groupSelected: groupSelected) {attachMove = .On; each.selector?.selected = .On}
        }
        
        corpsMove = .On; detachMove = .On; if indOrders > 0 {detachMove = .Option; independent = .On} else {independent = .NotAvail} // Default "On" state is option (1 selected) or On
        
    } else {
        corpsMove = .NotAvail; detachMove = .NotAvail; attachMove = .NotAvail
        if indOrders > 0 {independent = .On}
        else {independent = .NotAvail}
    }

    //print(commandSelected.movedVia)
    // Has moved case - in which case either independent move / corps move again (or attach if there is a viable attach)
    if commandSelected.hasMoved {
        
        if commandSelected.movedVia == .IndMove && groupSelected.fullCommand && !commandSelected.finishedMove {return (.Off, .Off, attachMove, .On)}
        else if commandSelected.movedVia == .CorpsMove && groupSelected.fullCommand && !commandSelected.finishedMove {return (.On, .Off, attachMove, .Off)}
        else {return (.Off, .Off, attachMove, .Off)}
    }
    
    // If command has finished move, return off for all (except if a single unit is selected - could happen if a unit is attached)
    var indUnit:Bool = false
    if unitsSelected.count == 1 && unitsSelected[0].unitType != .Ldr {indUnit = true}
    if commandSelected.finishedMove {
        if indUnit {return (.Off, .Off, attachMove, independent)}
        return (.Off, .Off, attachMove, .Off)
    }
    
    let unitsHaveLeader:Bool = groupSelected.leaderInGroup
    
    // Case: 1 unit selected (most ambiguity is here)
    if commandSelected.unitCount == 1 || unitsSelected.count == 1 {

        if !commandSelected.hasLeader {return (.Off, .Off, attachMove, independent)} // Independent and attach
        else if commandSelected.hasLeader && unitsHaveLeader && unitsSelected[0].unitType != .Ldr {return (corpsMove, .Off, attachMove, .Off)} // Corps move and attach
        else if commandSelected.hasLeader && !unitsHaveLeader && commandSelected.unitCount != 2 {return (.Off, detachMove, attachMove, independent)} // Independent, corps move and detach
        else {return (.Off, .Off, attachMove, .Off)} // Only a leader is selected or 1 non leader selected from a command with a leader and only 1 other unit with it
        
    // Case: 2+ units selected, no leader, can only detach
    } else if unitsSelected.count > 1 && !unitsHaveLeader {
        if detachMove == .Option {detachMove = .On}
        if unitsSelected.count < (commandSelected.activeUnits.count-1) {return (.Off, detachMove, .Off, .Off)} else {return (.Off, .Off, .Off, .Off)}
    
    // Case 3: Corps moves only (2+ units - must have leader)
    } else {
        return (corpsMove, .Off, .Off, .Off)
    }
    
    // Shouldn't go here - if so, all off...
    //return (.Off, .Off, .Off, .Off)
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
    
    for each1 in reserve1.ownApproaches {
        for each2 in reserve2.ownApproaches {
            if each1 == each2.oppApproach {return (each1, each2)}
        }
    }
    return nil // theoretically should never make it through there
}

func UnitsHaveLeader(units:[Unit]) -> Bool {
    for each in units {if each.unitType == .Ldr {return true}}
    return false
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

// MARK: Feint & Retreat Logic

// Returns groups available to defend (in reserve) and true if there are selectable defenders (false if something is on the approach or no defenders available)
func SelectableGroupsFromConflict (theConflict:Conflict) -> [Group] {
    
    var theCommandGroups:[Group] = []

    if (theConflict.defenseApproach.occupantCount > 0) || !(theConflict.defenseReserve.defendersAvailable) {return theCommandGroups}
    
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

/*
// Returns false if all approaches have been resolved
func SetDefenseApproaches(theThreat:(Reserve,[Approach])) -> Bool {
    let (_, theApproaches) = theThreat
    var anyMoreDefenseRequired = false

    for eachApproach in theApproaches {if !eachApproach.defenseRequired {eachApproach.hidden = false; anyMoreDefenseRequired = true} else {eachApproach.hidden = true}}

    return anyMoreDefenseRequired
}
*/

// Returns whether retreat state is ready (on) or still requires action (option)
func RetreatOptions(theThreat:GroupConflict, retreatGroup:[Group]) -> SelState {
    
    for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
    let retreatSelection = GroupSelection(theGroups: retreatGroup)
    if retreatSelection.groupSelectionSize == 0 {return .Option}
    
    
    // Check if reductions are finished for selected units locations
    for eachGroup in retreatGroup {
    //print("Damage Delivered:\(theThreat.damageDelivered[eachGroup.command.currentLocation!])")
    //print("Damage Required:\(theThreat.damageRequired[eachGroup.command.currentLocation!])")
    //print("Destroy Delivered:\(theThreat.destroyDelivered[eachGroup.command.currentLocation!])")
    //print("Destroy Required:\(theThreat.destroyRequired[eachGroup.command.currentLocation!])")
        
        for eachUnit in eachGroup.units {
            if eachUnit.selected == .Selected && theThreat.damageDelivered[eachGroup.command.currentLocation!] < theThreat.damageRequired[eachGroup.command.currentLocation!] {return .Option}
            if eachUnit.selected == .Selected && theThreat.destroyDelivered[eachGroup.command.currentLocation!] < theThreat.destroyRequired[eachGroup.command.currentLocation!] {return .Option}
        }
    }
    
    // Load attacked reserves
    var attackedReserves:[Reserve] = []
    for eachConflict in theThreat.conflicts {attackedReserves += [eachConflict.attackReserve]}
    
    // Load reserves where available area is sufficient
    var adjReservesWithSpace:[Reserve] = []
    for eachReserve in theThreat.defenseReserve.adjReserves {
        if eachReserve.availableSpace >= retreatSelection.groupSelectionSize && eachReserve.localeControl != manager!.actingPlayer.Other() {adjReservesWithSpace += [eachReserve]}
    }
    
    // Reveal available retreat reserves
    var returnOn:Bool = false
    manager!.selectionRetreatReserves = Array(Set(adjReservesWithSpace).subtract(Set(attackedReserves)))
    for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = false; returnOn = true}

    if returnOn {return .On} else {return .NotAvail}
}

// MARK: Leading Units

func SelectableLeadingUnits () {
    
}

// MARK: Toggle Selections

func ToggleCommands(theCommands:[Command], makeSelectable:Bool = true) {
    
    for eachCommand in theCommands {
        eachCommand.selectable = makeSelectable
        for eachUnit in eachCommand.activeUnits {if makeSelectable {eachUnit.selected = .Normal; eachUnit.zPosition = 100} else {eachUnit.selected = .NotSelectable; eachUnit.zPosition = 1}}
    }
}

func ToggleGroups(theGroups:[Group], makeSelection:SelectType = .Normal) {
    
    for eachGroup in theGroups {
        if makeSelection == .Normal || makeSelection == .Selected {eachGroup.command.selectable = true} else {eachGroup.command.selectable = false}
        for eachUnit in eachGroup.units {if eachGroup.command.selectable {eachUnit.selected = makeSelection; eachUnit.zPosition = 100} else {eachUnit.selected = makeSelection; eachUnit.zPosition = 1}}
    }
}

func ActivateDetached(theReserve:Reserve, theGroups:[Group], makeSelection:SelectType = .Normal) {
    for eachGroup in theGroups {
        if !eachGroup.command.hasLeader && eachGroup.command.currentLocation == theReserve {ToggleGroups([eachGroup], makeSelection: makeSelection)}
    }
}


