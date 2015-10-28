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
    
    case Move, Attach, FeintThreat, NormalThreat, Reduce, Surrender, Retreat, Feint, InitialBattle, FinalBattle
    
}

class Order {

    // MARK: Properties
    
    // For drawing the order path
    var orderArrow:SKShapeNode?
    var mainMap:SKSpriteNode?

    // Commands and groups
    var baseGroup:Group?
    var otherGroup:Group?
    var groupSelection:GroupSelection?
    var oldCommands:[Command] = []
    
    var swappedUnit:Unit?
    var newCommands:[Int:[Command]] = [:]
    var moveCommands:[Int:[Command]] = [:]
    var surrenderDict:[Unit:Int] = [:] // Used for the surrender order
    
    // Conflict objects
    var theConflict:Conflict?
    var theGroupConflict:GroupConflict?
    
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
    var reverseCode:Int = 1 // Used to store various scenarios that you might want to unwind in reverse (attach only)
    
    var reverseCavCommit = (false, 0) // Used to store whether the order contained a cav commit and, if so, how much morale it reduced
    var reverseGrdCommit = (false, 0) // Used to store whether the order contained a grd commit and, if so, how much morale it reduced

    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print ("DEINIT Order")
    }
    
    // Initiate order (move, must feint, attack)
    init(groupFromView:Group, touchedNodeFromView:SKNode, orderFromView:OrderType, corpsOrder:Bool?, moveTypePassed:MoveType, mapFromView:SKSpriteNode) {

        baseGroup = groupFromView
        otherGroup = Group(theCommand: baseGroup!.command, theUnits: Array(Set(baseGroup!.command.activeUnits).subtract(Set(baseGroup!.units))))
        
        order = orderFromView // Stores order type (eg. Move, Attach, FeintThreat, etc)
        
        startLocation = [baseGroup!.command.currentLocation!]
        endLocation = touchedNodeFromView as! Location
        
        mainMap = mapFromView
        
        corpsCommand = corpsOrder
        moveType = moveTypePassed
        //if order == .NormalThreat || order == .FeintThreat {unDoable = false}
    }
    
    // Initiate order (attach)
    init(groupFromView:Group, touchedCommandFromView:Command, orderFromView:OrderType, moveTypePassed:MoveType = .CorpsAttach, corpsOrder:Bool = true) {
        
        //print(commandFromView)
        baseGroup = Group(theCommand: touchedCommandFromView, theUnits: touchedCommandFromView.units)
        oldCommands = [groupFromView.command]
        swappedUnit = groupFromView.units[0]
        
        order = orderFromView
        
        startLocation = [baseGroup!.command.currentLocation!]
        endLocation = baseGroup!.command.currentLocation!
        corpsCommand = corpsOrder
    }
    
    // Initiate order (Retreat)
    init(retreatSelection:GroupSelection, passedGroupConflict:GroupConflict, touchedReserveFromView:Location, orderFromView: OrderType, mapFromView:SKSpriteNode) {
        order = orderFromView
        mainMap = mapFromView
        groupSelection = retreatSelection
        theGroupConflict = passedGroupConflict
        
        var theLocations:[Location] = []
        if groupSelection != nil {for eachGroup in groupSelection!.groups {theLocations += [eachGroup.command.currentLocation!]}}
        
        startLocation = theLocations
        endLocation = touchedReserveFromView
    }
    
    // Initiate order (Feint)
    init(retreatSelection:GroupSelection, passedGroupConflict:GroupConflict, touchedApproachFromView:Approach, orderFromView: OrderType, mapFromView:SKSpriteNode) {
        order = orderFromView
        mainMap = mapFromView
        groupSelection = retreatSelection
        theGroupConflict = passedGroupConflict
        
        var theLocations:[Location] = []
        if groupSelection != nil {for eachGroup in groupSelection!.groups {theLocations += [eachGroup.command.currentLocation!]}}
        
        startLocation = theLocations
        endLocation = touchedApproachFromView
    }
    
    // Reduce order (Reduce, BattleReduce)
    init(theUnit:Unit, passedGroupConflict: GroupConflict, orderFromView: OrderType, battleReduce:Bool = false) {
        order = orderFromView
        theGroupConflict = passedGroupConflict
        startLocation = [theUnit.parentCommand!.currentLocation!]
        endLocation = theUnit.parentCommand!.currentLocation!
        battleReduction = battleReduce
        swappedUnit = theUnit
    }
    
    // Reduce order (Surrender, initial battle, final battle)
    init(passedGroupConflict: GroupConflict, orderFromView: OrderType) {
        order = orderFromView
        theGroupConflict = passedGroupConflict
        startLocation = [theGroupConflict!.conflicts[0].attackReserve!]
        endLocation = theGroupConflict!.conflicts[0].defenseApproach!
    }
    
    // MARK: Order Functions
    
    func ExecuteOrder(reverse:Bool = false, playback:Bool = false) -> Bool { // Returns true if the reserve area is overloaded, otherwise false
        
        // Type-casting to get reserve locales
        var endLocaleReserve:Reserve?
        var startLocaleReserve:Reserve?
        let endApproach:Approach?
        let startApproach:Approach?
        
        // Determine whether to increment / decrement orders available
        if (corpsCommand != nil) && !playback {
            if reverse {
                if corpsCommand! {manager?.corpsCommandsAvail++} else {manager?.indCommandsAvail++}
            } else {
                if corpsCommand! {manager?.corpsCommandsAvail--} else {manager?.indCommandsAvail--}
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
        
        // Adds or removes the order arrow as applicable
        OrderArrow(reverse)
        
        switch (reverse, order!) {
        
        // MARK: Move (Corps, Detach, Ind)
            
        case (false, .Move):
        
            // Desintation
            let moveToLocation = endLocation
            var newCommandArray:[Command] = []
            var moveCommandArray:[Command] = []
            
            if moveType == .CorpsMove {
                moveBase.append(true)
                if otherGroup != nil {
                    for eachUnit in otherGroup!.units {
                        let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                        mainMap!.addChild(nCommand) // Add new command to map
                        baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                        
                        newCommandArray += [nCommand]; manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands
                    }
                    moveCommandArray += [baseGroup!.command]
                }
            } else if moveType == .CorpsDetach {
                
                moveBase.append(false)
                for eachUnit in baseGroup!.units {
                    let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                    mainMap!.addChild(nCommand) // Add new command to map
                    baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                    
                    newCommandArray += [nCommand]; manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands
                    
                    moveCommandArray += [nCommand]
                    baseGroup!.command.movedVia = .CorpsActed
                }
                
            } else if moveType == .IndMove {
                
                if baseGroup!.fullCommand {
                    moveBase.append(true)
                    moveCommandArray += [baseGroup!.command]
                } else {
                    moveBase.append(false)
                    let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                    mainMap!.addChild(nCommand) // Add new command to map
                    baseGroup!.command.passUnitTo(baseGroup!.units[0], recievingCommand: nCommand)
                    
                    newCommandArray += [nCommand]; manager!.gameCommands[nCommand.commandSide]! += [nCommand] // Add new command to orders and game commands

                    moveCommandArray += [nCommand]
                }
            } else {
                break
            }
            
            newCommands[0] = newCommandArray
            moveCommands[0] = moveCommandArray
            
            // Move each moving command
            if !playback {
            
                for each in moveCommands[0]! {

                    // Sets the new location
                    each.currentLocation = moveToLocation
                    
                    // Update occupants of new location
                    startLocation[0].occupants.removeObject(each)
                    moveToLocation.occupants += [each]
                    
                    // Update command movement trackers
                    if startLocation[0].locationType != .Start && startLocation[0] != endLocation {each.moveNumber++} else {each.moveNumber = 0} // # of steps moved
                    if manager!.actingPlayer.ContainsEnemy(endLocaleReserve!.containsAdjacent2PlusCorps) && each.isTwoPlusCorps {each.finishedMove = true}
                    if startLocation[0] == endLocation {each.finishedMove = true} // Rare case for attack moves when declaring a move "in place"
                    if !moveBase[0] {each.movedVia = moveType!} else {baseGroup!.command.movedVia = moveType!} // Detached move ends move (no road movement)
                    
                    // Movement from or to an approach
                    if (startLocation[0].locationType == .Approach || endLocation.locationType == .Approach) == true {each.finishedMove = true}
                    
                }
                
                // Add the new commands to their occupants if the base moved (if something was detached in the original location
                if moveBase[0] && !newCommands.isEmpty {for each in newCommands[0]! {each.currentLocation?.occupants += [each]}}
                
                // Update reserves
                if endLocation.locationType != .Start {for each in endLocaleReserve!.adjReserves {each.UpdateReserveState()}; endLocaleReserve!.UpdateReserveState()}
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
                
                // If we are over capacity, return true
                if endLocaleReserve != nil {if endLocaleReserve!.currentFill > endLocaleReserve!.capacity {return true}}
            
            } else {
                
                for each in moveCommands[0]! {
                    
                    // Sets the new location
                    each.currentLocation = moveToLocation
                    
                    // Update occupants of new location
                    startLocation[0].occupants.removeObject(each)
                    moveToLocation.occupants += [each]
                    
                }
                
                if moveBase[0] && !newCommands.isEmpty {for each in newCommands[0]! {each.currentLocation?.occupants += [each]}}
                
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

            // Add the detached units back to the base command
            if !newCommands.isEmpty {
                
                for each in newCommands[0]! {
                    
                    if !playback {each.units[0].hasMoved = false}
                    if !each.units.isEmpty {each.passUnitTo(each.activeUnits[0], recievingCommand: baseGroup!.command)}
                    
                    // Remove the now command (stays in memory due to orders)
                    each.removeFromParent() // Removes from the map
                    endLocation.occupants.removeObject(each) // Removes from the occupants of current location
                    manager!.gameCommands[each.commandSide]!.removeObject(each) // Removes from the game list
                    each.selector = nil // Removes the selector (which has a strong reference with the command)
                    
                    // Resets movement of command and child units (note that new commands HAD to have moved 1-step only if they moved at all)
                    if !playback {each.movedVia = .None}
                }
            }
            
            if moveBase[0] {
                
                // Set the base command as the mover
                baseGroup!.command.currentLocation = moveToLocation
                
                // Update occupants
                moveToLocation.occupants += [baseGroup!.command]
                endLocation.occupants.removeObject(baseGroup!.command)
                
                // Update command movement trackers
                if !playback {
                
                    if endLocation.locationType != .Start {baseGroup!.command.moveNumber--}  else {baseGroup?.command.rdMoves = []}
                    if baseGroup!.command.moveNumber == 0 {baseGroup!.command.movedVia = .None}
                    baseGroup!.command.finishedMove = false
                }
                
            } else {
                
                if moveType == .CorpsDetach && !playback {baseGroup!.command.movedVia = .None}
            }
            
            if playback {break}
            
            // Update reserves
            if endLocation.locationType != .Start {for each in endLocaleReserve!.adjReserves {each.UpdateReserveState()}; endLocaleReserve!.UpdateReserveState()}
            if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            
            // If we are over capacity, return true
            if startLocaleReserve != nil {if startLocaleReserve!.currentFill > startLocaleReserve!.capacity {return true}}
            
        // MARK: Retreat
        
        case (false, .Retreat):
            
            let moveToLocation = endLocation
            var i = -1
            
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
            }
            
            for eachGroup in groupSelection!.groups {
                var newCommandArray:[Command] = []
                var moveCommandArray:[Command] = []
                
                i++
                oldCommands += [eachGroup.command!]
                if eachGroup.leaderInGroup { // Remove other units and create commands from them (they remain)
                    moveBase.append(true)
                    let rightHandPriority = manager!.priorityLeaderAndBattle[manager!.actingPlayer]!
                    let leaderRightHand:Unit? = PriorityLoss(eachGroup.nonLdrUnits, unitLossPriority: rightHandPriority)
                    
                    let baseUnits:[Unit] = [eachGroup.leaderUnit!] + [leaderRightHand!]
                    let newUnits = Array(Set(eachGroup.command.activeUnits).subtract(Set(baseUnits)))
                    
                    for eachUnit in newUnits {
                        let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                        mainMap!.addChild(nCommand) // Add new command to map
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
                        mainMap!.addChild(nCommand) // Add new command to map
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
                for each in newCommands[i]! {each.currentLocation?.occupants += [each]}
                
                for eachCommand in moveCommands[i]! {
                    // Sets the new location
                    eachCommand.currentLocation = moveToLocation
                    moveToLocation.occupants += [eachCommand]
                    startLocation[i].occupants.removeObject(eachCommand)
                }
            }
            
            if !playback {
                
                // Catches the mysterious case of attacker retreats
                if !(theGroupConflict != nil && theGroupConflict!.conflicts[0].attackReserve == endLocation) {
                    theGroupConflict?.retreatOrders++
                    theGroupConflict?.mustRetreat = true
                    manager!.ResetRetreatDefenseSelection()
                }
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            }
                
        case (true, .Retreat):
            
            var i = -1
            for eachGroup in groupSelection!.groups {
                i++
                let moveToLocation = startLocation[i]
                
                // Move the commands to their original locations
                for eachCommand in moveCommands[i]! {
                    eachCommand.currentLocation = moveToLocation
                    moveToLocation.occupants += [eachCommand]
                    endLocation.occupants.removeObject(eachCommand)
                }
                
                // Eliminate the new commands
                if newCommands[i] != nil {
                    
                    for eachCommand in newCommands[i]! {
                        
                        eachCommand.passUnitTo(eachCommand.activeUnits[0], recievingCommand: eachGroup.command) // Sends the unit to their original owner
                        manager!.gameCommands[eachCommand.commandSide]!.removeObject(eachCommand)
                        eachCommand.currentLocation!.occupants.removeObject(eachCommand) // Removes the detached commands from their current location
                        eachCommand.removeFromParent() // Removes the command from the map
                        eachCommand.selector = nil
                    }
                }
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
                // All retreat cases other than attacker retreat
                if !(theGroupConflict != nil && theGroupConflict!.conflicts[0].attackReserve == endLocation) {
                    theGroupConflict?.retreatOrders--
                    if theGroupConflict?.retreatOrders == 0 {theGroupConflict?.mustRetreat = false}
                    manager!.ResetRetreatDefenseSelection()
                }
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            }
            
        // MARK: Feint
            
        case (false, .Feint):
            
            let moveToLocation = endLocation
            var i = -1
            for eachGroup in groupSelection!.groups {
                var newCommandArray:[Command] = []
                var moveCommandArray:[Command] = []
             
                i++
                oldCommands += [eachGroup.command!]
                if eachGroup.leaderInGroup { // Remove other units and create commands from them (they remain)
                    moveBase.append(true)
                    
                    let baseUnits:[Unit] = eachGroup.units
                    let newUnits = Array(Set(eachGroup.command.activeUnits).subtract(Set(baseUnits)))
                    
                    for eachUnit in newUnits {
                        let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                        mainMap!.addChild(nCommand) // Add new command to map
                        eachGroup.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                        newCommandArray += [nCommand]
                        //if eachGroup.units.contains(eachUnit) {moveCommandArray += [nCommand]}
                        manager!.gameCommands[nCommand.commandSide]! += [nCommand]
                    }
                    
                    moveCommandArray += [eachGroup.command]
                    
                } else if !eachGroup.fullCommand { // Means other units remain in the command so these must be broken off
                    
                    moveBase.append(false)
                    let newUnits = eachGroup.units
                    
                    for eachUnit in newUnits {
                        let nCommand = Command(creatingCommand: eachGroup.command, creatingUnits: [])
                        mainMap!.addChild(nCommand) // Add new command to map
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
                for each in newCommands[i]! {each.currentLocation?.occupants += [each]}
                
                for eachCommand in moveCommands[i]! {
                    
                    // Sets the new location
                    eachCommand.currentLocation = moveToLocation
                    moveToLocation.occupants += [eachCommand]
                    startLocation[i].occupants.removeObject(eachCommand)
                    
                }
            }
            
            if !playback {
                theGroupConflict?.retreatOrders++
                theGroupConflict?.mustRetreat = true
                //manager!.ResetRetreatDefenseSelection()
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            }
            
        case (true, .Feint):
            
            var i = -1
            for eachGroup in groupSelection!.groups {
                i++
                let moveToLocation = startLocation[i]
                
                // Move the commands to their original locations
                for eachCommand in moveCommands[i]! {
                    eachCommand.currentLocation = moveToLocation
                    moveToLocation.occupants += [eachCommand]
                    endLocation.occupants.removeObject(eachCommand)
                }
                
                // Eliminate the new commands
                if newCommands[i] != nil {
                    
                    for eachCommand in newCommands[i]! {
                        
                        eachCommand.passUnitTo(eachCommand.activeUnits[0], recievingCommand: eachGroup.command) // Sends the unit to their original owner
                        manager!.gameCommands[eachCommand.commandSide]!.removeObject(eachCommand)
                        eachCommand.currentLocation!.occupants.removeObject(eachCommand) // Removes the detached commands from their current location
                        eachCommand.removeFromParent() // Removes the command from the map
                        eachCommand.selector = nil
                    }
                }
                
            }
            
            // May need to release the must-retreat condition
            if !playback {
                
                theGroupConflict?.retreatOrders--
                if theGroupConflict?.retreatOrders == 0 {theGroupConflict?.mustRetreat = false}
                //manager!.ResetRetreatDefenseSelection()
                
                // Update reserves
                endLocaleReserve!.UpdateReserveState()
                startLocaleReserve!.UpdateReserveState()
            }
            
        // MARK: Attach
            
        case (false, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !oldCommands[0].units.isEmpty {
                oldCommands[0].passUnitTo(swappedUnit!, recievingCommand: baseGroup!.command)
                if playback{break}
                
                if oldCommands[0].hasMoved {oldCommands[0].finishedMove = true; reverseCode = 2} // Captures rare case where you might "drop off" an attached unit and try to move again
                baseGroup!.command.movedVia = .CorpsActed
                
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            }
            
        case (true, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !baseGroup!.command.units.isEmpty {
                baseGroup!.command.passUnitTo(swappedUnit!, recievingCommand: oldCommands[0])
                
                // Add back 0-unit commands that were eliminated from the location
                if oldCommands[0].unitCount == 1 {oldCommands[0].currentLocation?.occupants += [oldCommands[0]]}
                
                if playback{break}
                
                baseGroup!.command.movedVia = .None
            
                if reverseCode == 2 {oldCommands[0].finishedMove = false}
                
                // Update reserves
                if startLocation[0].locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            
            }
            
        // MARK: Must Feint
            
        case (false, .FeintThreat):
            
            if (endLocation is Approach) {
                
                if playback {break}
                let defenseApproach = (endLocation as! Approach)
                let attackApproach = defenseApproach.oppApproach!
                let defenseReserve = defenseApproach.ownReserve!
                let attackReserve = attackApproach.ownReserve!
                
                //print(defenseReserve)
                // Change this architecture later to add individual conflict
                theConflict = Conflict(aReserve: attackReserve, dReserve: defenseReserve, aApproach: attackApproach, dApproach: defenseApproach, mFeint: true)
            }
            
            print("Must Feint order", terminator: "")
        
        case (true, .FeintThreat):
            
            if playback {break}
            //manager!.NewPhase(2, reverse: true, playback: playback)

            print("Must Feint order rescinded", terminator: "")
            
        // MARK: Attack
            
        case (false, .NormalThreat):
            
            if playback {break}
            if (endLocation is Approach) {
                
                let defenseApproach = (endLocation as! Approach)
                let attackApproach = defenseApproach.oppApproach!
                let defenseReserve = defenseApproach.ownReserve!
                let attackReserve = attackApproach.ownReserve!
                
                theConflict = Conflict(aReserve: attackReserve, dReserve: defenseReserve, aApproach: attackApproach, dApproach: defenseApproach, mFeint: false)
            }
        
        case (true, .NormalThreat):
            
            if playback {break}
            //manager!.NewPhase(1, reverse: true, playback: playback)
            
            print("Attack order rescinded", terminator: "")
            
        /*
        
        case (false, .Defend):
            
            if playback {break}
            
            theConflict!.defenseGroup = groupSelection!
            theConflict!.parentGroupConflict!.defendedApproaches += [theConflict!.defenseApproach]
            groupSelection!.SetGroupSelectionPropertyUnitsHaveDefended(true)
            
            theConflict!.parentGroupConflict!.defenseOrders++
            theConflict!.parentGroupConflict!.mustDefend = true
            
        
        
        case (true, .Defend):
            
            if playback {break}
            
            theConflict!.parentGroupConflict!.defendedApproaches.removeObject(theConflict!.defenseApproach)
            theConflict!.defenseGroup!.SetGroupSelectionPropertyUnitsHaveDefended(false)
            theConflict!.defenseGroup = nil
            
            theConflict!.parentGroupConflict!.defenseOrders--
            if theConflict!.parentGroupConflict!.defenseOrders == 0 {theConflict!.parentGroupConflict!.mustDefend = false}
            
        */

        // MARK: Reduce
        
        case (false, .Reduce):
            
            if swappedUnit != nil {
                if !playback && !battleReduction! {
                    if swappedUnit!.unitType != .Art {
                        theGroupConflict!.damageDelivered[startLocation[0]] = theGroupConflict!.damageDelivered[startLocation[0]]! + 1
                    } else {
                        theGroupConflict!.destroyDelivered[startLocation[0]] = theGroupConflict!.destroyDelivered[startLocation[0]]! + 1
                    }
                }
                
                if !playback {
                    
                    // Commit morale loss tracker
                    guard let theSide = swappedUnit?.unitSide else {break}
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
                    
                    // Capture case of reducing a leader's last unit to zero
                    if !battleReduction! && swappedUnit!.parentCommand!.unitsTotalStrength == 0 && swappedUnit!.parentCommand!.hasLeader {
                        swappedUnit!.parentCommand!.theLeader!.decrementStrength(true)
                        if swappedUnit!.unitSide == .French {manager!.player2CorpsCommands--}
                        reduceLeaderReduction = swappedUnit!.parentCommand!.theLeader!
                    }
                }
                
                swappedUnit!.decrementStrength() 
            }
            
        case (true, .Reduce):
            
            if orderGroup != nil {
                
                if !playback && !battleReduction! {
                    if swappedUnit!.unitType != .Art {
                        theGroupConflict!.damageDelivered[startLocation[0]] = theGroupConflict!.damageDelivered[startLocation[0]]! - 1
                    } else {
                        theGroupConflict!.destroyDelivered[startLocation[0]] = theGroupConflict!.destroyDelivered[startLocation[0]]! - 1
                    }
                    
                    // Reverse a leader-kill
                    if reduceLeaderReduction != nil {
                        reduceLeaderReduction!.decrementStrength(false)
                        if reduceLeaderReduction!.unitSide == .French {manager!.player2CorpsCommands++}
                    }
                }
                swappedUnit!.decrementStrength(false)
                
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
                }
            }
            
        // MARK: Surrender
        
        case (false, .Surrender):
            
            // Build the surrender dictionary
            if theGroupConflict != nil {
                
                for eachCommand in theGroupConflict!.defenseReserve.occupants {
                    for eachUnit in eachCommand.units {
                        surrenderDict[eachUnit] = eachUnit.unitStrength
                    }
                }
                for eachApproach in theGroupConflict!.defenseReserve.ownApproaches {
                    for eachCommand in eachApproach.occupants {
                        for eachUnit in eachCommand.units {
                            surrenderDict[eachUnit] = eachUnit.unitStrength
                        }
                    }
                }
                
                // Commit morale loss tracker
                if !playback {
                    

                    guard let theSide = theGroupConflict?.conflict.defenseSide else {break}
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
                }
                //print("After Surrender Commiting: \(manager!.morale[manager!.phasingPlayer.Other()!]!))")
                
                // Execute the surrender dictionary
                SurrenderUnits(surrenderDict, reduce: true)
                startLocaleReserve!.UpdateReserveState()
                //print("After Surrender Reductions: \(manager!.morale[manager!.phasingPlayer.Other()!]!))")
            }
            
        case (true, .Surrender):
            
            // Reverse the morale losses
            if !playback {
                
                guard let theSide = theGroupConflict?.conflicts[0].defenseSide else {break}
                if reverseCavCommit.0 {
                    manager!.heavyCavCommited[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseCavCommit.1
                }
                if reverseGrdCommit.0 {
                    manager!.guardCommitted[theSide] = false
                    manager!.morale[theSide] = manager!.morale[theSide]! + reverseGrdCommit.1
                }
            }
            
            SurrenderUnits(surrenderDict, reduce: false)
            startLocaleReserve!.UpdateReserveState()
            
        // MARK: Battle
            
        case (false, .InitialBattle):
            if !playback {theGroupConflict!.conflicts[0].InitialResult()}
            // Animate
            
        case (true, .InitialBattle):
            break
            
        case (false, .FinalBattle):
            if !playback {

                //theGroupConflict!.SetupRetreatRequirements() <-- This should be done only in the case of attacker victory
                theGroupConflict!.conflict.ApplyCounterLosses()
                theGroupConflict!.conflict.FinalResult()
            }
            // Animate
            
        case (true, .FinalBattle):
            break
            
        // default:
            
        }
        
        return false
    }
    
    // MARK: Support Functions
    
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
        } else if mainMap != nil {
            
            let orderPath = CGPathCreateMutable()
            var strokeColor:SKColor = SKColor()
            var lineWidth:CGFloat = 2.0
            var glowHeight:CGFloat = 1.0
            var zPosition:CGFloat = 1.0
            
            // Draw the path
            if order == .Move || order == .Attach || order == .Move {
                CGPathMoveToPoint(orderPath, nil, baseGroup!.command.currentLocation!.position.x, baseGroup!.command.currentLocation!.position.y)
                CGPathAddLineToPoint(orderPath, nil, endLocation.position.x, endLocation.position.y)
                orderArrow = SKShapeNode(path: orderPath)
            
            } else if order == .FeintThreat || order == .NormalThreat {
                
                if let endApproach = endLocation as? Approach {
                    if let startReserve = endApproach.oppApproach?.ownReserve {
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
                
                strokeColor = SKColor.blueColor()
                lineWidth = 2.0
                glowHeight = 1.0
                zPosition = 1
                
            } else if order == .Attach {
                
                // No arrow
                
            } else if order == .NormalThreat {
                
                strokeColor = SKColor.redColor()
                lineWidth = 5.0
                glowHeight = 3.0
                zPosition = 1
                
            } else if order == .FeintThreat {
                
                strokeColor = SKColor.purpleColor()
                lineWidth = 4.0
                glowHeight = 2.0
                zPosition = 1
                
            } else if order == .Feint {
                
                strokeColor = SKColor.blueColor()
                lineWidth = 4.0
                glowHeight = 2.0
                zPosition = 1
                
            }
            
            // Add the arrow
            if orderArrow != nil {
                orderArrow!.strokeColor = strokeColor
                orderArrow!.lineWidth = lineWidth
                orderArrow!.glowWidth = glowHeight
                //orderArrow!.lineCap = .Square
                orderArrow!.zPosition = zPosition
                mainMap!.addChild(orderArrow!)
            }
            
        }
    }
}