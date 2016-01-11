//
//  Order.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-22.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

// Stores the kind of order
enum OrderType {
    case Move, Attach, Threat, Reduce, Surrender, Retreat, Feint, InitialBattle, FinalBattle, Defend, LeadingDefense, LeadingAttack, LeadingCounterAttack, ConfirmAttack, AttackGroupDeclare, RepeatMove
}

class Order {

    // MARK: Properties
    
    // For drawing the order path
    var orderArrow:SKShapeNode?

    // Commands and groups
    var baseGroup:Group?
    var otherGroup:Group?
    var groupSelection:GroupSelection?
    var oldCommands:[Command] = []
    
    var swappedUnit:Unit?
    var newCommands:[Int:[Command]] = [:]
    var moveCommands:[Int:[Command]] = [:]
    var surrenderDict:[Unit:Int] = [:] // Used for the surrender order
    
    // Used to store units / approaches when released for a given corpsGroupConflict
    var unitStorage:[[Unit]] = []
    var approachStorage:[Approach] = []
    
    // Conflict object
    var theConflict:Conflict?
    
    // Group receiving orders
    var orderGroup:Group?
    
    // Up to 2 locations possible in an order
    var startLocation:[Location] = []
    var endLocation:Location
    
    var corpsCommand:Bool?
    
    let order:OrderType!
    var moveType:MoveType?
    var unDoable:Bool = true // Can the order be undone?
    var battleReduction:Bool?
    var reduceLeaderReduction:Unit?
    var moveBase:[Bool] = [] // Is the base group the moving group?
    var reverseCode:Int = 0 // Used to store various scenarios that you might want to unwind in reverse (attach only)
    var reverseCode2:Int = 0
    var reverseString:String = ""
    
    var reverseCavCommit = (false, 0) // Used to store whether the order contained a cav commit and, if so, how much morale it reduced
    var reverseGrdCommit = (false, 0) // Used to store whether the order contained a grd commit and, if so, how much morale it reduced
    
    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print ("DEINIT Order")
    }
    
    // Initiate order (move, Threat)
    init(groupFromView:Group, touchedNodeFromView:SKNode, orderFromView:OrderType, corpsOrder:Bool?, moveTypePassed:MoveType) {

        baseGroup = groupFromView
        otherGroup = Group(theCommand: baseGroup!.command, theUnits: Array(Set(baseGroup!.command.activeUnits).subtract(Set(baseGroup!.units))))
        
        order = orderFromView // Stores order type (eg. Move, Attach, FeintThreat, etc)
        
        startLocation = [baseGroup!.command.currentLocation!]
        endLocation = touchedNodeFromView as! Location
        
        corpsCommand = corpsOrder
        moveType = moveTypePassed
        
        if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
            theConflict = activeConflict
        }
    }
    
    // Initiate order (Attach)
    init(groupFromView:Group, touchedUnitFromView:Unit, orderFromView:OrderType, moveTypePassed:MoveType = .CorpsAttach, corpsOrder:Bool = true) {
        
        baseGroup = groupFromView
        oldCommands = [touchedUnitFromView.parentCommand!]
        swappedUnit = touchedUnitFromView
        
        order = orderFromView
        
        startLocation = [baseGroup!.command.currentLocation!]
        endLocation = baseGroup!.command.currentLocation!
        corpsCommand = corpsOrder
    }
    
    // Initiate order (Retreat, Feint)
    init(passedConflict:Conflict, theGroupSelection:GroupSelection, touchedReserveFromView:Location, orderFromView: OrderType) {
        
        order = orderFromView
        groupSelection = theGroupSelection
        theConflict = passedConflict
        
        var theLocations:[Location] = []
        if groupSelection != nil {for eachGroup in groupSelection!.groups {theLocations += [eachGroup.command.currentLocation!]}}
        
        startLocation = theLocations
        endLocation = touchedReserveFromView
    }
    
    // Reduce order (Reduce)
    init(passedConflict:Conflict, theUnit:Unit, orderFromView: OrderType, battleReduce:Bool = false) {
        order = orderFromView
        theConflict = passedConflict
        startLocation = [theUnit.parentCommand!.currentLocation!]
        endLocation = theUnit.parentCommand!.currentLocation!
        battleReduction = battleReduce
        swappedUnit = theUnit
    }

    // Reduce order (Leading, AttackGroup, Surrender, Defense, Initial battle, Final battle)
    init(passedConflict:Conflict, orderFromView: OrderType) {
        order = orderFromView
        theConflict = passedConflict
        startLocation = [theConflict!.attackReserve!]
        endLocation = theConflict!.defenseApproach!
    }
    
    // Reduce order (Repeat Move)
    init(groupFromView:Group, orderFromView: OrderType) {
        order = orderFromView
        baseGroup = groupFromView
        startLocation = [baseGroup!.command.currentLocation!]
        endLocation = baseGroup!.command.currentLocation!
    }
    
    // MARK: Order Functions
    
    func ExecuteOrder(reverse:Bool = false, playback:Bool = false) -> Bool { // Returns true if the reserve area is overloaded, otherwise false
        
        var overloaded:Bool = false
        
        // Type-casting to get reserve locales
        var endLocaleReserve:Reserve?
        var startLocaleReserve:Reserve?
        let endApproach:Approach?
        let startApproach:Approach?
        
        // Determine whether to increment / decrement orders available ## replace below with simple button move reset (one for each command)
        if (corpsCommand != nil && order != .Threat) && !playback && !(baseGroup!.command.freeCorpsMove && baseGroup!.command.turnEnteredMap == manager!.turn && corpsCommand!) {
            if reverse {
                if corpsCommand! {
                    manager!.corpsCommandsAvail++
                }
                else {
                    manager!.indCommandsAvail++
                }
                if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
                    if theConflict!.phantomCorpsOrder! {manager!.phantomCorpsCommand++} else {manager!.phantomIndCommand++}
                }
            } else {
                if corpsCommand! {
                    manager!.corpsCommandsAvail--
                }
                else {
                    manager!.indCommandsAvail--
                }
                if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
                    if theConflict!.phantomCorpsOrder! {manager!.phantomCorpsCommand--} else {manager!.phantomIndCommand--}
                }
            }
        }
        
        // Casts start and end locations as reserve and approach objects
        if endLocation.locationType == .Reserve {endLocaleReserve = (endLocation as? Reserve)}
        else if endLocation.locationType == .Approach {
            endApproach = endLocation as? Approach
            endLocaleReserve = endApproach?.ownReserve
        }
        if startLocation[0].locationType == .Reserve {startLocaleReserve = (startLocation[0] as? Reserve)}
        else if startLocation[0].locationType == .Approach {
            startApproach = startLocation[0] as? Approach
            startLocaleReserve = startApproach?.ownReserve
        }
        
        switch (reverse, order!) {
        
        // MARK: Move (Corps, Detach, Ind)
            
        case (false, .Move):
        
            // Destination
            let moveToLocation = endLocation

            if !playback {
            
                var newCommandArray:[Command] = []
                var moveCommandArray:[Command] = []

                if moveType == .CorpsMove {
                    
                    moveBase.append(true)
                    if otherGroup != nil {
                        for eachUnit in otherGroup!.units {
                            let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                            NTMap!.addChild(nCommand) // Add new command to map
                            baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                            
                            newCommandArray += [nCommand]
                            manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands
                        }
                        moveCommandArray += [baseGroup!.command]
                    }
                    
                } else if moveType == .CorpsDetach {
                    
                    moveBase.append(false)
                    for eachUnit in baseGroup!.units {
                        let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                        NTMap!.addChild(nCommand) // Add new command to map
                        baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                        
                        newCommandArray += [nCommand]
                        manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands
                        
                        moveCommandArray += [nCommand]
                    }
                    baseGroup!.command.movedVia = .CorpsActed
                    
                } else if moveType == .IndMove {
                    
                    if baseGroup!.fullCommand {
                        moveBase.append(true)
                        moveCommandArray += [baseGroup!.command]
                    } else {
                        moveBase.append(false)
                        
                        let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                        NTMap!.addChild(nCommand) // Add new command to map
                        
                        baseGroup!.command.passUnitTo(baseGroup!.units[0], recievingCommand: nCommand)
                        
                        newCommandArray += [nCommand]
                        manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands

                        moveCommandArray += [nCommand]
                    }
                    
                } else {
                    break
                }

                newCommands[0] = newCommandArray
                moveCommands[0] = moveCommandArray
            
                for eachCommand in moveCommands[0]! {

                    // Sets the new location
                    eachCommand.currentLocation!.occupants.removeObject(eachCommand)
                    moveToLocation.occupants += [eachCommand]
                    eachCommand.currentLocation = moveToLocation
                    
                    // Update command movement trackers
                    if startLocation[0].locationType != .Start && startLocation[0] != endLocation {
                        eachCommand.moveNumber++
                    } else {
                        eachCommand.moveNumber = 0
                        eachCommand.hasMoved = true
                    } // Setup phase moves
                    
                    if manager!.actingPlayer.ContainsEnemy(endLocaleReserve!.containsAdjacent2PlusCorps) && eachCommand.isTwoPlusCorps {eachCommand.finishedMove = true}
                    if startLocation[0] == endLocation {eachCommand.finishedMove = true} // Rare case for attack moves when declaring a move "in place"
                    if moveBase[0] {
                        baseGroup!.command.movedVia = moveType!
                    } else {
                        eachCommand.movedVia = moveType!
                    }
                    
                    // For french reinforcements (flag their second-move is available upon move-out and which turn it entered)
                    if startLocaleReserve != nil && startLocaleReserve!.name == "201" {
                        eachCommand.turnEnteredMap = manager!.turn
                        if !manager!.frReinforcementsCalled {
                            manager!.ReduceMorale(manager!.frCalledReinforcementMoraleCost, side: .French, mayDemoralize: false)
                            manager!.frReinforcementsCalled = true
                            reverseCode2 = 1
                        }
                    }
                    
                    // When the attacker moves into the retreat-area
                    if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare && theConflict != nil {
                        
                        let theMoveCommand = moveCommandArray[0]
                        
                        if theConflict!.parentGroupConflict!.retreatMode && (theConflict!.defenseReserve as Location) == endLocation {

                            // Ind move or corps move AND not a 2-plus corps moving adjacent to enemy 2-plus corps
                            if (moveType == .IndMove || moveType == .CorpsMove) && !(theMoveCommand.unitCount > 1 && manager!.actingPlayer.ContainsEnemy((endLocation as! Reserve).containsAdjacent2PlusCorps)) {
                                
                                reverseCode = theMoveCommand.repeatMoveNumber
                                theMoveCommand.repeatMoveNumber = theMoveCommand.moveNumber
                            }
                            
                            // Releasing committed units
                            for eachConflict in theConflict!.parentGroupConflict!.conflicts {
                                for eachUnit in eachConflict.threateningUnits {
                                    eachUnit.threatenedConflict = nil
                                    reverseString = eachUnit.assigned
                                    eachUnit.assigned = "None"
                                }
                                eachConflict.storedThreateningUnits = eachConflict.threateningUnits
                                eachConflict.threateningUnits = []
                                eachConflict.defenseApproach.approachSelector!.selected = .Off
                                RevealLocation(eachConflict.defenseApproach, toReveal: false)
                                if eachConflict.defenseApproach != theConflict!.defenseApproach {
                                    if eachConflict.phantomCorpsOrder! {manager!.phantomCorpsCommand--}
                                    else {manager!.phantomIndCommand--}
                                }
                            }
                        
                        // When the attacker moves into the feint-area
                        } else if !theConflict!.parentGroupConflict!.retreatMode && theConflict!.defenseApproach.approachSelector!.selected == .Option && ((theConflict!.attackReserve as Location) == endLocation || (theConflict!.attackApproach as Location) == endLocation) {
                            
                            reverseCode = theMoveCommand.repeatMoveNumber
                            
                            for eachUnit in theConflict!.threateningUnits {
                                eachUnit.threatenedConflict = nil
                                reverseString = eachUnit.assigned
                                eachUnit.assigned = "None"
                            }
                            theConflict!.storedThreateningUnits = theConflict!.threateningUnits
                            theConflict!.threateningUnits = []
                            theConflict!.defenseApproach.approachSelector!.selected = .On
                            RevealLocation(theConflict!.defenseApproach, toReveal: false)
                            reverseCode2 = 5
                        
                        }
                        
                    }
                }
                
                // Add the new commands to their occupants if the base moved (if something was detached in the original location
                if moveBase[0] && !newCommands.isEmpty {
                    for each in newCommands[0]! {
                        each.currentLocation?.occupants += [each]
                    }
                } else if baseGroup!.leaderInGroup || otherGroup!.leaderInGroup {
                    swappedUnit = CheckForOneBlockCorps(baseGroup!.command)
                }
                
                // Update reserves
                if endLocation.locationType != .Start {
                    for each in endLocaleReserve!.adjReserves {
                        each.UpdateReserveState()
                    }
                    endLocaleReserve!.UpdateReserveState()
                }
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
                
                // If we are over capacity, return true
                if endLocaleReserve != nil {if endLocaleReserve!.currentFill > endLocaleReserve!.capacity {overloaded = true}}
                
            } else { // playback start
                
                GenericPlayback(0, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: baseGroup!.command)
            }
            
            print(endLocation.locationType, terminator: "\n")
            print("Two Plus Corps?: \(endLocaleReserve!.has2PlusCorps)", terminator: "\n")
            print("Current Fill: \(endLocaleReserve!.currentFill)", terminator: "\n")
            print("Allegience: \(endLocaleReserve!.localeControl)", terminator: "\n")
            print("Rd has 2+ Corps Pass: \(endLocaleReserve!.has2PlusCorpsPassed)", terminator: "\n")
            print("Commands Entered Array: \(endLocaleReserve!.commandsEntered)", terminator: "\n")
            print("Reserve had units go in: \(endLocaleReserve!.numberCommandsEntered)", terminator: "\n")
            print("Adj has 2PLus Corps: \(endLocaleReserve!.containsAdjacent2PlusCorps)", terminator: "\n")
            print("Unit Capacity: \(endLocaleReserve!.capacity)", terminator: "\n")
            print("Block Count: \(endLocaleReserve!.occupantCount)", terminator: "\n")
            
        case (true, .Move):
        
            let moveToLocation = startLocation[0]
            
            if !playback {
                
                // Reversing a move from fr Reserve
                if startLocaleReserve != nil && startLocaleReserve!.name == "201" && moveCommands[0]!.count == 1 {
                    moveCommands[0]![0].turnEnteredMap = -2
                    if reverseCode2 == 1 {
                        manager!.ReduceMorale(-manager!.frCalledReinforcementMoraleCost, side: .French, mayDemoralize: false)
                        manager!.frReinforcementsCalled = false
                    }
                }
                
                // Undoing a move into defense reserve or fulfilling a feint attack
                if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare && theConflict != nil {
                    
                    let theMoveCommand = moveCommands[0]![0]
                    theMoveCommand.repeatMoveNumber = reverseCode
                    
                    if theMoveCommand.moveNumber - theMoveCommand.repeatMoveNumber > 1 {
                        overloaded = true
                    } else {
                        overloaded = false
                    }
                    
                    // Retreat
                    if theConflict!.parentGroupConflict!.retreatMode && (theConflict!.defenseReserve as Location) == endLocation && (moveType == .IndMove || moveType == .CorpsMove) {
                        
                        // re-committed released units
                        for eachConflict in activeGroupConflict!.conflicts {
                            for eachUnit in eachConflict.storedThreateningUnits {
                                eachUnit.threatenedConflict = eachConflict
                                eachUnit.assigned = reverseString
                            }
                            eachConflict.threateningUnits = eachConflict.storedThreateningUnits
                            eachConflict.storedThreateningUnits = []
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            RevealLocation(eachConflict.defenseApproach, toReveal: true)
                            if eachConflict.defenseApproach != theConflict!.defenseApproach {
                                if eachConflict.phantomCorpsOrder! {manager!.phantomCorpsCommand++}
                                else {manager!.phantomIndCommand++}
                            }
                        }
                        
                    // Feint
                    } else if !theConflict!.parentGroupConflict!.retreatMode && ((theConflict!.attackReserve as Location) == endLocation || (theConflict!.attackApproach as Location) == endLocation) && reverseCode2 == 5 {
                        
                        for eachUnit in theConflict!.storedThreateningUnits {
                            eachUnit.threatenedConflict = theConflict!
                            eachUnit.assigned = reverseString
                        }
                        theConflict!.threateningUnits = theConflict!.storedThreateningUnits
                        theConflict!.storedThreateningUnits = []
                        theConflict!.defenseApproach.approachSelector!.selected = .Option
                        RevealLocation(theConflict!.defenseApproach, toReveal: true)
                    }
                    
                }
            
                for eachCommand in moveCommands[0]! {
                    
                    if endLocation.locationType != .Start && startLocation[0] != endLocation {
                        eachCommand.moveNumber--
                    } else {
                        eachCommand.hasMoved = false
                    }
                    
                    if eachCommand.moveNumber == 0 {eachCommand.movedVia = .None}
                }

                if moveType == .CorpsDetach {baseGroup!.command.movedVia = .None}
                
                if swappedUnit != nil {
                    swappedUnit!.hasMoved = false
                }
                
                GenericPlayback(0, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: baseGroup!.command)
                
                // Update reserves
                if endLocation.locationType != .Start {for each in endLocaleReserve!.adjReserves {each.UpdateReserveState()}; endLocaleReserve!.UpdateReserveState()}
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
                
                // If we are over capacity, return true
                if startLocaleReserve != nil {if startLocaleReserve!.currentFill > startLocaleReserve!.capacity { overloaded = true}}
        
            } else { // playback start
                
                GenericPlayback(0, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: baseGroup!.command)
            }

        // MARK: Retreat
        
        case (false, .Retreat):
            
            let moveToLocation = endLocation
            var i = 0
            
            if !playback {

                // Commit morale loss tracker
                guard let theSide = groupSelection?.groups[0].command.commandSide else {break}
                if groupSelection!.containsHeavyCav && !manager!.heavyCavCommited[theSide]! {
                    manager!.heavyCavCommited[theSide] = true
                    let beforeLoss = manager!.morale[theSide]!
                    manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: theSide, mayDemoralize: false)
                    let afterLoss = manager!.morale[theSide]!
                    reverseCavCommit = (true, beforeLoss - afterLoss)
                }
                if groupSelection!.containsGuard && !manager!.guardCommitted[theSide]! {
                    manager!.guardCommitted[theSide] = true
                    let beforeLoss = manager!.morale[theSide]!
                    manager!.ReduceMorale(manager!.guardCommittedCost, side: theSide, mayDemoralize: false)
                    let afterLoss = manager!.morale[theSide]!
                    reverseGrdCommit = (true, beforeLoss - afterLoss)
                }
            
                for eachGroup in groupSelection!.groups {
                    var newCommandArray:[Command] = []
                    var moveCommandArray:[Command] = []
                    
                    oldCommands += [eachGroup.command!]
                    if eachGroup.leaderInGroup { // Remove other units and create commands from them (they remain)
                        moveBase.append(true)
                        let rightHandPriority = manager!.priorityLeaderAndBattle[manager!.actingPlayer]!
                        let leaderRightHand:Unit? = PriorityLoss(eachGroup.nonLdrUnits, unitLossPriority: rightHandPriority)
                        
                        let baseUnits:[Unit] = [eachGroup.leaderUnit!] + [leaderRightHand!]
                        let newUnits = Array(Set(eachGroup.command.activeUnits).subtract(Set(baseUnits)))
                        
                        for eachUnit in newUnits {
                            let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                            NTMap!.addChild(nCommand) // Add new command to map
                            eachGroup.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                            newCommandArray += [nCommand]
                            if eachGroup.units.contains(eachUnit) {moveCommandArray += [nCommand]}
                            manager!.gameCommands[nCommand.commandSide]! += [nCommand]
                        }
                        
                        moveCommandArray += [eachGroup.command]
                        
                    } else if !eachGroup.fullCommand { // Means other units remain in the command so these must be broken off
                        
                        moveBase.append(false)
                        let newUnits = eachGroup.units
                        
                        for eachUnit in newUnits {
                            let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                            NTMap!.addChild(nCommand) // Add new command to map
                            eachGroup.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                            newCommandArray += [nCommand]
                            moveCommandArray += [nCommand]
                            manager!.gameCommands[nCommand.commandSide]! += [nCommand]
                            
                        }
                    } else { // no leader and full command means must be size = 1 which requires no new creating
                        moveCommandArray += [eachGroup.command]
                    }
                    
                    newCommands[i] = newCommandArray
                    moveCommands[i] = moveCommandArray
                    
                    // Add the new commands to the occupant list of their current location
                    for each in newCommands[i]! {
                        each.currentLocation?.occupants += [each]
                    }
                    
                    for eachCommand in moveCommands[i]! {
                        // Sets the new location
                        eachCommand.currentLocation = moveToLocation
                        moveToLocation.occupants += [eachCommand]
                        startLocation[i].occupants.removeObject(eachCommand)
                        //for eachUnit in eachCommand.activeUnits {eachUnit.selected = .NotSelectable}
                    }
                    
                    i++
                }
                
                // Sets up proper retreat reversing
                if !(theConflict != nil && theConflict!.attackReserve == endLocation) && theConflict!.parentGroupConflict!.mustRetreat == false {
                    reverseCode = 2
                    theConflict!.parentGroupConflict!.mustRetreat = true
                }
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            
            } else { // playback
                
                for eachGroup in groupSelection!.groups {
                    let moveToLocation = endLocation
                    GenericPlayback(i, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: eachGroup.command)
                    i++
                }
            }
                
        case (true, .Retreat):
            
            var i = 0
            for eachGroup in groupSelection!.groups {
                let moveToLocation = startLocation[i]
                
                GenericPlayback(i, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: eachGroup.command)
                i++
            }
            
            // May need to release the must-retreat condition
            if !playback {
                
                // Reverse the morale losses
                guard let theSide = groupSelection?.groups[0].command.commandSide else {break}
                if reverseCavCommit.0 {
                    manager!.heavyCavCommited[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseCavCommit.1
                }
                if reverseGrdCommit.0 {
                    manager!.guardCommitted[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseGrdCommit.1
                }

                // Sets up proper retreat reversing
                if theConflict != nil && reverseCode == 2 {
                    theConflict!.parentGroupConflict!.mustRetreat = false
                }

                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            }
            
        // MARK: Feint
            
        case (false, .Feint):
            
            let moveToLocation = endLocation
            var i = 0
            
            if !playback {
            
                for eachGroup in groupSelection!.groups {
                    var newCommandArray:[Command] = []
                    var moveCommandArray:[Command] = []
                 
                    oldCommands += [eachGroup.command!]
                    if eachGroup.leaderInGroup { // Remove other units and create commands from them (they remain)
                        moveBase.append(true)
                        
                        let baseUnits:[Unit] = eachGroup.units
                        let newUnits = Array(Set(eachGroup.command.activeUnits).subtract(Set(baseUnits)))
                        
                        for eachUnit in newUnits {
                            let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                            NTMap!.addChild(nCommand) // Add new command to map
                            eachGroup.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                            newCommandArray += [nCommand]
                            manager!.gameCommands[nCommand.commandSide]! += [nCommand]
                        }
                        
                        moveCommandArray += [eachGroup.command]
                        
                    } else if !eachGroup.fullCommand { // Means other units remain in the command so these must be broken off
                        
                        moveBase.append(false)
                        let newUnits = eachGroup.units
                        
                        for eachUnit in newUnits {
                            let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                            NTMap!.addChild(nCommand) // Add new command to map
                            eachGroup.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                            newCommandArray += [nCommand]
                            moveCommandArray += [nCommand]
                            manager!.gameCommands[nCommand.commandSide]! += [nCommand]
                            
                        }
                    } else { // no leader and full command means must be size = 1 which requires no new creating
                        moveCommandArray += [eachGroup.command]
                    }
                    
                    newCommands[i] = newCommandArray
                    moveCommands[i] = moveCommandArray
                    
                    // Add the new commands to the occupant list of their current location
                    for each in newCommands[i]! {each.currentLocation!.occupants += [each]}
                    
                    for eachCommand in moveCommands[i]! {
                        
                        // Sets the new location
                        eachCommand.currentLocation = moveToLocation
                        moveToLocation.occupants += [eachCommand]
                        startLocation[i].occupants.removeObject(eachCommand)
                    }
                    
                    i++
                }
                
                RevealLocation(theConflict!.defenseApproach, toReveal: false)
                theConflict!.defenseApproach.approachSelector!.selected = .On
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            
            } else {
                
                for eachGroup in groupSelection!.groups {
                    let moveToLocation = endLocation
                    GenericPlayback(i, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: eachGroup.command)
                    i++
                }
            }
            
            
        case (true, .Feint):
            
            var i = 0
            for eachGroup in groupSelection!.groups {
                let moveToLocation = startLocation[i]
                GenericPlayback(i, reverse: reverse, playback: playback, destination: moveToLocation, theCommand: eachGroup.command)
                i++
            }
            
            // May need to release the must-retreat condition
            if !playback {
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
                
                RevealLocation(theConflict!.defenseApproach, toReveal: true)
                theConflict!.defenseApproach.approachSelector!.selected = .Off
            }
            
        // MARK: Attach
            
        case (false, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !oldCommands[0].units.isEmpty {
                
                oldCommands[0].passUnitTo(swappedUnit!, recievingCommand: baseGroup!.command)

                if oldCommands[0].unitCount == 0 {
                    oldCommands[0].currentLocation!.occupants.removeObject(oldCommands[0])
                }
                
                if playback{break}
                
                baseGroup!.command.movedVia = .CorpsActed
                
                // This stores a unit that is flagged for deselection due to being the last unit in a used corps
                reduceLeaderReduction = CheckForOneBlockCorps(oldCommands[0])
                    
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            }
            
        case (true, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !baseGroup!.command.units.isEmpty {
                baseGroup!.command.passUnitTo(swappedUnit!, recievingCommand: oldCommands[0])
                
                // Add back 0-unit commands that were eliminated from the location
                if oldCommands[0].unitCount == 1 {oldCommands[0].currentLocation!.occupants += [oldCommands[0]]}
                
                if playback{break}
                
                baseGroup!.command.movedVia = .None
                
                // This reverses a unit flagged as having moved for being alone with a leader
                if reduceLeaderReduction != nil {reduceLeaderReduction!.hasMoved = false}
                
                // Update reserves
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            
            }
            
        // MARK: Threat
            
        case (false, .Threat):
            
            if playback || !(endLocation is Approach) {break}

            let defenseApproach = (endLocation as! Approach)
            let attackApproach = defenseApproach.oppApproach!
            let defenseReserve = defenseApproach.ownReserve!
            let attackReserve = attackApproach.ownReserve!
            
            let theUnits = baseGroup!.units
            
            // Determines whether its a must-feint
            var mFeint:Bool = false
            let curLocation = theUnits[0].parentCommand!.currentLocation
            if (curLocation != attackApproach && curLocation != attackReserve) || theUnits[0].parentCommand!.repeatMoveNumber > 0 {mFeint = true}

            theConflict = Conflict(aReserve: attackReserve, dReserve: defenseReserve, aApproach: attackApproach, dApproach: defenseApproach, mFeint: mFeint)
            
            for eachUnit in theUnits {
                eachUnit.threatenedConflict = theConflict!
                eachUnit.selected = .NotSelectable
            }
            
            // Assigned the units in the group
            if corpsCommand! {baseGroup!.SetGroupProperty("assignedCorps", onOff: true)}
            else {baseGroup!.SetGroupProperty("assignedInd", onOff: true)}
            
            theConflict!.threateningUnits = theUnits
            
            if corpsCommand! {manager!.phantomCorpsCommand++; theConflict!.phantomCorpsOrder = true}
            else {manager!.phantomIndCommand++; theConflict!.phantomCorpsOrder = false}
            
        case (true, .Threat):
            
            if playback || !(endLocation is Approach) {break}
            
            theConflict!.defenseApproach.threatened = false
            
            var theUnits:[Unit] = []
            if corpsCommand! && moveType == .CorpsDetach {
                theUnits = baseGroup!.units + [baseGroup!.command.theLeader!]
                baseGroup!.command.theLeader!.assigned = "None"
            } else {
                theUnits = baseGroup!.units
            }
            
            for eachUnit in theUnits {
                eachUnit.threatenedConflict = nil
                eachUnit.assigned = "None"
                eachUnit.selected = .Normal
            }
            theConflict!.threateningUnits = []
            
            theConflict!.phantomCorpsOrder = nil
            if corpsCommand! {manager!.phantomCorpsCommand--}
            else {manager!.phantomIndCommand--}

            theConflict = nil

        // MARK: Reduce
        
        case (false, .Reduce):
            
            if !playback {
                
                // Commit morale loss tracker
                guard let theSide = swappedUnit?.unitSide else {break}
                
                if !battleReduction! {
                    if swappedUnit!.unitType != .Art {
                        theConflict!.parentGroupConflict!.damageDelivered[startLocation[0]] = theConflict!.parentGroupConflict!.damageDelivered[startLocation[0]]! + 1
                    } else {
                        theConflict!.parentGroupConflict!.destroyDelivered[startLocation[0]] = theConflict!.parentGroupConflict!.destroyDelivered[startLocation[0]]! + 1
                    }
                    manager!.ReduceMorale(1, side: theSide, mayDemoralize: true)
                }
   
                if swappedUnit!.unitStrength == 3 && swappedUnit!.unitType == .Cav && !manager!.heavyCavCommited[theSide]! {
                    manager!.heavyCavCommited[theSide] = true
                    let beforeLoss = manager!.morale[theSide]!
                    manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: theSide, mayDemoralize: false)
                    let afterLoss = manager!.morale[theSide]!
                    reverseCavCommit = (true, beforeLoss - afterLoss)
                }
                if swappedUnit!.unitType == .Grd && !manager!.guardCommitted[theSide]! {
                    manager!.guardCommitted[theSide] = true
                    let beforeLoss = manager!.morale[theSide]!
                    manager!.ReduceMorale(manager!.guardCommittedCost, side: theSide, mayDemoralize: false)
                    let afterLoss = manager!.morale[theSide]!
                    reverseGrdCommit = (true, beforeLoss - afterLoss)
                }
                
                // Sets up proper reduce reversing
                if theConflict != nil && !battleReduction! && theConflict!.parentGroupConflict!.mustRetreat == false {
                    reverseCode = 2
                    theConflict!.parentGroupConflict!.mustRetreat = true
                }

                swappedUnit!.decrementStrength()
                
                if !battleReduction! && swappedUnit!.parentCommand!.unitsTotalStrength == 0 && swappedUnit!.parentCommand!.hasLeader {
                    swappedUnit!.parentCommand!.theLeader!.decrementStrength(true)
                    if swappedUnit!.unitSide == .French {manager!.player2CorpsCommands--}
                    reduceLeaderReduction = swappedUnit!.parentCommand!.theLeader!
                }
                
                startLocaleReserve!.UpdateReserveState()
                
            } else { // playback
                
                swappedUnit!.decrementStrength()
                if reduceLeaderReduction != nil {swappedUnit!.parentCommand!.theLeader!.decrementStrength(true)}
            }
            
        case (true, .Reduce):
            
            if !playback {
                
                guard let theSide = swappedUnit?.unitSide else {break}
                
                if !battleReduction! {
                    if swappedUnit!.unitType != .Art {
                        theConflict!.parentGroupConflict!.damageDelivered[startLocation[0]] = theConflict!.parentGroupConflict!.damageDelivered[startLocation[0]]! - 1
                    } else {
                        theConflict!.parentGroupConflict!.destroyDelivered[startLocation[0]] = theConflict!.parentGroupConflict!.destroyDelivered[startLocation[0]]! - 1
                    }
                    manager!.ReduceMorale(-1, side: theSide, mayDemoralize: true)
                }
                
                // Reverse a leader-kill
                if reduceLeaderReduction != nil {
                    reduceLeaderReduction!.decrementStrength(false)
                    if reduceLeaderReduction!.unitSide == .French {manager!.player2CorpsCommands++}
                }
                // Reverse unit reduction
                swappedUnit!.decrementStrength(false)
                
                // Reverse the morale losses
                if reverseCavCommit.0 {
                    manager!.heavyCavCommited[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseCavCommit.1
                }
                if reverseGrdCommit.0 {
                    manager!.guardCommitted[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseGrdCommit.1
                }
                // Sets up proper reduce reversing
                if theConflict != nil && !battleReduction! && reverseCode == 2 {
                    theConflict!.parentGroupConflict!.mustRetreat = false
                }
                
                startLocaleReserve!.UpdateReserveState()

            } else {
                
                // Reverse a leader-kill
                if reduceLeaderReduction != nil {
                    reduceLeaderReduction!.decrementStrength(false)
                }
                // Reverse unit reduction
                swappedUnit!.decrementStrength(false)
            }
            
        // MARK: Surrender
        
        case (false, .Surrender):
            
            // Build the surrender dictionary
            if theConflict != nil {
                
                for eachCommand in theConflict!.parentGroupConflict!.defenseReserve.occupants {
                    for eachUnit in eachCommand.units {
                        surrenderDict[eachUnit] = eachUnit.unitStrength
                    }
                }
                for eachApproach in theConflict!.parentGroupConflict!.defenseReserve.ownApproaches {
                    for eachCommand in eachApproach.occupants {
                        for eachUnit in eachCommand.units {
                            surrenderDict[eachUnit] = eachUnit.unitStrength
                        }
                    }
                }
                
                // Commit morale loss tracker
                if !playback {
                    
                    guard let theSide = theConflict!.defenseSide else {break}
                    //print("B4 Surrender Commiting: \(manager!.morale[manager!.phasingPlayer.Other()!]!))")
                    for (eachUnit, _) in surrenderDict {
                        
                        if eachUnit.unitStrength == 3 && eachUnit.unitType == .Cav && !manager!.heavyCavCommited[theSide]! {
                            manager!.heavyCavCommited[theSide] = true
                            let beforeLoss = manager!.morale[theSide]!
                            manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: theSide, mayDemoralize: false)
                            let afterLoss = manager!.morale[theSide]!
                            reverseCavCommit = (true, beforeLoss - afterLoss)
                        }
                        if eachUnit.unitType == .Grd && !manager!.guardCommitted[theSide]! {
                            manager!.guardCommitted[theSide] = true
                            let beforeLoss = manager!.morale[theSide]!
                            manager!.ReduceMorale(manager!.guardCommittedCost, side: theSide, mayDemoralize: false)
                            let afterLoss = manager!.morale[theSide]!
                            reverseGrdCommit = (true, beforeLoss - afterLoss)
                        }
                    }
                    // Execute the surrender dictionary
                    SurrenderUnits(surrenderDict, reduce: true)
                    endLocaleReserve!.UpdateReserveState()
                } else {
                    // Execute the surrender dictionary
                    SurrenderUnits(surrenderDict, reduce: true)
                }
            }
            
        case (true, .Surrender):
            
            // Reverse the morale losses
            if !playback {
                
                guard let theSide = theConflict!.defenseSide else {break}
                if reverseCavCommit.0 {
                    manager!.heavyCavCommited[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseCavCommit.1
                }
                if reverseGrdCommit.0 {
                    manager!.guardCommitted[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseGrdCommit.1
                }
                
                SurrenderUnits(surrenderDict, reduce: false)
                endLocaleReserve!.UpdateReserveState()
                
            } else {
                
                SurrenderUnits(surrenderDict, reduce: false)
            }

            // Check to see if it can be removed for surrender
            endLocaleReserve!.reShuffleLocation()
            for eachApproach in endLocaleReserve!.ownApproaches {eachApproach.reShuffleLocation()}
            
        // MARK: Battle
            
        case (false, .InitialBattle):
            if !playback {theConflict!.InitialResult()}
            // Animate
            
        case (true, .InitialBattle):
            break
            
        case (false, .FinalBattle):
            if !playback {
                
                if theConflict!.attackMoveType == .IndMove {
                    manager!.indCommandsAvail -= theConflict!.attackGroup!.groups.count
                
                } else {
                    
                    for eachGroup in theConflict!.attackGroup!.groups {
                        if !(eachGroup.command.freeCorpsMove && eachGroup.command.turnEnteredMap == manager!.turn) {
                            manager!.corpsCommandsAvail--
                        }
                    }
                }
                theConflict!.ApplyCounterLosses()
                theConflict!.FinalResult()
            }
            // Animate
            
        case (true, .FinalBattle):
            break

        // MARK: Repeat Move
        
        case (false, .RepeatMove):
            
            if playback {break}
            
            reverseCode = baseGroup!.command.moveNumber
            startLocation = baseGroup!.command.rdMoves
            baseGroup!.command.moveNumber = 0
            baseGroup!.command.movedVia = .None
            baseGroup!.command.secondMoveUsed = true
            baseGroup!.command.freeCorpsMove = true
                
        case (true, .RepeatMove):
            
            if playback {break}
            
            baseGroup!.command.freeCorpsMove = false
            baseGroup!.command.secondMoveUsed = false
            baseGroup!.command.rdMoves = startLocation
            baseGroup!.command.moveNumber = reverseCode
            if baseGroup!.leaderInGroup {baseGroup!.command.movedVia = .CorpsMove} else {baseGroup!.command.movedVia = .IndMove}
            
        // MARK: Defend
            
        case (false, .Defend):
            
            if playback {break}
            
            let defenseSelection = GroupSelection(theGroups: manager!.groupsSelectable)
            
            theConflict!.defenseGroup = defenseSelection
            theConflict!.parentGroupConflict!.defendedApproaches += [theConflict!.defenseApproach]
            defenseSelection.SetGroupSelectionPropertyUnitsHaveDefended(true, approachDefended: theConflict!.defenseApproach)
            
            theConflict!.approachDefended = true
            if  theConflict != nil && !theConflict!.parentGroupConflict!.mustDefend {
                reverseCode = 2
                theConflict!.parentGroupConflict!.mustDefend = true
            }
            
        case (true, .Defend):
            
            if playback {break}
            
            if  theConflict != nil && reverseCode == 2 {
                theConflict!.parentGroupConflict!.mustDefend = false
            }
            theConflict!.approachDefended = false
            
            if theConflict!.defenseGroup == nil {break}
            
            theConflict!.defenseGroup!.SetGroupSelectionPropertyUnitsHaveDefended(false, approachDefended: theConflict!.defenseApproach)
            
            ToggleGroups(theConflict!.defenseGroup!.groups, makeSelection: .NotSelectable)
            theConflict!.defenseGroup = nil
            theConflict!.parentGroupConflict!.defendedApproaches.removeObject(theConflict!.defenseApproach)
            
        // MARK: Leading Units
            
        case (false, .LeadingDefense), (false, .LeadingAttack), (false, .LeadingCounterAttack):
            
            if playback {break}
            
            let leadingSelection = GroupSelection(theGroups: manager!.groupsSelectable)
            
            switch order! {
            
            case .LeadingDefense:
                
                theConflict!.defenseLeadingUnits = leadingSelection
                //theConflict!.defenseLeadingSet = true
                
            case .LeadingAttack:
                
                theConflict!.attackLeadingUnits = leadingSelection
                //theConflict!.attackLeadingSet = true
                
            case .LeadingCounterAttack:
                
                theConflict!.counterAttackLeadingUnits = leadingSelection
                //theConflict!.counterAttackLeadingSet = true
            
            default: break
                
            }
            theConflict!.defenseApproach.approachSelector!.selected = .On
            
        case (true, .LeadingDefense), (true, .LeadingAttack), (true, .LeadingCounterAttack):
            
            if playback {break}
            
            switch order! {
                
            case .LeadingDefense:
                
                theConflict!.defenseLeadingUnits = nil
                //theConflict!.defenseLeadingSet = false
                
            case .LeadingAttack:
                
                theConflict!.attackLeadingUnits = nil
                //theConflict!.attackLeadingSet = false
                
            case .LeadingCounterAttack:
                
                theConflict!.counterAttackLeadingUnits = nil
                //theConflict!.counterAttackLeadingSet = false
                
            default: break
            
            }
            theConflict!.defenseApproach.approachSelector!.selected = .Option
        
        // MARK: Confirm Attack
            
        case (false, .ConfirmAttack):
            if playback {break}
            theConflict!.realAttack = true
            theConflict!.defenseApproach.approachSelector!.selected = .On
            
        case (true, .ConfirmAttack):
            if playback {break}
            theConflict!.realAttack = false
            theConflict!.defenseApproach.approachSelector!.selected = .Option
            
        // MARK: Declare Attack Group
            
        case (false, .AttackGroupDeclare):
            if playback {break}
            theConflict!.attackGroup = GroupSelection(theGroups: manager!.groupsSelected)
            if theConflict!.guardAttack {theConflict!.SetGuardAttackGroup()}
            theConflict!.attackMoveType = ReturnMoveType()
            
            // Determine battle width
            let initialDefenseSelection = theConflict!.defenseLeadingUnits!.blocksSelected
            theConflict!.counterAttackLeadingUnits = theConflict!.defenseLeadingUnits // Store for reversing
            theConflict!.defenseLeadingUnits = GroupSelection(theGroups: theConflict!.defenseLeadingUnits!.groups)
            
            if theConflict!.defenseLeadingUnits!.blocksSelected == 2 {theConflict!.wideBattle = true}
            else if initialDefenseSelection == 2 {theConflict!.wideBattle = false}
            else if theConflict!.defenseApproach.wideApproach {theConflict!.wideBattle = true}
            else {theConflict!.wideBattle = false}
            
            theConflict!.counterAttackGroup = GroupSelection(theGroups: theConflict!.availableCounterAttackers!.groups, selectedOnly:false)
            
        case (true, .AttackGroupDeclare):
            if playback {break}
            theConflict!.attackGroup = nil
            theConflict!.guardAttackGroup = nil
            theConflict!.attackMoveType = nil
            theConflict!.defenseLeadingUnits = theConflict!.counterAttackLeadingUnits
            theConflict!.counterAttackLeadingUnits = nil
            
        }
        
        // Adds or removes the order arrow as applicable
        OrderArrow(reverse)
        
        return overloaded
    }
    
    // MARK: Support Functions
    
    // Function for playback reversing
    func GenericPlayback(index:Int = 0, reverse:Bool, playback:Bool, destination:Location, theCommand:Command) {
        
        switch reverse {
            
        case true:
        
            if moveCommands[index] != nil && !moveCommands[index]!.isEmpty {
            
                for eachCommand in moveCommands[index]! {
                    
                    // Sets the new location
                    eachCommand.currentLocation!.occupants.removeObject(eachCommand)
                    destination.occupants += [eachCommand]
                    eachCommand.currentLocation = destination
                    
                }
            }
            
            // Add the detached units back to the base command
            if newCommands[index] != nil && !newCommands[index]!.isEmpty {
                
                if playback && reverse {
                    if unitStorage.count <= index {
                        unitStorage.insert([], atIndex: index)
                    } else {
                        unitStorage[index] = []
                    }
                }
                for eachCommand in newCommands[index]! {
                    
                    if playback && reverse {unitStorage[index] += [eachCommand.activeUnits[0]]}
                    eachCommand.passUnitTo(eachCommand.activeUnits[0], recievingCommand: theCommand)
                    eachCommand.currentLocation!.occupants.removeObject(eachCommand)
                    
                    if !playback {
                        eachCommand.removeFromParent() // Removes from the map
                        manager!.gameCommands[eachCommand.commandSide]!.removeObject(eachCommand) // Removes from the game list
                        eachCommand.selector = nil // Removes the selector (which has a strong reference with the command)
                    }
                }
            }
            
        case false:
            
            if newCommands[index] != nil && !newCommands[index]!.isEmpty {
                var i = 0
                for eachCommand in newCommands[index]! {
                    
                    theCommand.currentLocation!.occupants += [eachCommand]
                    theCommand.passUnitTo(unitStorage[index][i], recievingCommand: eachCommand)
                    i++
                }
            }
            
            if moveCommands[index] != nil && !moveCommands[index]!.isEmpty {
                
                for eachCommand in moveCommands[index]! {
                    
                    // Sets the new location
                    eachCommand.currentLocation!.occupants.removeObject(eachCommand)
                    destination.occupants += [eachCommand]
                    eachCommand.currentLocation = destination
                }
            }
            
        }
    }
    
    // Surrenders the units in the surrender Dict
    func SurrenderUnits(surrenderDict:[Unit:Int], reduce:Bool) {
        for (theUnit, unitStrength) in surrenderDict {
            if reduce {
                var i = unitStrength
                while i > 0 {
                    theUnit.decrementStrength(true)
                    if theUnit.unitType != .Ldr {
                        manager!.ReduceMorale(1, side: manager!.phasingPlayer.Other()!, mayDemoralize: true)
                    } else {
                        if theUnit.unitSide == .French {manager!.player2CorpsCommands--}
                    }
                    i--
                }
            } else {
                var i = 0
                while i < unitStrength {
                    theUnit.decrementStrength(false)
                    theUnit.selected = .NotSelectable // Grey's out the units
                    if theUnit.unitType != .Ldr {
                        manager!.morale[manager!.phasingPlayer.Other()!]! = manager!.morale[manager!.phasingPlayer.Other()!]! + 1
                    } else {
                        if theUnit.unitSide == .French {manager!.player2CorpsCommands++}
                    }
                    i++
                }
            }
        }
    }
    
    func moveRotateAnimation(moveToLocation:Location) -> SKAction {
        
        var extraRotation:CGFloat = 0
        
        // Rotates the block 90 degrees for approaches
        if moveToLocation is Approach {extraRotation = CGFloat(M_PI/2)}
        
        // Setups the move to location and rotation
        let finalPosition:CGPoint = CGPoint(x: moveToLocation.position.x, y: moveToLocation.position.y)
        let moveNode = SKAction.moveTo(finalPosition, duration:0.5)
        let rotateNode = SKAction.rotateToAngle(moveToLocation.zRotation + extraRotation, duration: 0.5, shortestUnitArc: true)
        let moveRotateNode = SKAction.group([moveNode,rotateNode])
        return moveRotateNode
        
    }
    
    func OrderArrow(reverse:Bool) {
        
        // Skip if dealing with a start location
        if startLocation[0].locationType == .Start || endLocation.locationType == .Start {return Void()}

        // If we are reversing an order, move the arrow
        if reverse && orderArrow != nil {
            
            orderArrow!.removeFromParent()
            
        // Add the arrow
        } else if NTMap != nil {
            
            let orderPath = CGPathCreateMutable()
            var strokeColor:SKColor = SKColor()
            var lineWidth:CGFloat = 1.0
            var glowHeight:CGFloat = 1.0
            var zPosition:CGFloat = 1.0
            
            // Draw the path
            if order == .Move {
                CGPathMoveToPoint(orderPath, nil, startLocation[0].position.x, startLocation[0].position.y)
                CGPathAddLineToPoint(orderPath, nil, endLocation.position.x, endLocation.position.y)
                orderArrow = SKShapeNode(path: orderPath)
            
            } else if order == .Retreat {
                CGPathMoveToPoint(orderPath, nil, theConflict!.defenseReserve.position.x, theConflict!.defenseReserve.position.y)
                CGPathAddLineToPoint(orderPath, nil, endLocation.position.x, endLocation.position.y)
                orderArrow = SKShapeNode(path: orderPath)
                
            } else if order == .Threat {
                
                if let endApproach = endLocation as? Approach {
                    if let startReserve = endApproach.oppApproach?.ownReserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
                
            } else if order == .Defend {
                
                if let endApproach = theConflict!.defenseApproach {
                    if let startReserve = theConflict!.defenseReserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
                
            } else if order == .ConfirmAttack {
                
                if let endApproach = theConflict!.defenseApproach {
                    if let startReserve = theConflict!.defenseReserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
                
            } else if order == .LeadingDefense {
                
                if let endApproach = theConflict!.defenseApproach {
                    if let startReserve = theConflict!.defenseReserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
                
            } else if order == .Feint {
                
                if let endApproach = endLocation as? Approach {
                    if let startReserve = startLocation[0] as? Reserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
            }
            
            orderArrow?.userInteractionEnabled = false
            
            if order == .Move {

                
                if baseGroup!.command.commandSide == .French {
                    strokeColor = SKColor.blueColor()
                } else {
                    strokeColor = SKColor.redColor()
                }
                lineWidth = 1.0
                glowHeight = 1.0
                zPosition = 1.0
                
            } else if order == .Retreat {
                
                if moveCommands[0]![0].commandSide == .French {
                    strokeColor = SKColor.blueColor()
                } else {
                    strokeColor = SKColor.redColor()
                }
                lineWidth = 1.0
                glowHeight = 1.0
                zPosition = 1.0
                
            } else if order == .Attach {
                
                // No arrow, maybe do some kind of highlight?
                
            } else if order == .Threat {
                
                if theConflict!.mustFeint {
                    strokeColor = SKColor.purpleColor()
                } else {
                    strokeColor = SKColor.redColor()
                }
                
                lineWidth = 5.0
                glowHeight = 3.0
                zPosition = 1.0
                
            } else if order == .Defend {
                    
                    strokeColor = SKColor.purpleColor()
                    lineWidth = 1.0
                    glowHeight = 1.0
                    zPosition = 1.0
                
            } else if order == .LeadingDefense {
                
                strokeColor = SKColor.purpleColor()
                lineWidth = 4.0
                glowHeight = 2.0
                zPosition = 2.0
                
            } else if order == .Feint {
                
                if theConflict!.defenseSide == .French {
                    strokeColor = SKColor.blueColor()
                } else {
                    strokeColor = SKColor.redColor()
                }
                lineWidth = 1.0
                glowHeight = 1.0
                zPosition = 1.0
                
            } else if order == .ConfirmAttack {
                
                strokeColor = SKColor.purpleColor()
                lineWidth = 7.0
                glowHeight = 3.0
                zPosition = 3.0
                
            }
            
            // Add the arrow
            if orderArrow != nil {
                orderArrow!.strokeColor = strokeColor
                orderArrow!.lineWidth = lineWidth
                orderArrow!.glowWidth = glowHeight
                orderArrow!.zPosition = zPosition
                NTMap!.addChild(orderArrow!)
            } 
        }
    }
}