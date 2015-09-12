//
//  Order.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-22.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

class Order {

    // MARK: Properties
    
    // For drawing the order path
    var orderArrow:SKShapeNode?
    var mainMap:SKSpriteNode?

    // Commands and groups
    //let baseCommand:Command?
    var baseGroup:Group?
    var otherGroup:Group?
    var oldCommand:Command?
    
    var swappedUnit:Unit?
    var newCommands:[Command] = []
    var moveCommands:[Command] = []
    
    // Conflict objects
    var theConflict:Conflict?
    var theGroupConflict:GroupConflict?
    
    // Group receiving orders
    var orderGroup:Group?
    
    // Up to 2 locations possible in an order
    let startLocation:Location?
    let endLocation:Location?
    
    var corpsCommand:Bool?
    
    // Stores the kind of order
    enum OrderType {
        
        case Move, Attach, FeintThreat, NormalThreat, Defend, Reduce, PreRetreat, Commit, Feint, ApproachMove, PostRetreat
    
    }
    
    let order:OrderType!
    var moveType:MoveType?
    var unDoable:Bool = true // Can the order be undone?
    var moveBase:Bool = true // Is the base group the moving group?
    var reverseCode:Int = 1 // Used to store various scenarios that you might want to unwind in reverse (attach only)

    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Initiate order (move, must feint, attack)
    init(groupFromView:Group, touchedNodeFromView:SKNode, orderFromView:OrderType, corpsOrder:Bool?, moveTypePassed:MoveType, mapFromView:SKSpriteNode) {

        baseGroup = groupFromView
        otherGroup = Group(theCommand: baseGroup!.command, theUnits: Array(Set(baseGroup!.command.activeUnits).subtract(Set(baseGroup!.units))))
        
        order = orderFromView // Stores order type (eg. Move, Attach, FeintThreat, etc)
        
        startLocation = baseGroup!.command.currentLocation
        endLocation = touchedNodeFromView as? Location
        
        if order == .Move {mainMap = mapFromView}
        //swappedUnit = nil
        
        corpsCommand = corpsOrder
        moveType = moveTypePassed
        if order == .NormalThreat || order == .FeintThreat {unDoable = false}
    }
    
    // Initiate order (attach)
    init(groupFromView:Group, touchedCommandFromView:Command, orderFromView:OrderType, moveTypePassed:MoveType = .CorpsAttach, corpsOrder:Bool = true) {
        
        //print(commandFromView)
        baseGroup = Group(theCommand: touchedCommandFromView, theUnits: touchedCommandFromView.units)
        oldCommand = groupFromView.command
        swappedUnit = groupFromView.units[0]
        
        order = orderFromView
        
        startLocation = baseGroup!.command.currentLocation
        endLocation = baseGroup!.command.currentLocation
        corpsCommand = corpsOrder
    }
    
    // Initiate order (Defend)
    init(defenseSelection:GroupSelection, passedConflict: Conflict, orderFromView: OrderType) {
        order = orderFromView
        theConflict = passedConflict
        startLocation = theConflict!.defenseReserve
        endLocation = theConflict!.defenseApproach
    }
    
    // Reduce order (Reduce)
    init(theGroup:Group, passedGroupConflict: GroupConflict, orderFromView: OrderType) {
        order = orderFromView
        theGroupConflict = passedGroupConflict
        startLocation = theGroup.command.currentLocation
        endLocation = theGroup.command.currentLocation

        orderGroup = theGroup
    }
    
    // MARK: Order Functions
    
    func ExecuteOrder(theMap:SKSpriteNode?, reverse:Bool = false, playback:Bool = false) -> Bool { // Returns true if the reserve area is overloaded, otherwise false
        
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
        if endLocation!.locationType == .Reserve {endLocaleReserve = (endLocation as? Reserve)}
        else if endLocation!.locationType == .Approach {
            endApproach = endLocation as? Approach
            endLocaleReserve = endApproach?.ownReserve
        }
        if startLocation!.locationType == .Reserve {startLocaleReserve = (startLocation as? Reserve)}
        else if startLocation!.locationType == .Approach {
            startApproach = startLocation as? Approach
            startLocaleReserve = startApproach?.ownReserve
        }
        
        // Adds or removes the order arrow as applicable
        OrderArrow(reverse, theMap: theMap)
        
        switch (reverse, order!) {
        
        // MARK: Normal Move
        case (false, .Move):
        
            // Desintation
            let moveToLocation = endLocation!
            
            if moveType == .CorpsMove {
                moveBase = true
                if otherGroup != nil {
                    
                    for eachUnit in otherGroup!.units {
                        let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                        mainMap!.addChild(nCommand) // Add new command to map
                        baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                        
                        newCommands += [nCommand]; manager!.gameCommands[manager!.actingPlayer]! += [nCommand] // Add new command to orders and game commands
                    }
                    moveCommands = [baseGroup!.command]
                }
            } else if moveType == .CorpsDetach {
                moveBase = false
                for eachUnit in baseGroup!.units {
                    let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                    mainMap!.addChild(nCommand) // Add new command to map
                    baseGroup!.command.passUnitTo(eachUnit, recievingCommand: nCommand)
                    
                    newCommands += [nCommand]; manager!.gameCommands[manager!.actingPlayer]! += [nCommand] // Add new command to orders and game commands
                    
                    moveCommands += [nCommand]
                    baseGroup!.command.movedVia = .CorpsActed
                }
                
            } else if moveType == .IndMove {
                if baseGroup!.fullCommand {
                    moveBase = true
                    moveCommands = [baseGroup!.command]
                } else {
                    moveBase = false
                    let nCommand = Command(creatingCommand: baseGroup!.command, creatingUnits: [])
                    mainMap!.addChild(nCommand) // Add new command to map
                    baseGroup!.command.passUnitTo(baseGroup!.units[0], recievingCommand: nCommand)
                    
                    newCommands += [nCommand]; manager!.gameCommands[manager!.actingPlayer]! += [nCommand] // Add new command to orders and game commands

                    moveCommands = [nCommand]
                }
            } else {
                break
            }
            
            // Move each moving command
            if !playback {
            
                for each in moveCommands {

                    // Sets the new location
                    each.currentLocation = moveToLocation
                    
                    // Update occupants of new location
                    moveToLocation.occupants += [each]
                    startLocation!.occupants.removeObject(each)

                    //if playback {continue}
                    
                    // Update command movement trackers
                    if startLocation?.locationType != .Start {each.moveNumber++} else {each.moveNumber = 0} // # of steps moved
                    if manager!.actingPlayer.ContainsEnemy(endLocaleReserve!.containsAdjacent2PlusCorps) && each.isTwoPlusCorps {each.finishedMove = true}
                    if !moveBase {each.movedVia = moveType!} else {baseGroup!.command.movedVia = moveType!} // Detached move ends move (no road movement)
                    
                    // Movement from or to an approach
                    if (startLocation!.locationType == .Approach || endLocation!.locationType == .Approach) == true {each.finishedMove = true}
                    
                }
                
                // Add the new commands to their occupants if the base moved (if something was detached in the original location
                if moveBase {for each in newCommands {each.currentLocation?.occupants += [each]}}
                
                //if playback {break}
                
                // Update reserves
                if endLocation!.locationType != .Start {for each in endLocaleReserve!.adjReserves {each.UpdateReserveState()}; endLocaleReserve!.UpdateReserveState()}
                if startLocation!.locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
                
                // If we are over capacity, return true
                if endLocaleReserve != nil {if endLocaleReserve!.currentFill > endLocaleReserve!.capacity {return true}}
            
            } else {
                
                for each in moveCommands {
                    
                    // Sets the new location
                    each.currentLocation = moveToLocation
                    
                    // Update occupants of new location
                    moveToLocation.occupants += [each]
                    startLocation!.occupants.removeObject(each)
                    
                }
                
                if moveBase {for each in newCommands {each.currentLocation?.occupants += [each]}}
                
            }
            
            print(endLocation!.locationType, appendNewline: true)
            print("Two Plus Corps?: \(endLocaleReserve!.has2PlusCorps)", appendNewline: true)
            print("Current Fill: \(endLocaleReserve!.currentFill)", appendNewline: true)
            print("Allegience: \(endLocaleReserve!.localeControl)", appendNewline: true)
            print("Rd has 2+ Corps Pass: \(endLocaleReserve!.has2PlusCorpsPassed)", appendNewline: true)
            print("Commands Entered Array: \(endLocaleReserve!.commandsEntered)", appendNewline: true)
            print("Reserve had units go in: \(endLocaleReserve!.numberCommandsEntered)", appendNewline: true)
            print("Adj has 2PLus Corps: \(endLocaleReserve!.containsAdjacent2PlusCorps)", appendNewline: true)
            print("Unit Capacity: \(endLocaleReserve!.capacity)", appendNewline: true)
            print("Unit Count: \(endLocaleReserve!.occupantCount)", appendNewline: true)
            

        // MARK: Reverse Move
        case (true, .Move):
        
            let moveToLocation = startLocation!

            // Add the detached units back to the base command
            for each in newCommands {
                
                if !playback {each.units[0].hasMoved = false}
                if !each.units.isEmpty {each.passUnitTo(each.units[0], recievingCommand: baseGroup!.command)}
                
                // Remove the now command (stays in memory due to orders)
                each.removeFromParent() // Removes from the map
                moveToLocation.occupants.removeObject(each) // Removes from the occupants of current location
                manager!.gameCommands[manager!.actingPlayer]!.removeObject(each) // Removes from the game list
                each.selector = nil // Removes the selector (which has a strong reference with the command)
                
                // Resets movement of command and child units (note that new commands HAD to have moved 1-step only if they moved at all)
                if !playback {each.movedVia = .None}
                
            }
            
            if moveBase {
                
                // Set the base command as the mover
                baseGroup!.command.currentLocation = moveToLocation
                
                // Update occupants
                moveToLocation.occupants += [baseGroup!.command]
                endLocation!.occupants.removeObject(baseGroup!.command)
                
                // Update command movement trackers
                if !playback {
                
                    if endLocation?.locationType != .Start {baseGroup!.command.moveNumber--}  else {baseGroup?.command.rdMoves = []}
                    if baseGroup!.command.moveNumber == 0 {baseGroup!.command.movedVia = .None}
                    baseGroup!.command.finishedMove = false
                    
                }
                
            } else {
                
                if moveType == .CorpsDetach && !playback {baseGroup!.command.movedVia = .None}
            }
            
            if playback {break}
            
            // Update reserves
            if endLocation!.locationType != .Start {for each in endLocaleReserve!.adjReserves {each.UpdateReserveState()}; endLocaleReserve!.UpdateReserveState()}
            if startLocation!.locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            
            // If we are over capacity, return true
            if startLocaleReserve != nil {if startLocaleReserve!.currentFill > startLocaleReserve!.capacity {return true}}
            
        // MARK: Attach
            
        case (false, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !oldCommand!.units.isEmpty {
                oldCommand!.passUnitTo(swappedUnit!, recievingCommand: baseGroup!.command)
                if playback{break}
                
                if oldCommand!.hasMoved {oldCommand!.finishedMove = true; reverseCode = 2} // Captures rare case where you might "drop off" an attached unit and try to move again
                baseGroup!.command.movedVia = .CorpsActed
                
                if startLocation!.locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            }
            
        case (true, .Attach):
            
            // If the units array has something, pass it it's only unit
            if !baseGroup!.command.units.isEmpty {
                baseGroup!.command.passUnitTo(swappedUnit!, recievingCommand: oldCommand!)
                
                // Add back 0-unit commands that were eliminated from the location
                if oldCommand!.unitCount == 1 {oldCommand?.currentLocation?.occupants += [oldCommand!]}
                
                if playback{break}
                
                baseGroup!.command.movedVia = .None
            
                if reverseCode == 2 {oldCommand!.finishedMove = false}
                
                // Update reserves
                if startLocation!.locationType != .Start {for each in startLocaleReserve!.adjReserves {each.UpdateReserveState()}; startLocaleReserve!.UpdateReserveState()}
            
            }
            
        // MARK: Must Feint
            
        case (false, .FeintThreat):
            
            if (endLocation is Approach) {
                
                if playback {break}
                let defenseApproach = (endLocation as! Approach)
                let attackApproach = defenseApproach.oppApproach!
                let defenseReserve = defenseApproach.ownReserve!
                let attackReserve = attackApproach.ownReserve!
                
                // Change this architecture later to add individual conflict
                theConflict = Conflict(aReserve: attackReserve, dReserve: defenseReserve, aApproach: attackApproach, dApproach: defenseApproach, mFeint: true, mRetreat:!defenseReserve.defendersAvailable)
            }
            
            print("Must Feint order", appendNewline: false)
        
        case (true, .FeintThreat):
            
            if playback {break}
            manager!.NewPhase(2, reverse: true, playback: playback)

            print("Must Feint order rescinded", appendNewline: false)
            
        // MARK: Attack
            
        case (false, .NormalThreat):
            
            if playback {break}
            if (endLocation is Approach) {
                
                let defenseApproach = (endLocation as! Approach)
                let attackApproach = defenseApproach.oppApproach!
                let defenseReserve = defenseApproach.ownReserve!
                let attackReserve = attackApproach.ownReserve!
                
                theConflict = Conflict(aReserve: attackReserve, dReserve: defenseReserve, aApproach: attackApproach, dApproach: defenseApproach, mFeint: false, mRetreat:!defenseReserve.defendersAvailable)
            }
        
        case (true, .NormalThreat):
            
            if playback {break}
            manager!.NewPhase(1, reverse: true, playback: playback)
            
            print("Attack order rescinded", appendNewline: false)
            
        case (false, .Defend):
            
            if playback {break}
            //manager!.NewPhase(1, reverse: true, playback: playback)
            
        case (true, .Defend):
            
            if playback {break}
            manager!.NewPhase(1, reverse: true, playback: playback)
            
        case (false, .Reduce):
            
            if orderGroup != nil {
                if !playback {
                    if orderGroup!.units[0].unitType != .Art {
                        theGroupConflict!.damageDelivered[startLocation!] = theGroupConflict!.damageDelivered[startLocation!]! + 1
                    } else {
                        theGroupConflict!.destroyDelivered[startLocation!] = theGroupConflict!.destroyDelivered[startLocation!]! + 1
                    }
                }
                orderGroup!.units[0].decrementStrength()
            }
            
        case (true, .Reduce):
            
            if orderGroup != nil {
                if !playback {
                    if orderGroup!.units[0].unitType != .Art {
                        theGroupConflict!.damageDelivered[startLocation!] = theGroupConflict!.damageDelivered[startLocation!]! - 1
                    } else {
                        theGroupConflict!.destroyDelivered[startLocation!] = theGroupConflict!.destroyDelivered[startLocation!]! - 1
                    }
                }
                orderGroup!.units[0].decrementStrength(false)
            }
            
        default:
        print("Do Nothing", appendNewline: false)
            
        }
        
        return false
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
    
    func OrderArrow(reverse:Bool, theMap:SKSpriteNode?) {
        
        // Skip if dealing with a start location
        if startLocation?.locationType == .Start || endLocation?.locationType == .Start {return Void()}

        // If we are reversing an order, move the arrow
        if reverse && orderArrow != nil {
            
            orderArrow!.removeFromParent()
            
            // Add the arrow
        } else if theMap != nil {
            
            let orderPath = CGPathCreateMutable()
            var strokeColor:SKColor = SKColor()
            var lineWidth:CGFloat = 2.0
            var glowHeight:CGFloat = 1.0
            var zPosition:CGFloat = 1.0
            
            // Draw the path
            if order == .Move || order == .Attach || order == .NormalThreat || order == .Move {
                CGPathMoveToPoint(orderPath, nil, baseGroup!.command.currentLocation!.position.x, baseGroup!.command.currentLocation!.position.y)
                CGPathAddLineToPoint(orderPath, nil, endLocation!.position.x, endLocation!.position.y)
                orderArrow = SKShapeNode(path: orderPath)
            
            } else if order == .FeintThreat {
                
                if let endApproach = endLocation as? Approach {
                    if let startReserve = endApproach.oppApproach?.ownReserve {
                        CGPathMoveToPoint(orderPath, nil, startReserve.position.x, startReserve.position.y)
                        CGPathAddLineToPoint(orderPath, nil, endApproach.position.x, endApproach.position.y)
                        orderArrow = SKShapeNode(path: orderPath)
                    }
                }
            } else if order == .Defend {
                
                if let endApproach = endLocation as? Approach {
                    if let startReserve = endApproach.ownReserve {
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
                
            } else if order == .Defend {
                
                strokeColor = SKColor.brownColor()
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
                theMap!.addChild(orderArrow!)
            }
            
        }
    }
}