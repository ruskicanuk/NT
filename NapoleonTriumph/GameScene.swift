//
//  GameScene.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright (c) 2015 Justin Anderson. All rights reserved.
//

import SpriteKit
import Foundation

// Main game objects
var manager:GameManager?

class GameScene: SKScene, NSXMLParserDelegate {
    
    // MARK: Main Properties
    
    // Map drawing and menu buttons
    var NTMap:SKSpriteNode?
    var NTMenu:SKNode?
    var undoButton:SKSpriteNode?
    var endTurnButton:SKSpriteNode?
    var terrainButton:SKSpriteNode?
    var fastfwdButton:SKSpriteNode?
    var rewindButton:SKSpriteNode?
    var hideCommandsButton:SKSpriteNode?
    var corpsMoveButton:SKSpriteNode?
    var corpsDetachButton:SKSpriteNode?
    var corpsAttachButton:SKSpriteNode?
    var independentButton:SKSpriteNode?
    var retreatButton:SKSpriteNode?
    var commitButton:SKSpriteNode?
    
    // Playback properties
    var statePoint:ReviewState = .Front
    var selectedStatePoint:ReviewState = .Front
    var fastFwdIndex:Int = 0
    var fastFwdExecuted:CFTimeInterval = 0
    var reCommand:Bool = false
    var undoOrAct:Bool = false
    var disableTouches = false
    
    // Hold touch
    var touchStartTime:CFTimeInterval?
    var holdNode:SKNode?
    
    // Fixed properties?
    var editorPixelWidth:CGFloat = 1267.2
    
    // Available locations
    var adjMoves:[SKNode] = []
    var attackThreats:[SKNode] = []
    var mustFeintThreats:[SKNode] = []
    
    // Group selections
    var selectedGroup:Group?
    var selectableGroups:[Group]?
    var repeatGroup:Group?
    
    // Stores which reserve is currently (switch to group conflict?)
    var activeThreat:GroupConflict?
    
    // Selectors
    var corpsMoveSelector:SpriteSelector?
    var corpsDetachSelector:SpriteSelector?
    var corpsAttachSelector:SpriteSelector?
    var independentSelector:SpriteSelector?
    var retreatSelector:SpriteSelector?
    var commitSelector:SpriteSelector?
    var endTurnSelector:SpriteSelector?
    
    // Name of selection
    let mapName:String = "Map"
    let commandName:String = "Command"
    let unitName:String = "Unit"
    let approachName:String = "Approach"
    let reserveName:String = "Reserve"
    let orderName:String = "Order"
    let undoName:String = "Undo"
    let endTurnName:String = "EndTurn"
    let terrainName:String = "Terrain"
    let fastfwdName:String = "Fastfwd"
    let rewindName:String = "Rewind"
    let corpsMoveName:String = "CorpsMove"
    let corpsDetachName:String = "CorpsDetach"
    let corpsAttachName:String = "CorpsAttach"
    let independentName:String = "Independent"
    let retreatName:String = "Retreat"
    let commitName:String = "Commit"
    
    // Stores whether the commands hidden button was selected
    var commandsHidden:Bool = false
    
    // Stores name of selection
    var selectionCase:String = ""
    
    // MARK: Swiping Properties and Function

    var swipeStartPoint:CGPoint?
    var swipeStart:Bool = false
    var swipeDown:Bool = false
    var swipeUp:Bool = false
    var swipeQueue:Array = [SKNode]()
    var swipeQueueIndex:Int = 0
    var newSwipeQueue:Bool = true
    
    func QueueSwipe (swipeUp:Bool) {
        
        let endOfSwipeQueue = swipeQueue.endIndex - 1
        var nextIndex:Int = 1
        
        if swipeQueue.count == 0 || swipeQueue.count == 1 {return Void()}
        
        if swipeUp {
            
            if swipeQueueIndex == endOfSwipeQueue {nextIndex = 0}
            else {nextIndex = swipeQueueIndex + 1}
            
        } else {
            
            if swipeQueueIndex == 0 {nextIndex = endOfSwipeQueue}
            else {nextIndex = swipeQueueIndex - 1}
        }

        // Elevate z-position of next in index
        if swipeQueue[swipeQueueIndex] is Command {(swipeQueue[swipeQueueIndex] as! Command).SetUnitsZ(100)}
        else {swipeQueue[swipeQueueIndex].zPosition = 200}
        
        if swipeQueue[nextIndex] is Command {(swipeQueue[nextIndex] as! Command).SetUnitsZ(1000)}
        else {swipeQueue[nextIndex].zPosition = 1000}

        swipeQueueIndex = nextIndex
    }
    
    // MARK: Move To View
    
    override func didMoveToView(view: SKView) {
        
        //Build map and menu (eventually roll the menu into game-manager)
        mapScaleFactor = setupMap()
        setupMenu()
        
        // Setup game-manager
        manager = GameManager(theMenu: NTMenu!)
        manager!.setupCommandDashboard()
        
        //Parse xml file to finish map setup
        parseXMLFileWithName("MapBuilder")
        linkApproaches()
        linkReserves()
        
        // Hide the locations
        HideAllLocations(true)
    }
    
    // MARK: Touches
    
    func theTouchedNode(theSelectedNodes:[SKNode], mapLocation:CGPoint, touchedCount:Int = 1) -> SKNode? {
        
        //var highestSceneZ = CGFloat(-1)
        var highestMapZ = CGFloat(-1)
        
        //var countTouchesScene = 0
        var countTouches = 0
        var shortestDistance:CGFloat = 0.0
        
        var touchedNode:SKNode?
        
        for each in theSelectedNodes {
            //print(each)
            
            if let possibleTouch = (each as? Command) {if manager!.actingPlayer.Opposite(possibleTouch.commandSide)! {continue}} // Skip touches on non-acting player
            
            if each is Unit && touchedCount == 2 {
                
                touchedNode = each
                
            } else if each is SKShapeNode {
                
            } else if each.zPosition > highestMapZ {
                
                highestMapZ = each.zPosition
                touchedNode = each
                shortestDistance = DistanceBetweenTwoCGPoints(touchedNode!.position, Position2: mapLocation)
                
            } else if each.zPosition == highestMapZ {
                
                let newDistance:CGFloat = DistanceBetweenTwoCGPoints(each.position, Position2: mapLocation)
                
                if shortestDistance > newDistance {
                    
                    touchedNode = each
                    shortestDistance = newDistance
                }
            }
            
            countTouches++
        }
        
        return touchedNode
        
    }
    
    // Function called when screen is pressed and held for a period of 1 second
    func HoldTouch() {
        
        // Sets up touchedUnit, touchedParent and theGroupConflict
        guard let touchedUnit = holdNode as? Unit else {holdNode = nil; return Void()}
        guard let touchedParent = touchedUnit.parent as? Command else {holdNode = nil; return Void()}
        if manager!.reserveThreats.isEmpty {holdNode = nil; return Void()}
        
        var theReserve:Reserve!
        if touchedParent.currentLocationType == .Reserve {theReserve = touchedParent.currentLocation as! Reserve} else if touchedParent.currentLocationType == .Approach {theReserve = (touchedParent.currentLocation as! Approach).ownReserve}
        guard let theGroupConflict:GroupConflict = manager!.reserveThreats.filter({$0.defenseReserve == theReserve})[0] else {return Void()}
        
        if ReduceStrengthIfRetreat(touchedUnit, theLocation:touchedParent.currentLocation!, theGroupConflict:theGroupConflict, retreatMode:(retreatSelector?.selected == .Option)) {
            ReduceUnitUI(Group(theCommand: touchedParent, theUnits: [touchedUnit]), theGroupConflict:theGroupConflict)
        }
        if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {retreatSelector!.selected = RetreatOptions(theGroupConflict, retreatGroup: manager!.selectableRetreatGroups)}
        
        holdNode = nil
        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches {return Void()}
        // Find the touched nodes
        let touch = touches.first as UITouch!
        let mapLocation:CGPoint? = touch.locationInNode(NTMap!)
        let acceptableDistance:CGFloat = mapScaleFactor*50
        if mapLocation == nil {return Void()}
        let touchedNodesMap = self.nodesAtPoint(mapLocation!)
        //print(swipeQueue.count)
        if newSwipeQueue {
            for eachCommand in manager!.gameCommands[manager!.actingPlayer]! {
                
                let distanceFromCommandSelected = DistanceBetweenTwoCGPoints(eachCommand.position, Position2: mapLocation!)
                if distanceFromCommandSelected < acceptableDistance {
                    swipeQueue += [eachCommand]
                }
            }
        
            swipeQueue = Array(Set(swipeQueue))
            swipeQueueIndex = 0
            newSwipeQueue = false
        }
        
        if !swipeQueue.isEmpty {
            swipeStartPoint = mapLocation
            swipeStart = true
        }
        //print(swipeQueue)
        holdNode = theTouchedNode(touchedNodesMap, mapLocation: mapLocation!)
        touchStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches {return Void()}
        
        // Start if initial tap met the right conditions (Command is selected + tap is close enough)
        //print("swipeStart: \(swipeStart), touchCount: \(touches.count)")
        if swipeStart {
            
            let touch = touches.first as UITouch!
            let mapLocation = touch.locationInNode(NTMap!)
            let yRequiredForSwipe:CGFloat = mapScaleFactor*20.0
            
            //print("mapLocationX: \(mapLocation.x), mapLocationY: \(mapLocation.y), swipeStartPointX: \(swipeStartPoint!.x), swipeStartPointY: \(swipeStartPoint!.y), yRequiredForSwipe: \(yRequiredForSwipe)")
            if swipeStartPoint != nil {

                if (mapLocation.y - swipeStartPoint!.y) > yRequiredForSwipe || (mapLocation.x - swipeStartPoint!.x) > yRequiredForSwipe {
                
                    QueueSwipe(swipeUp)
                    swipeStart = false
                    swipeStartPoint = nil
                    print("Registered swipeUp", appendNewline: true)
                    
                } else if (swipeStartPoint!.y - mapLocation.y) > yRequiredForSwipe || (swipeStartPoint!.x - mapLocation.x) > yRequiredForSwipe {
                
                    QueueSwipe(swipeDown)
                    swipeStart = false
                    swipeStartPoint = nil
                    print("Registered swipeDown", appendNewline: true)
                }
                
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        touchStartTime = nil
        if holdNode == nil {return Void()} else {holdNode = nil}
        if disableTouches {return Void()}

        let touch = touches.first as UITouch!
        
        //Find the selected node within the map and the scene
        let sceneLocation = touch.locationInNode(self)
        let mapLocation = touch.locationInNode(NTMap!)
        
        var touchedNodeScene:SKNode?
        var touchedNode:SKNode? // = NTMap!.nodeAtPoint(mapLocation)

        let touchedCount:Int = touch.tapCount
        
        // Select the highest Z value in the touch
        let touchedNodesScene = self.nodesAtPoint(sceneLocation)
        let touchedNodesMap = self.nodesAtPoint(mapLocation)

        var highestSceneZ = CGFloat(-1)
        
        var countTouchesScene = 0
        
        for each in touchedNodesScene {
        
            if let possibleTouch = (each as? Command) {if manager!.actingPlayer.Opposite(possibleTouch.commandSide)! {continue}} // Skip touches on non-acting player
            
            if each.zPosition > highestSceneZ {
                
                highestSceneZ = each.zPosition
                touchedNodeScene = each
            }
            countTouchesScene++
        }

        // Sets the touched node
        touchedNode = theTouchedNode(touchedNodesMap, mapLocation:mapLocation, touchedCount:touchedCount)
        //print(touchedNodeScene)
        // Exit if in rewind mode
        if statePoint != .Front && touchedNodeScene != fastfwdButton && touchedNodeScene != rewindButton {return Void()}
        
        //What was touched
        if touchedNodeScene == undoButton {selectionCase = undoName; print("UndoTouch", appendNewline: false)}
        else if touchedNodeScene == endTurnButton {if undoOrAct {return Void()}; selectionCase = endTurnName; print("EndTurnTouch", appendNewline: false)}
        else if touchedNodeScene == terrainButton {selectionCase = terrainName; print("HideCommandsTouch", appendNewline: false)}
        else if touchedNodeScene == fastfwdButton {if undoOrAct {return Void()}; selectionCase = fastfwdName; print("FastFwdTouch", appendNewline: false)}
        else if touchedNodeScene == rewindButton {if undoOrAct {return Void()}; selectionCase = rewindName; print("RewindTouch", appendNewline: false)}
        else if touchedNodeScene == corpsMoveButton {selectionCase = corpsMoveName; print("CorpsMoveTouch", appendNewline: false)}
        else if touchedNodeScene == corpsDetachButton {selectionCase = corpsDetachName; print("CorpsDetachTouch", appendNewline: false)}
        else if touchedNodeScene == corpsAttachButton {selectionCase = corpsAttachName; print("CorpsAttachTouch", appendNewline: false)}
        else if touchedNodeScene == independentButton {selectionCase = independentName; print("IndependentTouch", appendNewline: false)}
        else if touchedNodeScene == retreatButton {selectionCase = retreatName; print("RetreatTouch", appendNewline: false)}
        else if touchedNodeScene == commitButton {selectionCase = commitName; print("CommitTouch", appendNewline: false)}
        else {
            
            if touchedNode == NTMap {
                print("MapTouch", appendNewline: true)
                if undoOrAct {return Void()}
                selectionCase = mapName
            } else if touchedNode is Approach {
                print("ApproachTouch", appendNewline: true)
                selectionCase = approachName
            } else if touchedNode is Reserve {
                print("ReserveTouch", appendNewline: true)
                selectionCase = reserveName
            } else if touchedNode is Command {
                print("CommandTouch Units: \((touchedNode as! Command).units.count) Active Units: \((touchedNode as! Command).activeUnits.count)", appendNewline: true)
                //print("CommandChildren: \((touchedNode as! Command).children.count)")
                //print("CommandFrame: \((touchedNode)?.frame)")
                if undoOrAct {return Void()}
                selectionCase = mapName // This triggers map-events for command selections
            } else if touchedNode is Unit {
                print("UnitTouch", appendNewline: true)
                //print("UnitFrame: \((touchedNode)?.frame)")
                if undoOrAct {return Void()}
                selectionCase = unitName
            } else {
                if undoOrAct {return Void()}
                DeselectEverything()
                print("NothingTouch", appendNewline: true)
            }
        }
        
        // Selection Scenario
        var phaseGroup:String = "Move"
        if manager!.phaseOld == .FeintThreat || manager!.phaseOld == .NormalThreat {phaseGroup = "Threat"}
        else if manager!.phaseOld == .NTDefend {phaseGroup = "Commit"}
        else if manager!.phaseOld == .PreRetreat || manager!.phaseOld == .FeintMove {phaseGroup = "Threat"}
        else if manager!.phaseOld == .FeintRespond || manager!.phaseOld == .RealAttack {phaseGroup = "Threat"}
        else if manager!.phaseOld == .LeadingDefense || manager!.phaseOld == .Commit {phaseGroup = "Threat"}
        else if manager!.phaseOld == .PostRetreat || manager!.phaseOld == .ApproachResponse {phaseGroup = "Threat"}
        else {phaseGroup = "Move"}
        
        // Touch Processing
        switch (selectionCase, touchedCount, phaseGroup) {
        
        // MARK: Map Touches
            
        case (unitName,1,"Threat"):
            
            // Gets us the parent command, reserve location and group conflict
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            
            guard let touchedParent = touchedUnit.parent as? Command else {break}
            var theReserve:Reserve!
            if touchedParent.currentLocationType == .Reserve {theReserve = touchedParent.currentLocation as! Reserve} else if touchedParent.currentLocationType == .Approach {theReserve = (touchedParent.currentLocation as! Approach).ownReserve}
            guard let theGroupConflict:GroupConflict = manager!.reserveThreats.filter({$0.defenseReserve == theReserve})[0] else {break}
            
            ThreatUnitSelection(touchedUnit, retreatMode:(retreatSelector?.selected == .On || retreatSelector?.selected == .Option), theTouchedThreat:theGroupConflict)
            if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {retreatSelector!.selected = RetreatOptions(theGroupConflict, retreatGroup: manager!.selectableRetreatGroups)}
                
        case (approachName,1,"Threat"):
            
            guard let touchedApproach = touchedNode as? Approach else {break}
            DefendThreatUI(touchedApproach)
            print("Approach Defend Selected")

        case (reserveName,1,"Threat"):
            
            guard let touchedReserve = touchedNode as? Reserve else {break}
            RetreatUI(touchedReserve)
            print("Reserve Retreat Selected")
            
        case (mapName,1,"Threat"):
            
            if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .Normal)
                retreatSelector!.selected = .Option
            } else {
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .Normal)
            }
            for each in manager!.reserves {each.hidden = true} // Likely want to replace this later with a more elegant solution
        
        case (mapName,1,"Move"):

            DeselectEverything()

        // Clicking approach when something is selected
        case (approachName,1,"Move"):
            
            if touchedNode != nil && selectedGroup != nil {
                if mustFeintThreats.contains(touchedNode!) {MustFeintThreatUI(touchedNode!)}
                else if attackThreats.contains(touchedNode!) {AttackThreatUI(touchedNode!)}
                else {MoveUI(touchedNode!)}
            }
            
        // Clicking reserve when units are selected
        case (reserveName,1,"Move"):
            
            if touchedNode != nil && selectedGroup != nil {MoveUI(touchedNode!)}
   
        // Toggle unit selection
        case (unitName,1,"Move"):
            
            guard let touchedUnit = touchedNode as? Unit else {break}
            if !(touchedUnit.unitSide == manager!.actingPlayer) || touchedUnit.fixed == true || touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            
            // Add code eventually to shade out those who already moved (make them non selectable)
            
            if UpdateSelection(touchedUnit) {
                MoveUnitSelection()
                
                if selectedGroup != nil {
                print("FinishedMove: \(selectedGroup!.command.finishedMove)")
                print("HasMoved: \(selectedGroup!.command.hasMoved)")
                print("MovedVia: \(selectedGroup!.command.movedVia)")
                print("UndoOrAct: \(undoOrAct)")
                //print("FinishedMove: \(selectedGroup!.command.finishedMove)")
                }
            }
            
            // Attach scenario
            else {
                
                // Create an order
                let newOrder = Order(groupFromView: selectedGroup!, touchedCommandFromView: (touchedUnit.parent as! Command), orderFromView: .Attach)
                
                // Execute the order and add to order array
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
                
                DeselectEverything()
                
            }
            
        // MARK: Menu Touches
            
        // Undo
        case (undoName,1,_):
            
            // Ensures there are orders to undo and that we aren't in locked mode
            if manager!.orders.count > 0 && manager!.orders.last!.unDoable {
        
                switch (manager!.phaseOld) {
                    
                case .Move, .PreGame:
                    undoOrAct = manager!.orders.last!.ExecuteOrder(true)

                    if undoOrAct {
                        selectedGroup = manager!.orders.last!.baseGroup!
                        ToggleGroups([selectedGroup!], makeSelection: .Selected)
                        MoveUnitSelection()}
                    else {
                        DeselectEverything()
                    }
                    
                case .NormalThreat, .FeintThreat:
                    
                    manager!.orders.last!.ExecuteOrder(true)
                    
                    if activeThreat != nil {
                        manager!.ResetRetreatDefenseSelection()
                        if CheckTurnEndViableRetreatOrDefend(activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                    }
                    
                default: break
                }

                manager!.orders.removeLast()
                
            }
            
        case (fastfwdName,1,_):
            
            if statePoint == .Middle {
                
                // Remove order arrows from previous turn
                if manager!.orderHistoryTurn > 1 {
                    for eachOrder in manager!.orderHistory[manager!.orderHistoryTurn-1]! {eachOrder.orderArrow?.removeFromParent()}
                }
                
                disableTouches = true
                selectedStatePoint = .Front
                
            } else if statePoint == .Back {
            
                disableTouches = true
                selectedStatePoint = .Middle
            }
            
        case (rewindName,1,_):
            
            // Rewind to the end of the current turn
            if statePoint == .Front {
                
                undoOrAct = false
                DeselectEverything()
                
                for var rewindIndex = manager!.orders.endIndex-1; rewindIndex >= 0; rewindIndex-- {
                    manager!.orders[rewindIndex].ExecuteOrder(true, playback: true)
                }
                selectedStatePoint = .Middle
                statePoint = .Middle
            
            } else if statePoint == .Middle && manager!.orderHistoryTurn > 1 { // Not the first turn and exists orders in the previous turn
                
                undoOrAct = false
                let historicalOrders = manager!.orderHistory[manager!.orderHistoryTurn-1]!
                    for var rewindIndex = historicalOrders.endIndex-1; rewindIndex >= 0; rewindIndex-- {
                    historicalOrders[rewindIndex].ExecuteOrder(true, playback: true)
                }
                selectedStatePoint = .Back
                statePoint = .Back
            }
            
        case (terrainName,1,_):
            
            DeselectEverything()
            commandsHidden = !commandsHidden
            HideAllCommands(commandsHidden)
            HideAllOrderArrows(commandsHidden)
            
        case (corpsDetachName,1,_):

            if corpsDetachSelector?.selected == .Option {
                corpsDetachSelector?.selected = .On
                independentSelector?.selected = .Option
            }
                
        case (independentName,1,_):
            
            if independentSelector?.selected == .Option {
                corpsDetachSelector?.selected = .Option
                independentSelector?.selected = .On
            }
            
        case (retreatName,1,"Threat"):
            
            // In retreat mode, not flagged as must retreat, no reductions made
            if activeThreat!.retreatMode && !activeThreat!.mustRetreat && !activeThreat!.madeReductions {
                retreatSelector?.selected = .Off; activeThreat!.retreatMode = false
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .NotSelectable)
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .Normal)
                for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
            
            // In defend mode, not flagged as must defend
            } else if !activeThreat!.retreatMode && !activeThreat!.mustDefend {
                retreatSelector?.selected = .Option; activeThreat!.retreatMode = true
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .NotSelectable)
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .Normal)
            }
            
        case (commitName,1,"Commit"):
            
            if commitSelector?.selected == .Option {
                commitSelector?.selected = .On
            } else if commitSelector?.selected == .On {
                commitSelector?.selected = .Option
            }
            
        case (endTurnName,1,_):
            
            DeselectEverything()
            //print(endTurnSelector!.selected)
            switch (manager!.phaseOld) {
                
            case .PreGame: manager!.NewTurn()
                
            case .Move:
                var threatRespondMode:Bool = false
                var theCode:String = ""
                
                if endTurnSelector?.selected == .Option {
                    manager!.NewTurn()
                
                // Later swap this out for something that detects if there are ANY threats out there
                } else if endTurnSelector?.selected == .On && manager!.orders.last?.order == .NormalThreat {
                    threatRespondMode = true
                    theCode = manager!.NewPhase(1, reverse: false, playback: false)
                } else if endTurnSelector?.selected == .On && manager!.orders.last?.order == .FeintThreat {
                    threatRespondMode = true
                    theCode = manager!.NewPhase(2, reverse: false, playback: false)
                }
                
                if threatRespondMode {
                    activeThreat = manager!.reserveThreats[0]
                    if theCode == "TurnOnRetreat" {retreatSelector?.selected = .Option}
                    else if theCode == "TurnOnSurrender" {
                        let newOrder = Order(passedGroupConflict: activeThreat!, orderFromView: .Surrender)
                        newOrder.ExecuteOrder()
                        newOrder.unDoable = false // Can't undo surrender
                        manager!.orders += [newOrder]
                        retreatSelector?.selected = .Option
                    }
                    else {retreatSelector?.selected = .Off}
                    
                    if CheckTurnEndViableRetreatOrDefend(activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                    break
                }
                
            case .NormalThreat, .FeintThreat:
                
                if activeThreat != nil {
                    endTurnSelector?.selected = .Off
                    if activeThreat!.retreatMode {
                        manager!.NewPhase(2, reverse: false, playback: false)
                    } else {
                        if manager!.phaseOld == .NormalThreat {commitSelector?.selected = .Option} // Makes it option if you can click it
                        manager!.NewPhase(1, reverse: false, playback: false)
                    }
                }
                
            default:
                break
                
                
            }
            
        default:
            DeselectEverything()
        }
    }
    
    // MARK: UI Orders
    
    // Order to move (corps, detach or independent)
    func MoveUI(touchedNodeFromView:SKNode) {
        
        var corpsCommand:Bool?
        if manager?.phaseOld == .PreGame || selectedGroup!.command.hasMoved == true {corpsCommand == nil} else {corpsCommand = !(independentSelector?.selected == .On)}
        
        // Create a new order
        let newOrder = Order(groupFromView: selectedGroup!, touchedNodeFromView: touchedNodeFromView, orderFromView: .Move, corpsOrder: !(independentSelector?.selected == .On), moveTypePassed: ReturnMoveType(), mapFromView:NTMap!)
        
        undoOrAct = newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        if newOrder.moveCommands[0]!.count == 1 && (newOrder.moveType == .CorpsMove || newOrder.moveType == .IndMove) && (!newOrder.moveCommands[0]![0].finishedMove) {
            selectedGroup = Group(theCommand: newOrder.moveCommands[0]![0], theUnits: selectedGroup!.units)
            MoveUnitSelection()
            if adjMoves.isEmpty {DeselectEverything()}
        } else {DeselectEverything()}

        //if !repeatGroup!.command.finishedMove {fastFwdExecuted = 0; disableTouches = true; reCommand = true}
    }
    
    // Order to threaten (may later attack or feint)
    func AttackThreatUI(touchedNodeFromView:SKNode) {
        
        // Create an order, execute and deselect everything
        let newOrder = Order(groupFromView: selectedGroup!, touchedNodeFromView: touchedNodeFromView, orderFromView: .NormalThreat, corpsOrder: nil, moveTypePassed: ReturnMoveType(), mapFromView:NTMap!)
        
        endTurnSelector?.selected = .On
        
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        DeselectEverything()
        
    }
    
    // Order to threaten an approach (must feint)
    func MustFeintThreatUI(touchedNodeFromView:SKNode) {
        
        // Create an order, execute and deselect everything
        let newOrder = Order(groupFromView: selectedGroup!, touchedNodeFromView: touchedNodeFromView, orderFromView: .FeintThreat, corpsOrder: nil, moveTypePassed: ReturnMoveType(), mapFromView:NTMap!)
        
        endTurnSelector?.selected = .On
        
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        DeselectEverything()
        
    }
    
    // Order to defend
    func DefendThreatUI(touchedNodeFromView:Approach) {

        if activeThreat == nil {return Void()}

        guard let conflictSelected:Conflict = manager!.approachThreats[touchedNodeFromView]! else {return Void()}
        if conflictSelected.approachConflict {return Void()} // Approach conflicts do not get extra defenders
        if conflictSelected.parentGroupConflict!.defendedApproaches.contains(touchedNodeFromView) {return Void()} // If defenders have already been sent
        
        let defenseSelection = GroupSelection(theGroups: manager!.selectableDefenseGroups)
        if defenseSelection.groupSelectionSize == 0 {return Void()} // No units selected
  
        let newOrder = Order(defenseSelection: defenseSelection, passedConflict: conflictSelected, orderFromView: .Defend, mapFromView:NTMap! )
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        manager!.ResetRetreatDefenseSelection()
        if CheckTurnEndViableRetreatOrDefend(activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
        //let theCode = manager!.NewPhase(1, reverse: false, playback: false)
        //if theCode == "TurnOnRetreat" {retreatSelector?.selected = .On}
        //else {}
        
    }
    
    // Order to retreat
    func RetreatUI(touchedNodeFromView:Reserve) {
        
        if activeThreat == nil {return Void()}
        
        let retreatSelection = GroupSelection(theGroups: manager!.selectableRetreatGroups)
        
        let newOrder = Order(retreatSelection: retreatSelection, passedGroupConflict:activeThreat!, touchedReserveFromView: touchedNodeFromView, orderFromView: .Retreat, mapFromView:NTMap!)
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        // Hide the selected reserve
        touchedNodeFromView.hidden = true
        
        // Resets selectable defense group - only way that this is false is if we are in a surrender
        let theCode = manager!.ResetRetreatDefenseSelection()
        if theCode == "TurnOnRetreat" {
            retreatSelector?.selected = .Option
        } else if theCode == "TurnOnSurrender" {
            let newOrder = Order(passedGroupConflict: activeThreat!, orderFromView: .Surrender)
            newOrder.ExecuteOrder()
            newOrder.unDoable = false
            manager!.orders += [newOrder]
            retreatSelector?.selected = .Option
        }
        
        if CheckTurnEndViableRetreatOrDefend(activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
        
    }
    
    // Order to reduce unit strength
    func ReduceUnitUI(passedGroup:Group, theGroupConflict:GroupConflict) {
        
        // Create an order
        let newOrder = Order(theGroup: passedGroup, passedGroupConflict:theGroupConflict, orderFromView: .Reduce)
        
        // Execute the order and add to order array
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        // Toggles to normal
        //ToggleGroups([passedGroup], makeSelection: .Normal)
        //retreatSelector!.selected = RetreatOptions(theGroupConflict, retreatGroup: manager!.selectableRetreatGroups)
        
        manager!.ResetRetreatDefenseSelection()
        if CheckTurnEndViableRetreatOrDefend(activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
    }
    
    // Fast-fwd cycle
    func CycleOrdersFwd(direction:Bool = true) {

        switch (statePoint, direction) {
            
        case (.Back, true):
            
            if manager!.orderHistoryTurn == 1 || fastFwdIndex == manager!.orderHistory[manager!.orderHistoryTurn-1]!.endIndex {fastFwdIndex = 0; statePoint = .Middle; disableTouches = false}
            else {
                let historicalOrders = manager!.orderHistory[manager!.orderHistoryTurn-1]!

                undoOrAct = historicalOrders[fastFwdIndex].ExecuteOrder(false, playback: true)
                
                fastFwdIndex++
            }
            
        case (.Middle, true):
        
            if fastFwdIndex == manager!.orders.endIndex {fastFwdIndex = 0; statePoint = .Front; disableTouches = false}
            else {
                let historicalOrders = manager!.orders
                //print(fastFwdIndex)
                undoOrAct = historicalOrders[fastFwdIndex].ExecuteOrder(false, playback: true)
                if undoOrAct && (fastFwdIndex == manager!.orders.endIndex-1) {repeatGroup = selectedGroup!; DeselectEverything(); fastFwdExecuted = 0; disableTouches = true; reCommand = true} else {DeselectEverything()}
                
                fastFwdIndex++
            }
        
        default:
            break
            
        }
    }
    
    // MARK: Update
    
    // Runs several times a second
    override func update(currentTime: CFTimeInterval) {
        
        // Holding down functionality
        if touchStartTime != nil {
            let touchHoldTime = CFAbsoluteTimeGetCurrent() - touchStartTime!
            if touchHoldTime > 1.0 {HoldTouch(); touchStartTime = nil; holdNode = nil}
        }
        
        // Playback functionality (a little fidgety but it works...)
        if fastFwdExecuted == 0 {fastFwdExecuted = currentTime}
        let theInterval = currentTime - fastFwdExecuted
        
        if  statePoint != .Front && ((selectedStatePoint == .Front && statePoint == .Middle) || (selectedStatePoint == .Middle && statePoint == .Back)) && theInterval > 0.7 {
            fastFwdExecuted = currentTime
            CycleOrdersFwd()
        }
        
        /*
        if reCommand && theInterval > 0.6 {
            if repeatGroup != nil {MoveUnitSelection()}
            reCommand = false
            disableTouches = false
        }
        */
    }
    
    // MARK: Setup Map / Parse XML
    
    // Calls parser
    func parseXMLFileWithName(name:NSString){
        
        let path:String = NSBundle.mainBundle().pathForResource(name as String, ofType: "xml")!
        let data:NSData = NSData(contentsOfFile:path)!
        let parser:NSXMLParser = NSXMLParser(data: data)
        
        parser.delegate = self
        parser.parse()
    }
    
    // Parses the xml file
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        let type:AnyObject? = attributeDict["type"]
        
        switch type as? String {
            
        case "Approach"?:
            
            let xmlDict = attributeDict
            let newApproach:Approach = Approach(theDict: xmlDict, scaleFactor: mapScaleFactor, reserveLocation:false)
            NTMap!.addChild(newApproach)
            manager!.approaches += [newApproach]
            
        case "Reserve"?:
            
            let xmlDict = attributeDict
            let newReserve:Reserve = Reserve(theDict: xmlDict, scaleFactor: mapScaleFactor, reserveLocation:true)
            NTMap!.addChild(newReserve)
            manager!.reserves += [newReserve]
            
        case "Command"?:
            
            let xmlDict = attributeDict
            let newCommand:Command = Command(theDict: xmlDict)
            
            if newCommand.loc == "Reserve" {
            
                newCommand.currentLocation?.occupants.removeObject(newCommand)
                newCommand.currentLocation = manager!.reserves.filter { $0.name == newCommand.locID }.first
                newCommand.moveNumber = 0
                
            } else if newCommand.loc == "Approach" {
                
                newCommand.currentLocation?.occupants.removeObject(newCommand)
                newCommand.currentLocation = manager!.approaches.filter { $0.name == newCommand.locID }.first
                newCommand.moveNumber = 0
            }
            
            newCommand.currentLocation?.occupants += [newCommand]
            
            NTMap!.addChild(newCommand)
            manager!.gameCommands[newCommand.commandSide]! += [newCommand]
            
        default:
            break
        }
        
    }
    
    // Setup map
    func setupMap () -> CGFloat {
        
        NTMap = SKSpriteNode(imageNamed: "MapBoardMedium")
        
        if NTMap != nil {
        
        var setMapX:CGFloat
        var setMapY:CGFloat
        let sceneSizeX:CGFloat = self.size.width
        let sceneSizeY:CGFloat = self.size.height
        let mapSizeX:CGFloat = NTMap!.size.width
        let mapSizeY:CGFloat = NTMap!.size.height
            
        let sceneAspect:CGFloat = sceneSizeY / sceneSizeX
        let mapAspect:CGFloat = mapSizeY / mapSizeX
            
            if sceneAspect >= mapAspect {
                setMapX = sceneSizeX
                setMapY = setMapX*mapAspect
            } else {
                setMapY = sceneSizeY
                setMapX = setMapY*(1/mapAspect)
            }
            
        NTMap!.anchorPoint = CGPoint(x: 0.0,y: 0.0)
        NTMap!.size = CGSize(width: setMapX, height: setMapY)
        NTMap!.position = CGPoint(x: 0.0, y: 0.0)
        NTMap!.zPosition = 0.0
            
        self.addChild(NTMap!)
        
        return (setMapX/editorPixelWidth)
        
        //Nil case
        } else {
        
        return 1.0
        }
    }
    
    // Setup menu
    func setupMenu () {
        
        NTMenu = SKNode()
        NTMenu!.position = CGPoint(x: CGFloat(mapScaleFactor*1250), y: CGFloat(mapScaleFactor*600))
        NTMenu!.zPosition = 5000
        self.addChild(NTMenu!)
        
        undoButton = SKSpriteNode(texture: SKTexture(imageNamed: "black_marker"), color: UIColor(), size: CGSize(width: 50, height: 50))
        NTMenu!.addChild(undoButton!)
        undoButton!.zPosition = NTMenu!.zPosition + 1.0
        undoButton!.position = CGPoint(x: 0.0, y: 60.0)
        
        endTurnButton = SKSpriteNode(texture: SKTexture(imageNamed: "blue_marker"), color: UIColor(), size: CGSize(width: 50, height: 50))
        NTMenu!.addChild(endTurnButton!)
        endTurnButton!.zPosition = NTMenu!.zPosition + 1.0
        endTurnButton!.position = CGPoint(x: 0.0, y: 0.0)
        
        terrainButton = SKSpriteNode(texture: SKTexture(imageNamed: "FRback"), color: UIColor(), size: CGSize(width: 50, height: 10))
        NTMenu!.addChild(terrainButton!)
        terrainButton!.zPosition = NTMenu!.zPosition + 1.0
        terrainButton!.position = CGPoint(x: 0.0, y: -50.0)
        
        fastfwdButton = SKSpriteNode(texture: SKTexture(imageNamed: "icon_blue_down"), color: UIColor(), size: CGSize(width: 50, height: 50))
        NTMenu!.addChild(fastfwdButton!)
        fastfwdButton!.zPosition = NTMenu!.zPosition + 1.0
        fastfwdButton!.zRotation = CGFloat(M_PI/2)
        fastfwdButton!.position = CGPoint(x: 0.0, y: -110.0)
        
        rewindButton = SKSpriteNode(texture: SKTexture(imageNamed: "icon_red_down"), color: UIColor(), size: CGSize(width: 50, height: 50))
        NTMenu!.addChild(rewindButton!)
        rewindButton!.zPosition = NTMenu!.zPosition + 1.0
        rewindButton!.zRotation = -CGFloat(M_PI/2)
        rewindButton!.position = CGPoint(x: -60.0, y: -110.0)
        
        let corpsMoveButtonHolder = SKNode()
        corpsMoveButton = SKSpriteNode(texture: SKTexture(imageNamed: "corps_move_mark"), color: UIColor(), size: CGSize(width: 20, height: 20))
        corpsMoveButtonHolder.position = CGPoint(x: -90.0, y: -160.0)
        NTMenu!.addChild(corpsMoveButtonHolder)
        corpsMoveButtonHolder.addChild(corpsMoveButton!)
        corpsMoveButton!.zPosition = NTMenu!.zPosition + 1
        
        let corpsDetachButtonHolder = SKNode()
        corpsDetachButton = SKSpriteNode(texture: SKTexture(imageNamed: "corps_detach_mark"), color: UIColor(), size: CGSize(width: 20, height: 20))
        corpsDetachButtonHolder.position = CGPoint(x: -60.0, y: -160.0)
        NTMenu!.addChild(corpsDetachButtonHolder)
        corpsDetachButtonHolder.addChild(corpsDetachButton!)
        corpsDetachButton!.zPosition = NTMenu!.zPosition + 1
        
        let corpsAttachButtonHolder = SKNode()
        corpsAttachButton = SKSpriteNode(texture: SKTexture(imageNamed: "corps_attach_mark"), color: UIColor(), size: CGSize(width: 20, height: 20))
        corpsAttachButtonHolder.position = CGPoint(x: -30.0, y: -160.0)
        NTMenu!.addChild(corpsAttachButtonHolder)
        corpsAttachButtonHolder.addChild(corpsAttachButton!)
        corpsAttachButton!.zPosition = NTMenu!.zPosition + 1
        
        let independentButtonHolder = SKNode()
        independentButton = SKSpriteNode(texture: SKTexture(imageNamed: "independent_mark"), color: UIColor(), size: CGSize(width: 20, height: 20))
        independentButtonHolder.position = CGPoint(x: 0.0, y: -160.0)
        NTMenu!.addChild(independentButtonHolder)
        independentButtonHolder.addChild(independentButton!)
        independentButton!.zPosition = NTMenu!.zPosition + 1

        let retreatButtonHolder = SKNode()
        retreatButton = SKSpriteNode(texture: SKTexture(imageNamed: "AustrianFlag"), color: UIColor(), size: CGSize(width: 20, height: 20))
        retreatButtonHolder.position = CGPoint(x: 0.0, y: -260.0)
        NTMenu!.addChild(retreatButtonHolder)
        retreatButtonHolder.addChild(retreatButton!)
        retreatButton!.zPosition = NTMenu!.zPosition + 1
        
        let commitButtonHolder = SKNode()
        commitButton = SKSpriteNode(texture: SKTexture(imageNamed: "Commit"), color: UIColor(), size: CGSize(width: 20, height: 20))
        commitButtonHolder.position = CGPoint(x: 0.0, y: -280.0)
        NTMenu!.addChild(commitButtonHolder)
        commitButtonHolder.addChild(commitButton!)
        commitButton!.zPosition = NTMenu!.zPosition + 1
        
        corpsMoveSelector = SpriteSelector(parentNode: corpsMoveButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        corpsDetachSelector = SpriteSelector(parentNode: corpsDetachButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        corpsAttachSelector = SpriteSelector(parentNode: corpsAttachButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        independentSelector = SpriteSelector(parentNode: independentButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        retreatSelector = SpriteSelector(parentNode: retreatButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        endTurnSelector = SpriteSelector(parentNode: endTurnButton!, initialSelection: .Option, theCoordinateSystem: NTMenu!, passDrawType: "EndTurn")
        commitSelector = SpriteSelector(parentNode: commitButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
    
    }
    
    // Setup approaches
    func linkApproaches () {
        
        for each in manager!.approaches {
            
            each.ownReserve = manager!.reserves.filter { $0.name == each.ownReserveName }.first
            each.adjReserve = manager!.reserves.filter { $0.name == each.adjReserveName }.first
            each.oppApproach = manager!.approaches.filter { $0.name == each.oppApproachName }.first
        }
    }
    
    // Setup reserves
    func linkReserves () {
        
        for each in manager!.reserves {
            
            for each2 in each.adjReservesName {
                
                each.adjReserves += [(manager!.reserves.filter { $0.name! == each2 }.first!)]
            }
            
            for each2 in each.ownApproachesName {
                
                each.ownApproaches += [(manager!.approaches.filter { $0.name! == each2 }.first!)]
                //print([(approaches.filter { $0.name! == each2 }.first!)])
            }
            
            for each2 in each.rdReservesName {
                
                var rdSet:[Reserve] = []
                
                for each3 in each2 {
                    
                    rdSet += [(manager!.reserves.filter { $0.name! == each3 }.first!)]
                }
    
                each.rdReserves += [rdSet]
            }
            
           each.UpdateReserveState() // Update reserve state
            
        }
    }
    
    // MARK: Unit Selection Functions
    
    // Return true if you can run the MoveUnitSelection function (false if you are triggering attach command)
    func UpdateSelection(touchedUnit:Unit) -> Bool {
        
        var sameCommand:Bool = false
        var touchedLeader:Bool = false
        var selectedUnit:Bool = false
        var unitsSelected:Bool = true
        
        var theCommand:Command!
        var theUnits:[Unit] = []
        if selectedGroup != nil {
            theCommand = selectedGroup!.command
            theUnits = selectedGroup!.units
        } else {
            guard let theParent = touchedUnit.parent as? Command else {return false}
            theCommand = theParent
        }

        if touchedUnit.parent != theCommand {
            sameCommand = false
            if CheckIfViableAttach(touchedUnit, groupSelected: selectedGroup!) {return false}
            theCommand = touchedUnit.parentCommand
        } else {
            sameCommand = true
        }
        
        if touchedUnit.unitType == .Ldr {touchedLeader = true}
        if touchedUnit.selected == .Selected {selectedUnit = true}
        if theUnits.count == 0 {unitsSelected = false}
        switch (touchedLeader, selectedUnit, sameCommand, unitsSelected) {
            
        case (true, _, _, false):
            // Leader with nothing selected
            theUnits = theCommand.units
            for eachUnit in theUnits {eachUnit.selected = .Selected}
        case (true, _, false, _):
            // Leader in a new group (deselect everything except leader)
            ToggleGroups([selectedGroup!], makeSelection: .Normal)
            theUnits = theCommand.units
            for eachUnit in theUnits {eachUnit.selected = .Selected}
        case (true, _, true, true):
            // Leader with units selected in the leader group (toggle leader)
            if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        case (false, true, _, _):
            // Selected unit (toggle)
            if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        case (false, false, true, _):
            // New unit in the same group
            if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        case (false, false, false, _):
            // New unit in a different group
            //print("here")
            ToggleGroups([selectedGroup!], makeSelection: .Normal)
            touchedUnit.selected = .Selected; theUnits = [touchedUnit]
        default:
            break
        }
        
        if theUnits == [] {
            DeselectEverything()
        } else {
            selectedGroup = Group(theCommand: theCommand, theUnits: theUnits)
            //if selectedGroup!.fullCommand {print("Highlight me")}
        }
        
        return true
    }
    
    // Sets the viable moves and orders for a given selection (under move orders)
    func  MoveUnitSelection() {
    
        // Hide locations, check that we have a selection group then update based on what was touched
        HideAllLocations(true)
        if selectedGroup == nil {return Void()}
        //print(selectedGroup!.units.count)
        // Set the commands available
        (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected) = OrdersAvailable(selectedGroup!, ordersLeft: ((manager?.corpsCommandsAvail)!, (manager?.indCommandsAvail)!))
        
        // Setup the swipe queue for the selected command
        (adjMoves, attackThreats, mustFeintThreats) = MoveLocationsAvailable(selectedGroup!, selectors: (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected), undoOrAct:undoOrAct)
        
        // Setup the SwipeQueue
        /*
        ResetSwipeQueue()
        swipeQueue = adjMoves + attackThreats + mustFeintThreats
        swipeQueue += selectedGroup!.command.currentLocation?.occupants as [SKNode]!
        */
        
        // Reveal all locations if on a start location
        if selectedGroup!.command.currentLocationType == .Start {HideAllLocations(false)}
        
    }
    
    // Sets the defense/retreat selection when a threat is made (returns the reserve area of the threat group)
    func ThreatUnitSelection(touchedUnit:Unit, retreatMode:Bool = false, theTouchedThreat:GroupConflict) -> Reserve? {
        
        var selectableGroups:[Group]!
        var theReserve:Reserve!
        
        if retreatMode {selectableGroups = manager!.selectableRetreatGroups} else {selectableGroups = manager!.selectableDefenseGroups}
        
        if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {return nil}
        
        let parentCommand = touchedUnit.parent as! Command
        
        if parentCommand.currentLocation?.locationType == .Reserve {
            theReserve = parentCommand.currentLocation as! Reserve
        } else if parentCommand.currentLocation?.locationType == .Approach {
            theReserve = (parentCommand.currentLocation as! Approach).ownReserve
        } else {
            return nil
        }
        
        // Resets the selected units in the activeThreat
        if activeThreat == nil {activeThreat = theTouchedThreat}
        else if theTouchedThreat.defenseReserve != activeThreat!.defenseReserve {
            ToggleGroups(selectableGroups, makeSelection: .Normal)
            for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
            activeThreat = theTouchedThreat
        }
        
        if touchedUnit.unitType == .Ldr { // Always select all if selecting the leader
            
            if let indexOfCommand = selectableGroups.indexOf({$0.command == parentCommand}) {
                let leaderUnits:[Unit] = selectableGroups[indexOfCommand].units
                for eachUnit in leaderUnits {eachUnit.selected = .Selected; eachUnit.zPosition = 100}
            }
        }
            
        else { // Normal click mode
            
            if touchedUnit.selected == .Selected {
                
                touchedUnit.selected = .Normal
                if !retreatMode && !parentCommand.hasLeader {ActivateDetached(theReserve, theGroups: selectableGroups, makeSelection: .Normal)}
                
            } else {
                
                if !retreatMode && !parentCommand.hasLeader {ActivateDetached(theReserve, theGroups: selectableGroups, makeSelection: .NotSelectable)}
                touchedUnit.selected = .Selected
                touchedUnit.zPosition = 100
            }
        }
        
        return theReserve
        
    }
    
    // MARK: Support
    
    func ResetSwipeQueue() {
        
        for eachObject in swipeQueue {
            if eachObject is Command {(eachObject as! Command).SetUnitsZ(100)}
            else {eachObject.zPosition = 200}
        }
        
        swipeQueue = []
        swipeQueueIndex = 0
        newSwipeQueue = true
    }
    
    func DeselectEverything(locationsOnly:Bool = false) {
        
        if selectedGroup != nil {
            for eachCommand in selectedGroup!.command.currentLocation!.occupants {eachCommand.selector?.selected = .Off}
            ToggleGroups([selectedGroup!], makeSelection: .Normal); selectedGroup = nil
        }
        HideAllLocations(true)
        ResetSwipeQueue()
        
        // Selectors to unselected
        (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected) = (.Off, .Off, .Off, .Off)
    }
    
    func HideAllLocations (hide:Bool) {
        
        for each in manager!.reserves {each.hidden = hide}
        for each in manager!.approaches {each.hidden = hide}
    }
    
    func HideAllCommands (hide:Bool) {
        
        for each in (manager!.gameCommands[manager!.actingPlayer]! + manager!.gameCommands[manager!.actingPlayer.Other()!]!) {each.hidden = hide}
        
    }
    
    func HideAllOrderArrows (hide:Bool) {
        
        for eachOrder in manager!.orders {if eachOrder.orderArrow != nil {eachOrder.orderArrow!.hidden = hide}}
        
    }
    
    func ReturnMoveType () -> MoveType {
        if corpsMoveSelector!.selected == .On {return .CorpsMove}
        else if corpsDetachSelector!.selected  == .On {return .CorpsDetach}
        else if independentSelector!.selected == .On {return .IndMove}
        else if manager!.phaseOld == .PreGame {return .CorpsMove}
        else {return .None}
    }
        
}




