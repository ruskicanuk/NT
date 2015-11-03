//
//  GameScene.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright (c) 2015 Justin Anderson. All rights reserved.
//

import SpriteKit
import Foundation

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
    var guardButton:SKSpriteNode?
    
    // Playback properties
    var statePoint:ReviewState = .Front
    var selectedStatePoint:ReviewState = .Front
    var fastFwdIndex:Int = 0
    var fastFwdExecuted:CFTimeInterval = 0
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
    var hiddenLocations:[Location] = []
    
    // Selectors
    var corpsMoveSelector:SpriteSelector?
    var corpsDetachSelector:SpriteSelector?
    var corpsAttachSelector:SpriteSelector?
    var independentSelector:SpriteSelector?
    var retreatSelector:SpriteSelector?
    var commitSelector:SpriteSelector?
    var endTurnSelector:SpriteSelector?
    var guardSelector:SpriteSelector?
    
    // Name of Selectors
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
    let guardName:String = "Guard"
    
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
        NSNotificationCenter.defaultCenter().postNotificationName(SHOWMENU, object: nil)
    }
    
    // MARK: TouchedNode and HoldNode
    
    // Decides what was touched
    func theTouchedNode(theSelectedNodes:[SKNode], mapLocation:CGPoint, touchedCount:Int = 1) -> SKNode? {
        
        var highestMapZ = CGFloat(-1)
        var countTouches = 0
        var shortestDistance:CGFloat = 0.0
        
        var touchedNode:SKNode?
        
        for each in theSelectedNodes {
            
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
    
    // Called when screen is pressed and held for a period of 1 second
    func HoldTouch() {
        
        // Safety drill
        guard let touchedUnit = holdNode as? Unit else {holdNode = nil; return}
        guard let touchedParent = touchedUnit.parent as? Command else {holdNode = nil; return}
        guard let theGroupConflict = manager!.activeThreat else {holdNode = nil; return}
        
        if ReduceStrengthIfRetreat(touchedUnit, theLocation:touchedParent.currentLocation!, theGroupConflict:theGroupConflict, retreatMode:(retreatSelector?.selected == .Option)) {
            ReduceUnitUI(Group(theCommand: touchedParent, theUnits: [touchedUnit]), theGroupConflict:theGroupConflict)
        }
        if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {retreatSelector!.selected = CheckRetreatViable(theGroupConflict, retreatGroup: manager!.selectableRetreatGroups)}
        
        holdNode = nil
        
    }
    
    // MARK: Touches
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches {return Void()}
        
        // Find the touched nodes
        let touch = touches.first as UITouch!
        let mapLocation:CGPoint? = touch.locationInNode(NTMap!)
        let acceptableDistance:CGFloat = mapScaleFactor*50
        if mapLocation == nil {return Void()}
        let touchedNodesMap = self.nodesAtPoint(mapLocation!)

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
        holdNode = theTouchedNode(touchedNodesMap, mapLocation: mapLocation!)
        touchStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches {return Void()}
        
        // Start if initial tap met the right conditions (Command is selected + tap is close enough)
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
                    print("Registered swipeUp", terminator: "\n")
                    
                } else if (swipeStartPoint!.y - mapLocation.y) > yRequiredForSwipe || (swipeStartPoint!.x - mapLocation.x) > yRequiredForSwipe {
                
                    QueueSwipe(swipeDown)
                    swipeStart = false
                    swipeStartPoint = nil
                    print("Registered swipeDown", terminator: "\n")
                }
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        touchStartTime = nil
        if holdNode == nil {return} else {holdNode = nil}
        if disableTouches {return}

        let touch = touches.first as UITouch!
        
        //Find the selected node within the map and the scene
        let sceneLocation = touch.locationInNode(self)
        let mapLocation = touch.locationInNode(NTMap!)
        
        var touchedNodeScene:SKNode?
        var touchedNode:SKNode?

        let touchedCount:Int = touch.tapCount
        
        // Select the highest Z value in the touch
        let touchedNodesScene = self.nodesAtPoint(sceneLocation)
        let touchedNodesMap = self.nodesAtPoint(mapLocation)

        var highestSceneZ = CGFloat(-1)
        
        var countTouchesScene = 0
        
        for each in touchedNodesScene {
        
            if let possibleTouch = (each as? Command) {if manager!.actingPlayer.Opposite(possibleTouch.commandSide)! {continue}} // Skip touches on non-acting player (except when declaring attack group)
            
            if each.zPosition > highestSceneZ {
                
                highestSceneZ = each.zPosition
                touchedNodeScene = each
            }
            countTouchesScene++
        }

        // Sets the touched node
        touchedNode = theTouchedNode(touchedNodesMap, mapLocation:mapLocation, touchedCount:touchedCount)

        // Exit if in rewind mode
        if statePoint != .Front && touchedNodeScene != fastfwdButton && touchedNodeScene != rewindButton {return Void()}
        
        // Button touched cases
        if touchedNodeScene == undoButton {selectionCase = undoName; print("UndoTouch", terminator: "")}
        else if touchedNodeScene == endTurnButton {selectionCase = endTurnName; print("EndTurnTouch", terminator: "")}
        else if touchedNodeScene == terrainButton {selectionCase = terrainName; print("HideCommandsTouch", terminator: "")}
        else if touchedNodeScene == fastfwdButton {if undoOrAct {return Void()}; selectionCase = fastfwdName; print("FastFwdTouch", terminator: "")}
        else if touchedNodeScene == rewindButton {if undoOrAct {return Void()}; selectionCase = rewindName; print("RewindTouch", terminator: "")}
        else if touchedNodeScene == corpsMoveButton {selectionCase = corpsMoveName; print("CorpsMoveTouch", terminator: "")}
        else if touchedNodeScene == corpsDetachButton {selectionCase = corpsDetachName; print("CorpsDetachTouch", terminator: "")}
        else if touchedNodeScene == corpsAttachButton {selectionCase = corpsAttachName; print("CorpsAttachTouch", terminator: "")}
        else if touchedNodeScene == independentButton {selectionCase = independentName; print("IndependentTouch", terminator: "")}
        else if touchedNodeScene == retreatButton {selectionCase = retreatName; print("RetreatTouch", terminator: "")}
        else if touchedNodeScene == commitButton {selectionCase = commitName; print("CommitTouch", terminator: "")}
        else if touchedNodeScene == guardButton {selectionCase = guardName; print("GuardTouch", terminator: "")}
            
        // Map object touched cases
        else {
            
            if touchedNode == NTMap {
                print("MapTouch", terminator: "\n")
                if undoOrAct {return Void()}
                selectionCase = mapName
            } else if touchedNode is Approach {
                print("ApproachTouch", terminator: "\n")
                selectionCase = approachName
            } else if touchedNode is Reserve {
                print("ReserveTouch", terminator: "\n")
                selectionCase = reserveName
            } else if touchedNode is Command {
                print("CommandTouch Units: \((touchedNode as! Command).units.count) Active Units: \((touchedNode as! Command).activeUnits.count)", terminator: "\n")
                if undoOrAct {return Void()}
                selectionCase = mapName
            } else if touchedNode is Unit {
                print("UnitTouch", terminator: "\n")
                if undoOrAct {return Void()}
                selectionCase = unitName
            } else {
                if undoOrAct {return Void()}
                DeselectEverything()
                print("NothingTouch", terminator: "\n")
            }
        }
        
        // Selection Scenario
        var phaseGroup:String = "Move"
        if manager!.phaseOld == .FeintThreat || manager!.phaseOld == .NormalThreat || manager!.phaseOld == .RetreatAfterCombat {phaseGroup = "Threat"}
        else if manager!.phaseOld == .StoodAgainstNormalThreat || manager!.phaseOld == .StoodAgainstFeintThreat || manager!.phaseOld == .RetreatedBeforeCombat {phaseGroup = "Commit"}
        else if manager!.phaseOld == .FeintMove || manager!.phaseOld == .PostVictoryFeintMove {phaseGroup = "DefendResponse"}
        else if manager!.phaseOld == .RealAttack || manager!.phaseOld == .DeclaredAttackers || manager!.phaseOld == .DeclaredLeadingA {phaseGroup = "LeadingUnits"}
        else if manager!.phaseOld == .DeclaredLeadingD {phaseGroup = "AttackDeclare"}
        else {phaseGroup = "Move"}
        
        // Touch Processing
        switch (selectionCase, touchedCount, phaseGroup) {
        
        // MARK: Move Touch

        case (unitName,1,"Move"):
            
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.fixed == true || touchedUnit.selected == .Off {break}
            
            // Case of allowing for the second-move order
            if !manager!.currentGroupsSelected.isEmpty  {SecondMoveUI()}
            
            // Add code eventually to shade out those who already moved (make them non selectable)
            if MoveGroupUnitSelection(touchedUnit) {MoveOrdersAvailable()}
                
            // Attach scenario
            else {
                
                // Create an order
                let newOrder = Order(groupFromView: manager!.currentGroupsSelected[0], touchedUnitFromView: touchedUnit, orderFromView: .Attach)
                
                // Execute the order and add to order array
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
                
                DeselectEverything()
            }
            
        case (reserveName,1,"Move"): if touchedNode != nil && !manager!.currentGroupsSelected.isEmpty {MoveUI(touchedNode!)}
            
        case (approachName,1,"Move"):
            
            if touchedNode != nil && !manager!.currentGroupsSelected.isEmpty {
                if mustFeintThreats.contains(touchedNode!) {MustFeintThreatUI(touchedNode!)}
                else if attackThreats.contains(touchedNode!) {AttackThreatUI(touchedNode!)}
                else {MoveUI(touchedNode!)}
            }
            
        case (mapName,1,"Move"):
            
            SecondMoveUI()
            DeselectEverything()
            
        // MARK: Defend & Pre-retreat Touch
            
        case (unitName,1,"Threat"):
            
            // Safety Drill
            guard let touchedUnit = touchedNode as? Unit else {break}
            guard let theGroupConflict = manager!.activeThreat else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off || touchedUnit.unitSide != manager!.actingPlayer {break}
            
            DefenseGroupUnitSelection(touchedUnit, retreatMode:(retreatSelector?.selected == .On || retreatSelector?.selected == .Option), theTouchedThreat:theGroupConflict)
            if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {retreatSelector!.selected = CheckRetreatViable(theGroupConflict, retreatGroup: manager!.selectableRetreatGroups)}
            
            if CheckTurnEndViableInRetreatOrDefendMode(theGroupConflict) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
            
        case (reserveName,1,"Threat"):
            
            guard let touchedReserve = touchedNode as? Reserve else {break}
            RetreatUI(touchedReserve)
            
        case (mapName,1,"Threat"):
            
            if retreatSelector!.selected == .On || retreatSelector!.selected == .Option {
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .Normal)
                retreatSelector!.selected = .Option
            } else {
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .Normal)
            }
            for each in manager!.reserves {each.hidden = true} // ###
            if retreatSelector?.selected == .Off {endTurnSelector?.selected = .Off}
        
        // MARK: Move after Pre-retreat, Feint-move & Attack-declaration Touch
        
        case (unitName,1,"Commit"), (unitName,1,"AttackDeclare"):

            // Safety checks
            guard let touchedUnit = touchedNode as? Unit else {break}
            guard let theConflict = manager!.activeThreat?.conflict! else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off || touchedUnit.fixed || manager!.activeThreat == nil {break}
            
            if touchedUnit.parentCommand!.commandSide.Opposite(manager!.actingPlayer)! {
                ToggleBattleWidthUnitSelection(touchedUnit, theThreat: theConflict)
                break
            }
            
            // 1st: Updates which units are selected, 2nd: Updates orders available, 3rd update locations
            AttackGroupUnitSelection(touchedUnit, realAttack:(phaseGroup == "AttackDeclare"), theTouchedThreat: theConflict)
            AttackOrdersAvailable()
            
            if phaseGroup == "AttackDeclare" {if ReturnMoveType() != .None {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}}
            
            if manager!.currentGroupsSelected.isEmpty && manager!.phaseOld == .StoodAgainstNormalThreat {commitSelector!.selected = .Option} else {commitSelector!.selected = .Off}
        
        case (reserveName,1,"Commit"): if touchedNode != nil && !manager!.currentGroupsSelected.isEmpty {MoveUI(touchedNode!)}
            
        case (approachName,1,"Commit"):
            
            // Safety check
            guard let touchedApproach = touchedNode as? Approach else {break}
            
            if touchedNode != nil && !manager!.currentGroupsSelected.isEmpty {
                
                if !(touchedApproach.ownReserve?.localeControl == manager!.actingPlayer.Other()) {MoveUI(touchedNode!)}
                else {MustFeintThreatUI(touchedNode!, forceFeint:true)} // This must be a continuation threat
            }
            
        case (mapName,1,"Commit"), (mapName,1,"AttackDeclare"):
            
            SecondMoveUI()
            DeselectEverything()
            if manager!.phaseOld == .StoodAgainstNormalThreat {commitSelector!.selected = .Option; endTurnSelector!.selected = .Off}
            if manager!.phaseOld == .DeclaredLeadingD {endTurnSelector!.selected = .Off}
        
        // MARK: Feint-response Touch
            
        case (unitName,1,"DefendResponse"):
            
            guard let touchedUnit = touchedNode as? Unit else {break}
            guard let theConflict = manager!.activeThreat?.conflict! else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            if CheckTurnEndViableInDefenseMode(theConflict) {break}
            
            FeintDefenseUnitSelection(touchedUnit)
            
            let theSelectionGroup:GroupSelection = GroupSelection(theGroups: theConflict.defenseGroup!.groups)

            // If end-turn condition yet to be reached (if not, run the selection and show the approach)
            if !theSelectionGroup.groups.isEmpty {manager!.activeThreat!.conflict.defenseApproach.hidden = false}
            else {manager!.activeThreat!.conflict.defenseApproach.hidden = true}

        case (approachName,1,"DefendResponse"):
            
            // Safety check
            guard let touchedApproach = touchedNode as? Approach else {break}
            let selectedGroups = GroupSelection(theGroups: GroupsIncludeLeaders(manager!.activeThreat!.conflict.defenseGroup!.groups))
            if selectedGroups.blocksSelected == 0 {break} // Do nothing
            
            DefendAgainstFeintUI(touchedApproach, theGroupSelection: selectedGroups)
            
            if CheckTurnEndViableInDefenseMode(manager!.activeThreat!.conflict) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
            
            //manager!.activeThreat!.conflict.defenseApproach.hidden = true
            
        case (mapName,1,"DefendResponse"):

            ToggleGroups(manager!.activeThreat!.conflict.defenseGroup!.groups, makeSelection: .NotSelectable)
            SelectableGroupsForFeintDefense(manager!.activeThreat!.conflict)
            
            if CheckTurnEndViableInDefenseMode(manager!.activeThreat!.conflict) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
            
            manager!.activeThreat!.conflict.defenseApproach.hidden = true

        // MARK: Leading-units Touch
            
        case (unitName,1,"LeadingUnits"):
            
            // Safety check
            guard let theConflict = manager!.activeThreat?.conflict! else {break}
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}

            LeadingUnitSelection(touchedUnit)
            SelectableLeadingGroups(theConflict, thePhase: manager!.phaseOld)
        
        case (mapName,1,"LeadingUnits"):
            
            // Safety check
            guard let theConflict = manager!.activeThreat?.conflict! else {break}
            SelectableLeadingGroups(theConflict, thePhase: manager!.phaseOld, resetState: true)
        
        // MARK: Undo
            
        case (undoName,1,_):
            
            // Ensures there are orders to undo and that we aren't in locked mode
            if (manager!.orders.count > 0 && manager!.orders.last!.unDoable) || manager!.phaseOld == .DeclaredAttackers {
        
                switch (manager!.phaseOld) {
                    
                case .Move, .Setup:
                    
                    undoOrAct = manager!.orders.last!.ExecuteOrder(true)
                    
                    if manager!.orders.last!.order as OrderType == .FeintThreat || manager!.orders.last!.order as OrderType == .NormalThreat {
                        endTurnSelector?.selected = .Option
                        guardSelector?.selected = .Off
                        manager!.activeThreat = nil
                        undoOrAct = false
                    }
                    
                    if undoOrAct || manager!.orders.last!.order == .SecondMove || manager!.orders.last!.baseGroup!.command.moveNumber > 0 {
                        manager!.currentGroupsSelected = [manager!.orders.last!.baseGroup!]
                        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Selected)
                        MoveOrdersAvailable()
                    
                    } else {DeselectEverything()}
                    
                case .NormalThreat, .FeintThreat, .RetreatAfterCombat:
                    
                    manager!.orders.last!.ExecuteOrder(true)
                    
                    if manager!.activeThreat != nil {
                        
                        if manager!.phaseOld == .RetreatAfterCombat {manager!.PostBattleRetreatOrSurrender()}
                        else {manager!.ResetRetreatDefenseSelection()}
                        if CheckTurnEndViableInRetreatOrDefendMode(manager!.activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                    }
                    
                case .StoodAgainstFeintThreat, .StoodAgainstNormalThreat, .RetreatedBeforeCombat:
                    
                    guard let theThreat = manager!.activeThreat?.conflict else {break}
                    let endLocation = manager!.orders.last!.endLocation
                    let startLocation = manager!.orders.last!.startLocation[0]
                    
                    if let theGroup = manager!.orders.last?.baseGroup {manager!.currentGroupsSelected = [theGroup]}
                    manager!.orders.last!.ExecuteOrder(true)
                    
                    // This eliminates the repeat attack the appropriate undo
                    if endLocation is Reserve && startLocation is Reserve && manager!.repeatAttackGroup != nil {
                        if (endLocation as! Reserve) == theThreat.defenseReserve && (startLocation as! Reserve) == theThreat.attackReserve && manager!.repeatAttackMoveNumber == manager!.currentGroupsSelected[0].command.moveNumber {
                            manager!.repeatAttackGroup = nil; manager!.repeatAttackMoveNumber = nil
                        }
                    }
                    
                    if manager!.currentGroupsSelected[0].command.moveNumber == 0 { // Move number 0 plus undo always start
                        undoOrAct = false
                        endTurnSelector?.selected = .Off
                        if manager!.phaseOld == .StoodAgainstNormalThreat {commitSelector?.selected = .Option}
                        DeselectEverything()
                    } else {
                        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Selected)
                        if CheckTurnEndViableInCommitMode(theThreat, endLocation:startLocation) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                    }
                    AttackOrdersAvailable()
                    
                case .FeintMove, .PostVictoryFeintMove:
                    
                    manager!.orders.last!.ExecuteOrder(true)
                    
                    if manager!.activeThreat != nil {

                        ToggleCommands(manager!.activeThreat!.conflict.defenseGroup!.groups.map{return $0.command}, makeSelection: .Off)

                        SelectableGroupsForFeintDefense(manager!.activeThreat!.conflict)
                        
                        manager!.activeThreat!.conflict.defenseApproach.hidden = true
                        endTurnSelector?.selected = .Off
                    }
                    
                case .DeclaredAttackers:
                    
                    manager!.activeThreat?.conflict.attackGroup = nil
                    manager!.activeThreat?.conflict.attackMoveType == nil
                    manager!.NewPhase(1, reverse: true, playback: false)
                    break

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
            
            //DeselectEverything()
            commandsHidden = !commandsHidden
            HideAllCommands(commandsHidden)
            HideAllOrderArrows(commandsHidden)
            HideAllLocations(commandsHidden)
            
        case (guardName,1,"Move"):
            
            if guardSelector?.selected == .Option {guardSelector?.selected = .On}
            else if guardSelector?.selected == .On {guardSelector?.selected = .Option}
            
        case (corpsDetachName,1,"Move"), (corpsDetachName,1,"Commit"), (corpsDetachName,1,"AttackDeclare"):

            if corpsDetachSelector?.selected == .Option {
                corpsDetachSelector?.selected = .On
                independentSelector?.selected = .Option
                if manager!.phaseOld == .Move {MoveOrdersAvailable(false)} else if manager!.phaseOld == .DeclaredLeadingD {AttackOrdersAvailable(false)}
            }
                
        case (independentName,1,"Move"), (independentName,1,"Commit"), (independentName,1,"AttackDeclare"):
            
            if independentSelector?.selected == .Option {
                corpsDetachSelector?.selected = .Option
                independentSelector?.selected = .On
                if manager!.phaseOld == .Move {MoveOrdersAvailable(false)} else if manager!.phaseOld == .DeclaredLeadingD {AttackOrdersAvailable(false)}
            }
            
        case (retreatName,1,"Threat"):
            
            if manager!.phaseOld == .RetreatAfterCombat {break}
            
            // In retreat mode, not flagged as must retreat, no reductions made
            if manager!.activeThreat!.retreatMode && !manager!.activeThreat!.mustRetreat && !manager!.activeThreat!.madeReductions {
                retreatSelector?.selected = .Off; manager!.activeThreat!.retreatMode = false
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .NotSelectable)
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .Normal)
                for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
            
            // In defend mode, not flagged as must defend
            } else if !manager!.activeThreat!.retreatMode && !manager!.activeThreat!.mustDefend {
                retreatSelector?.selected = .Option; manager!.activeThreat!.retreatMode = true
                ToggleGroups(manager!.selectableDefenseGroups, makeSelection: .NotSelectable)
                ToggleGroups(manager!.selectableRetreatGroups, makeSelection: .Normal)
            }
            
        case (commitName,1,"Commit"):
            
            if commitSelector?.selected == .Option {
                commitSelector?.selected = .On
                endTurnSelector?.selected = .On
            } else if commitSelector?.selected == .On {
                commitSelector?.selected = .Option
                endTurnSelector?.selected = .Off
            }
           
        // MARK: End Turn
            
        case (endTurnName,1,_):
            
            if endTurnSelector?.selected == .Off {break}
            //if manager!.phaseOld != .DeclaredLeadingD {DeselectEverything()}

            switch (manager!.phaseOld) {
                
            // Pre-game phase
            case .Setup:
                
                manager!.NewTurn()
                
            // Attacker ending the turn or confirming a threat
            case .Move:
                
                var threatRespondMode:Bool = false
                var theCode:String = ""
                
                if endTurnSelector?.selected == .Option {
                    HideAllLocations(true)
                    manager!.NewTurn()
                    
                } else if endTurnSelector?.selected == .On && manager!.orders.last?.order == .NormalThreat {
                    
                    threatRespondMode = true
                    theCode = manager!.NewPhase(1, reverse: false, playback: false)
                    
                } else if endTurnSelector?.selected == .On && manager!.orders.last?.order == .FeintThreat {
                    
                    threatRespondMode = true
                    theCode = manager!.NewPhase(2, reverse: false, playback: false)
                }
                undoOrAct = false
                ResetSelectors()
                
                if threatRespondMode {RetreatPreparation(theCode)}
                
            // Defender confirming a retreat or defense
            case .NormalThreat, .FeintThreat:
                
                if let theGroupThreat = manager!.activeThreat {
                    
                    endTurnSelector?.selected = .Off
                    
                    if theGroupThreat.retreatMode {
                        
                        retreatSelector?.selected = .Off
                        
                        // Morale reductions (before combat retreat)
                        manager!.ReduceMorale(theGroupThreat.moraleLossFromRetreat, side: manager!.phasingPlayer.Other()!, mayDemoralize: true)
                        manager!.NewPhase(2, reverse: false, playback: false)
                        
                    } else {
                        
                        SaveDefenseGroup(theGroupThreat)
                        if manager!.phaseOld == .NormalThreat {commitSelector?.selected = .Option} // Makes it option if attacker can click it
                        manager!.NewPhase(1, reverse: false, playback: false)
                    }
                    
                    // Continue-attack mode
                    if manager!.repeatAttackGroup != nil {
                        if CheckTurnEndViableInCommitMode(theGroupThreat.conflict, endLocation:manager!.repeatAttackGroup!.command.currentLocation!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                        manager!.currentGroupsSelected = [manager!.repeatAttackGroup!]
                        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Selected)
                        AttackOrdersAvailable()
                        undoOrAct = true
                    }
                    
                    // Guard-threat mode
                    if !theGroupThreat.retreatMode && guardSelector?.selected == .On {
                    
                        theGroupThreat.conflict.guardAttack = true
                        
                        // Captures the guard-threat case (no feint option)
                        manager!.NewPhase(1, reverse: false, playback: false)
                        
                        // Initial selection
                        // SelectableLeadingGroups(theGroupThreat.conflict, thePhase: manager!.phaseOld)
                        endTurnSelector?.selected = .On // Always can end turn when selecting leading units
                    }
                    
                    guardSelector?.selected = .Off
                }
            
            // Must-feint attacker confirming their feint move against a stalwart defender
            case .StoodAgainstFeintThreat:
            
                manager!.NewPhase(1, reverse: false, playback: false)
                //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
                //SelectableGroupsForFeintDefense(manager!.activeThreat!.conflict)
                
                if CheckTurnEndViableInDefenseMode(manager!.activeThreat!.conflict) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                undoOrAct = false
                ResetSelectors()
               
            // May-fight attacker confirming their feint move or real attack against a stalwart defender
            case .StoodAgainstNormalThreat:
            
                if commitSelector?.selected == .On {
                    commitSelector?.selected = .Off
                    manager!.NewPhase(1, reverse: false, playback: false)
                    endTurnSelector?.selected = .On // Always can end turn when selecting leading units
                
                } else { // Feint case
                    
                    manager!.NewPhase(2, reverse: false, playback: false)

                    //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
                    //SelectableGroupsForFeintDefense(manager!.activeThreat!.conflict)
                    if CheckTurnEndViableInDefenseMode(manager!.activeThreat!.conflict) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                }
                
                undoOrAct = false
                ResetSelectors()
                
            // Attacker confirming their move, or starting a new threat, against a retreating defender
            case .RetreatedBeforeCombat:
                
                if manager!.orders.last?.order == .FeintThreat {
                    
                    let theCode = manager!.NewPhase(2, reverse: false, playback: false)
                    //manager!.activeThreat = manager!.reserveThreats[0]
                    
                    if theCode == "TurnOnRetreat" {
                        retreatSelector?.selected = .Option
                    }
                    else if theCode == "TurnOnSurrender" {
                        let newOrder = Order(passedGroupConflict: manager!.activeThreat!, orderFromView: .Surrender)
                        newOrder.ExecuteOrder()
                        newOrder.unDoable = false // Can't undo surrender
                        manager!.orders += [newOrder]
                        retreatSelector?.selected = .Option
                    }
                    else {retreatSelector?.selected = .Off}
                    
                    if CheckTurnEndViableInRetreatOrDefendMode(manager!.activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
                    
                    undoOrAct = false

                } else {
                
                    manager!.NewPhase(1, reverse: false, playback: false)
                    endTurnSelector?.selected = .Option
                    undoOrAct = false
                }
                
                ResetSelectors()
                
            // Defender confirming their leading units
            case .RealAttack:
                
                // Safety check
                //guard let theConflict = manager!.activeThreat?.conflict! else {break}
                
                manager!.NewPhase(1, reverse: false, playback: false)
                
                endTurnSelector?.selected = .Off
                //manager!.selectableAttackAdjacentGroups = SelectableGroupsForAttackAdjacent(theConflict)
                
                //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
                
                //ToggleGroups(manager!.selectableAttackAdjacentGroups, makeSelection: .Normal)
                //ToggleGroups(theConflict.defenseLeadingUnits!.groups, makeSelection: .Selected)
                
            // Defender confirming their feint-response (after a feint-threat or won battle)
            case .FeintMove, .PostVictoryFeintMove:
                
                manager!.NewPhase(1, reverse: false, playback: false)
                endTurnSelector?.selected = .Option
                
            // Attacker confirming their attack move declaration
            case .DeclaredLeadingD:
                
                // Safety check
                guard let theConflict = manager!.activeThreat?.conflict! else {break}
                
                // Sets the attack group, updates defense leading units, whether its a wide attack, available counter-attackers and attack move type
                theConflict.attackGroup = GroupSelection(theGroups: manager!.currentGroupsSelected)
                if theConflict.guardAttack {theConflict.SetGuardAttackGroup()}
                theConflict.attackMoveType = ReturnMoveType()
                
                // Determine battle width
                let initialDefenseSelection = theConflict.defenseLeadingUnits!.blocksSelected
                theConflict.defenseLeadingUnits = GroupSelection(theGroups: theConflict.defenseLeadingUnits!.groups)
                if theConflict.defenseLeadingUnits?.blocksSelected == 2 {theConflict.wideBattle = true}
                else if initialDefenseSelection == 2 {theConflict.wideBattle = false}
                else if theConflict.defenseApproach.wideApproach {theConflict.wideBattle = true}
                else {theConflict.wideBattle = false}
                
                theConflict.counterAttackGroup = GroupSelection(theGroups: theConflict.availableCounterAttackers!.groups, selectedOnly:false)
                
                // Initial selection
                //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
                
                //ToggleGroups(theConflict.defenseGroup!.groups, makeSelection: .NotSelectable)
                //ToggleGroups(theConflict.defenseLeadingUnits!.groups, makeSelection: .Selected)

                manager!.NewPhase(1, reverse: false, playback: false)
                ResetSelectors()
                //SelectableLeadingGroups(theConflict, thePhase: manager!.phaseOld)
                
            // Attacker confirming their leading units
            case .DeclaredAttackers:
                
                // Safety check
                guard let theConflict = manager!.activeThreat?.conflict! else {break}
                
                // Initial selection
                //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
                //ToggleGroups(theConflict.attackLeadingUnits!.groups, makeSelection: .Selected) //CheckCheck
                
                // INITIAL RESULT
                let newOrder = Order(passedGroupConflict: manager!.activeThreat!, orderFromView: .InitialBattle)
                newOrder.ExecuteOrder()
                newOrder.unDoable = false // Can't undo initial result
                manager!.orders += [newOrder]
                
                manager!.NewPhase(1, reverse: false, playback: false)
                
                if !theConflict.mayCounterAttack {
                    theConflict.counterAttackLeadingUnits = GroupSelection(theGroups: [])
                    ProcessBattle()
                }
                
            // Defender confirming their counter-attack leading units
            case .DeclaredLeadingA:
                
                ProcessBattle()
                
            // Defender confirming their retreat move after a lost battle
            case .RetreatAfterCombat:
            
                // Safety check
                //guard let theConflict = manager!.activeThreat?.conflict! else {break}

                PostBattleMove()
                
            }
            
        default: break
            
        }
    }
    
    // MARK: End Turn Support
    
    func ProcessBattle() {
        
        // Safety check
        guard let theConflict = manager!.activeThreat?.conflict! else {return}
        
        // Reset conflict state
        manager!.activeThreat!.mustDefend = false; manager!.activeThreat!.mustRetreat == false
        
        // FINAL RESULT
        let newOrder = Order(passedGroupConflict: manager!.activeThreat!, orderFromView: .FinalBattle)
        newOrder.ExecuteOrder()
        newOrder.unDoable = false // Can't undo final result
        manager!.orders += [newOrder]
        
        if theConflict.conflictFinalWinner == .Neutral { // Artillery shot, skip to move phase
            manager!.NewPhase(1, reverse: false, playback: false)
            PostBattleMove(true)
            //manager!.NewPhase(1, reverse: false, playback: false)
            endTurnSelector?.selected = .Option
        }
        else if theConflict.conflictFinalWinner != theConflict.defenseSide { // Attacker wins
            
            manager!.NewPhase(1, reverse: false, playback: false)
            
            // Reveal all retreaters
            //var normalCommands:[Command] = []
            //normalCommands = theConflict.defenseReserve.occupants
            //for eachApproach in theConflict.defenseReserve.ownApproaches {normalCommands += eachApproach.occupants}
            
            manager!.activeThreat!.SetupRetreatRequirements() // Re-seeds the reduce requirements for retreating
            // Morale reductions (after combat retreat)
            
            let theCode = manager!.PostBattleRetreatOrSurrender() // Checks if surrender case exists
            
            // Only reduce from retreat if not in surrender or nothing to retreat mode
            if theCode == "TurnOnRetreat" {manager!.ReduceMorale(manager!.activeThreat!.moraleLossFromRetreat, side: theConflict.defenseSide, mayDemoralize: true)}
            
            RetreatPreparation(theCode) // Sets up turn-end status (requires empty locale)
        
        } else { // Defender wins
            
            manager!.NewPhase(2, reverse: false, playback: false)
            
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
                    
                    let newOrder = Order(retreatSelection: retreatGroup!, passedGroupConflict: theConflict.parentGroupConflict!, touchedReserveFromView: theConflict.attackReserve as Location, orderFromView: .Retreat, mapFromView: NTMap!)
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
                    
                    let newOrder = Order(retreatSelection: remainGroup!, passedGroupConflict: theConflict.parentGroupConflict!, touchedReserveFromView: remainGroup.groups[0].command.currentLocation!, orderFromView: .Retreat, mapFromView: NTMap!)
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
                
            }

            // Morale reductions (guard-attack failed)
            if theConflict.guardAttack {
                manager!.guardFailed[theConflict.defenseSide.Other()!] = true
                manager!.ReduceMorale(manager!.guardFailedCost, side: theConflict.defenseSide.Other()!, mayDemoralize: false)
            }
            
            if theConflict.approachConflict { // Skip to move
                manager!.NewPhase(1, reverse: false, playback: false)
                endTurnSelector?.selected = .Option
            } else { // Switch to feint defense
                SelectableGroupsForFeintDefense(theConflict)
                
                // Double check that defenders remain to move into position (otherwise skip to Move)
                let doubleCheckExistance:GroupSelection = GroupSelection(theGroups: theConflict.defenseGroup!.groups, selectedOnly: false)
                if doubleCheckExistance.groupSelectionStrength > 0 {endTurnSelector?.selected = .Off}
                else {manager!.NewPhase(1, reverse: false, playback: false)}
            }
        }
    }
    
    func PostBattleMove(artAttack:Bool = false) {
        
        // Safety check
        guard let theConflict = manager!.activeThreat?.conflict! else {return}
        
        let moveToNode:SKNode!
        if artAttack {
            moveToNode = theConflict.attackApproach
        }
        else {
            moveToNode = theConflict.defenseReserve
            theConflict.defenseReserve.has2PlusCorpsPassed = true // This ensures that the locale is blocked to all further movement
        }
        
        // Attack moves
        for eachGroup in theConflict.attackGroup!.groups {
            
            let newOrder = Order(groupFromView: eachGroup, touchedNodeFromView: moveToNode, orderFromView: .Move, corpsOrder: theConflict.attackMoveType! != .IndMove, moveTypePassed: theConflict.attackMoveType!, mapFromView:NTMap!)
            newOrder.ExecuteOrder()
            newOrder.unDoable = false
            manager!.orders += [newOrder]
            
            // Sets the moved commands to "finished moved"
            for (_, eachCommandArray) in newOrder.moveCommands {
                for eachCommand in eachCommandArray {
                    eachCommand.movedVia = theConflict.attackMoveType!
                    eachCommand.finishedMove = true
                }
            }
        }
        manager!.NewPhase(1, reverse: false, playback: false)
        endTurnSelector?.selected = .Option
        retreatSelector?.selected = .Off
    }
    
    func RetreatPreparation(theCode:String, initialRun:Bool = true) {
        
        // Safety drill
        if manager!.activeThreat == nil {return}
        guard let theThreat = manager!.activeThreat?.conflict else {return}
        
        if initialRun && theThreat.approachConflict && manager!.phaseOld != .RetreatAfterCombat { // Threatened occupied approach case
            manager!.NewPhase(1, reverse: false, playback: false)
            manager!.NewPhase(1, reverse: false, playback: false)
            
            //ToggleCommands(manager!.gameCommands[manager!.actingPlayer]!, makeSelectable: false)
            //SelectableLeadingGroups(theThreat, thePhase: manager!.phaseOld)
            endTurnSelector?.selected = .On // Always can end turn when selecting leading units
            return
        }
        else if theCode == "TurnOnRetreat" {retreatSelector?.selected = .Option} // Retreat mode
        else if theCode == "TurnOnSurrender" { // Surrender case
            let newOrder = Order(passedGroupConflict: manager!.activeThreat!, orderFromView: .Surrender)
            newOrder.ExecuteOrder()
            newOrder.unDoable = false
            manager!.orders += [newOrder]
            retreatSelector?.selected = .Option
        }
        else {retreatSelector?.selected = .Off} // Defense mode
        
        if manager!.phaseOld == .RetreatAfterCombat {
            
            theThreat.ResetUnitsAndLocationsInConflict()
            
            // Auto-move into the zone if nothing exists to retreat
            if theThreat.defenseReserve.localeControl == .Neutral {
                PostBattleMove()
            } else {
                endTurnSelector?.selected = .Off // Requires some retreating
            }
        }
        else if CheckTurnEndViableInRetreatOrDefendMode(manager!.activeThreat!) {endTurnSelector?.selected = .On}
        else {endTurnSelector?.selected = .Off}
        
    }
    
    // MARK: UI Orders
    
    // Order to move (corps, detach or independent)
    func MoveUI(touchedNodeFromView:SKNode) {
        
        let returnType = ReturnMoveType(); if returnType == .None {return Void()}
        let theGroup = manager!.currentGroupsSelected[0]
        
        // Sets up command order usage
        var commandUsage:Bool?
        if manager!.phaseOld == .Setup {}
        else if theGroup.fullCommand && theGroup.command.hasMoved {}
        //else if theGroup.units.count > 1 && theGroup.command
        else if independentSelector?.selected == .On {commandUsage = false}
        else {commandUsage = true}
        
        let newOrder = Order(groupFromView: manager!.currentGroupsSelected[0], touchedNodeFromView: touchedNodeFromView, orderFromView: .Move, corpsOrder: commandUsage, moveTypePassed: returnType, mapFromView:NTMap!)
        
        undoOrAct = newOrder.ExecuteOrder()
        manager!.orders += [newOrder]

        // Post-move processing
        switch (manager!.phaseOld) {
            
        case .Setup:
            
            DeselectEverything()
            
        case .Move:
            
        if newOrder.moveCommands[0]!.count == 1 && (newOrder.moveType == .CorpsMove || newOrder.moveType == .IndMove) {
            manager!.currentGroupsSelected = [Group(theCommand: newOrder.moveCommands[0]![0], theUnits: manager!.currentGroupsSelected[0].units)]
            MoveOrdersAvailable()
            //if adjMoves.isEmpty {DeselectEverything()}
        } else {DeselectEverything()}
            
        case .StoodAgainstFeintThreat, .StoodAgainstNormalThreat, .RetreatedBeforeCombat:
        
            guard let theThreat = manager!.activeThreat?.conflict else {break}
            let endLocation = newOrder.endLocation
            let startLocation = newOrder.startLocation[0]
            
            // Select the moving command
            manager!.currentGroupsSelected = [Group(theCommand: newOrder.moveCommands[0]![0], theUnits: manager!.currentGroupsSelected[0].units)]
            
            // This sets up the repeat attack group for after moving to the retreat area
            if endLocation is Reserve && startLocation is Reserve {
                if (endLocation as! Reserve) == theThreat.defenseReserve && (startLocation as! Reserve) == theThreat.attackReserve {
                    
                    manager!.repeatAttackGroup = manager!.currentGroupsSelected[0]
                    manager!.repeatAttackMoveNumber = manager!.repeatAttackGroup!.command.moveNumber - 1
                }
                
            }
            
            // Deselect in the case of Corps Detach
            if newOrder.moveType == .CorpsDetach {DeselectEverything()}
            
            if CheckTurnEndViableInCommitMode(theThreat, endLocation:endLocation) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
            
            AttackOrdersAvailable()
            undoOrAct = true
            
        default: break
        }
    }
    
    // Order to threaten (may later attack or feint)
    func AttackThreatUI(touchedNodeFromView:SKNode) {
        
        // Create an order, execute and deselect everything
        let newOrder = Order(groupFromView: manager!.currentGroupsSelected[0], touchedNodeFromView: touchedNodeFromView, orderFromView: .NormalThreat, corpsOrder: nil, moveTypePassed: ReturnMoveType(), mapFromView:NTMap!)
        
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        endTurnSelector?.selected = .On
        if CheckIfViableGuardThreat(newOrder.theConflict!) {guardSelector?.selected = .Option}
        
        DeselectEverything()
        undoOrAct = true
        
    }
    
    // Order to threaten an approach (must feint)
    func MustFeintThreatUI(touchedNodeFromView:SKNode, forceFeint:Bool = false) {
        
        // Check for viable adjacent (if so switch to AttachThreatUI)
        if !forceFeint && AdjacentThreatPotentialCheck(touchedNodeFromView, commandOrdersAvailable: manager!.corpsCommandsAvail > 0, independentOrdersAvailable: manager!.indCommandsAvail > 0) {AttackThreatUI(touchedNodeFromView); return Void()}
        
        // Create an order, execute and deselect everything
        let newOrder = Order(groupFromView: manager!.currentGroupsSelected[0], touchedNodeFromView: touchedNodeFromView, orderFromView: .FeintThreat, corpsOrder: nil, moveTypePassed: ReturnMoveType(), mapFromView:NTMap!)
        
        endTurnSelector?.selected = .On

        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        DeselectEverything()
        undoOrAct = true
        
    }
    
    // Order to retreat
    func RetreatUI(touchedNodeFromView:Reserve) {
        
        if manager!.activeThreat == nil {return}
        
        let retreatSelection = GroupSelection(theGroups: manager!.selectableRetreatGroups)
        
        let newOrder = Order(retreatSelection: retreatSelection, passedGroupConflict: manager!.activeThreat!, touchedReserveFromView: touchedNodeFromView, orderFromView: .Retreat, mapFromView:NTMap!)
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        // Hide the selected reserve
        touchedNodeFromView.hidden = true
        
        // Resets selectable defense group
        var theCode = ""
        if manager!.phaseOld == .RetreatAfterCombat {theCode = manager!.PostBattleRetreatOrSurrender()}
        else {theCode = manager!.ResetRetreatDefenseSelection()}
        
        RetreatPreparation(theCode, initialRun:false)
        
    }
    
    func DefendAgainstFeintUI(touchedNodeFromView:Approach, theGroupSelection:GroupSelection) {
        
        let newOrder = Order(retreatSelection: theGroupSelection, passedGroupConflict: manager!.activeThreat!, touchedApproachFromView: touchedNodeFromView, orderFromView: .Feint, mapFromView: NTMap!)

        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        // Hide the selected reserve
        touchedNodeFromView.hidden = true
        ToggleGroups(theGroupSelection.groups, makeSelection: .Normal)
    }
    
    // Order to reduce unit strength
    func ReduceUnitUI(passedGroup:Group, theGroupConflict:GroupConflict) {
        
        // Create an order
        let newOrder = Order(theUnit: passedGroup.units[0], passedGroupConflict:theGroupConflict, orderFromView: .Reduce)
        
        // Execute the order and add to order array
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
        if manager!.phaseOld == .RetreatAfterCombat {manager!.PostBattleRetreatOrSurrender()}
        else {manager!.ResetRetreatDefenseSelection()}
        if CheckTurnEndViableInRetreatOrDefendMode(manager!.activeThreat!) {endTurnSelector?.selected = .On} else {endTurnSelector?.selected = .Off}
    }
    
    func SecondMoveUI() {
        
        if !manager!.currentGroupsSelected.isEmpty && manager!.currentGroupsSelected.count == 1 {
            let theGroup = manager!.currentGroupsSelected[0]
            if manager!.turn == theGroup.command.turnEnteredMap && theGroup.command.hasMoved && !theGroup.command.secondMoveUsed && theGroup.command.moveNumber > 0 {
                let newOrder = Order(groupFromView: theGroup, orderFromView: .SecondMove)
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
            }
        }
    }
    
    // MARK: Fast-fwd & Rewind
    
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
                undoOrAct = historicalOrders[fastFwdIndex].ExecuteOrder(false, playback: true)
                if undoOrAct && (fastFwdIndex == manager!.orders.endIndex-1) {
                    DeselectEverything()
                    fastFwdExecuted = 0
                    disableTouches = true
                } else {DeselectEverything()}
                
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
        
        let guardButtonHolder = SKNode()
        guardButton = SKSpriteNode(texture: SKTexture(imageNamed: "FRINFEL3"), color: UIColor(), size: CGSize(width: 50, height: 10))
        guardButtonHolder.position = CGPoint(x: 0.0, y: -65.0)
        NTMenu!.addChild(guardButtonHolder)
        guardButtonHolder.addChild(guardButton!)
        guardButton!.zPosition = NTMenu!.zPosition + 1
        
        corpsMoveSelector = SpriteSelector(parentNode: corpsMoveButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        corpsDetachSelector = SpriteSelector(parentNode: corpsDetachButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        corpsAttachSelector = SpriteSelector(parentNode: corpsAttachButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        independentSelector = SpriteSelector(parentNode: independentButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        retreatSelector = SpriteSelector(parentNode: retreatButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        endTurnSelector = SpriteSelector(parentNode: endTurnButton!, initialSelection: .Option, theCoordinateSystem: NTMenu!, passDrawType: "EndTurn")
        commitSelector = SpriteSelector(parentNode: commitButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
        guardSelector = SpriteSelector(parentNode: guardButtonHolder, initialSelection: .Off, theCoordinateSystem: NTMenu!)
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
    func MoveGroupUnitSelection(touchedUnit:Unit) -> Bool {
        
        var sameCommand:Bool = false
        var touchedLeader:Bool = false
        var selectedUnit:Bool = false
        var unitsSelected:Bool = true
        
        var theCommand:Command!
        var theUnits:[Unit] = []
        
        // If current selection has something, set the command and units to the 1st current selection, otherwise the command is new
        if !manager!.currentGroupsSelected.isEmpty {
            theCommand = manager!.currentGroupsSelected[0].command
            theUnits = manager!.currentGroupsSelected[0].units
        } else {
            guard let theParent = touchedUnit.parent as? Command else {return true} // This false shouldn't happen
            theCommand = theParent
        }

        // If its a new command touched, check for attach or change selection
        if touchedUnit.parent != theCommand {
            sameCommand = false
            if CheckIfViableAttach(manager!.currentGroupsSelected[0], touchedUnit: touchedUnit) && corpsAttachSelector!.selected == .On {return false}
            theCommand = touchedUnit.parentCommand
        } else {
            sameCommand = true
        }
        
        if touchedUnit.selected == .NotSelectable {return true}
        if touchedUnit.unitType == .Ldr {touchedLeader = true}
        if touchedUnit.selected == .Selected {selectedUnit = true}
        if theUnits.count == 0 {unitsSelected = false}
        
        switch (touchedLeader, selectedUnit, sameCommand, unitsSelected) {
            
        case (true, _, _, _):
            // Leader always deselects whatever is selected then selects all in its command (including self)
            ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Normal)
            theUnits = theCommand.units
            for eachUnit in theUnits {eachUnit.selected = .Selected}
        case (false, true, _, _):
            // Selected unit (toggle)
            if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        case (false, false, true, _):
            // New unit in the same group
            if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        case (false, false, false, _):
            // New unit in a different group
            //print("here")
            ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Normal)
            touchedUnit.selected = .Selected; theUnits = [touchedUnit]
        }
        
        // Case where all but leader is selected
        if theUnits.count == theCommand.activeUnits.count - 1 && theCommand.theLeader?.selected == .Normal {theCommand.theLeader?.selected = .Selected; theUnits += [theCommand.theLeader!]}
        
        // Case where only leader is selected
        if theUnits == [] || (theUnits.count == 1 && theUnits[0].unitType == .Ldr) {
            DeselectEverything()
        } else {
            manager!.currentGroupsSelected = [Group(theCommand: theCommand, theUnits: theUnits)]
        }
        
        return true
    }
    
    // Sets the defense/retreat selection when a threat is made (returns the reserve area of the threat group)
    func DefenseGroupUnitSelection(touchedUnit:Unit, retreatMode:Bool = false, theTouchedThreat:GroupConflict) -> Reserve? {
        
        var selectableGroups:[Group]!
        var theReserve:Reserve!
        
        if retreatMode {selectableGroups = manager!.selectableRetreatGroups} else {selectableGroups = manager!.selectableDefenseGroups}
        
        if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {return nil}
        
        let parentCommand = touchedUnit.parentCommand!
        
        if parentCommand.currentLocation?.locationType == .Reserve {
            theReserve = parentCommand.currentLocation as! Reserve
        } else if parentCommand.currentLocation?.locationType == .Approach {
            theReserve = (parentCommand.currentLocation as! Approach).ownReserve
        } else {
            return nil
        }
        
        // Resets the selected units in the manager!.activeThreat
        if manager!.activeThreat == nil || theTouchedThreat.defenseReserve != manager!.activeThreat?.defenseReserve {manager!.activeThreat = theTouchedThreat}
        else if theTouchedThreat.defenseReserve != manager!.activeThreat!.defenseReserve {
            ToggleGroups(selectableGroups, makeSelection: .Normal)
            for eachReserve in manager!.selectionRetreatReserves {eachReserve.hidden = true}
            manager!.activeThreat = theTouchedThreat
        }
        
        if touchedUnit.unitType == .Ldr { // Always select all if selecting the leader
            
            if let indexOfCommand = selectableGroups.indexOf({$0.command == parentCommand}) {
                let leaderUnits:[Unit] = selectableGroups[indexOfCommand].nonLdrUnits
                for eachUnit in leaderUnits {eachUnit.selected = .Selected} // eachUnit.zPosition = 100
                if retreatMode {touchedUnit.selected = .Selected}
            }
        }
            
        else { // Normal click mode
            
            /*
            var selectedCount = 0
            var normalCount = 0
            var leaderStillSelected:Unit?
            
            for eachUnit in touchedUnit.parentCommand!.activeUnits {
                if eachUnit.unitType == .Ldr && eachUnit.selected == .Selected {leaderStillSelected = eachUnit}
                if eachUnit.selected == .Selected {selectedCount++}
                else if eachUnit.selected == .Normal {normalCount++}
            }
            */
            
            if touchedUnit.selected == .Selected {
                
                touchedUnit.selected = .Normal
                if !retreatMode && !parentCommand.hasLeader {ActivateDetached(theReserve, theGroups: selectableGroups, makeSelection: .Normal)}
                
                /*
                // Hanging leader
                if retreatMode && selectedCount == 2 && leaderStillSelected != nil {
                    leaderStillSelected!.selected = .Normal
                }
                */
                
            } else {
                
                if !retreatMode && !parentCommand.hasLeader {
                    ActivateDetached(theReserve, theGroups: selectableGroups, makeSelection: .NotSelectable)
                }
                touchedUnit.selected = .Selected
                
                /*
                // Hanging units
                if retreatMode && leaderStillSelected == nil && normalCount == 2 {
                    touchedUnit.parentCommand!.theLeader!.selected = .Selected
                }
                */
            }
        }
        
        return theReserve
        
    }
    
    func FeintDefenseUnitSelection(touchedUnit:Unit) {
        
        switch (touchedUnit.unitType == .Ldr, touchedUnit.selected == .Selected) {
            
        case (true, _):
            
            for eachUnit in touchedUnit.parentCommand!.activeUnits {
                if eachUnit.selected == .Normal {eachUnit.selected = .Selected}
            }
            
        case (false, true):
            
            touchedUnit.selected = .Normal
            
        case (false, false):
            
            touchedUnit.selected = .Selected
        }
        
        // Ensures a leader doesn't remain selected or a 2-unit command adds the leader when selected
        var selectedCount = 0
        var normalCount = 0
        var leaderStillSelected:Unit?
        for eachUnit in touchedUnit.parentCommand!.activeUnits {
            if eachUnit.unitType == .Ldr && eachUnit.selected == .Selected {leaderStillSelected = eachUnit}
            if eachUnit.selected == .Selected {selectedCount++}
            else if eachUnit.selected == .Normal {normalCount++}
        }
        if selectedCount == 1 && leaderStillSelected != nil {leaderStillSelected!.selected = .Normal} // Case of hanging leader
        else if leaderStillSelected == nil && selectedCount == touchedUnit.parentCommand!.activeUnits.count - 1 { // Case of the hanging units
            touchedUnit.parentCommand!.theLeader!.selected = .Selected
        }
    }
    
    func LeadingUnitSelection(touchedUnit:Unit) {
        
        if touchedUnit.unitType == .Ldr {return}
        if touchedUnit.selected == .Selected {touchedUnit.selected = .Normal}
        else {touchedUnit.selected = .Selected}
    }
    
    // Function updates selectionGroups based on what unit is selected
    func AttackGroupUnitSelection(touchedUnit:Unit!, realAttack:Bool, theTouchedThreat:Conflict) {
        
        let leaderTouched = touchedUnit.unitType == .Ldr
        let unitAlreadySelected = touchedUnit.selected == .Selected
        
        var groupTouched:Group!
        
        var newGroupTouched:Bool = true
        for eachGroup in manager!.currentGroupsSelected {
            if eachGroup.command == touchedUnit.parentCommand! {newGroupTouched = false; break}
        }
        
        // The selected group
        let commandtouched = touchedUnit.parentCommand!
        
        var maySelectAnotherCorps = false
        var maySelectASecondIndArt = false
        var requiredLocation:Location?
        var selectableGroups:[Group] = []
        
        // Real attack, setup detection of the corner cases (art, guard and multi corps)
        if realAttack {
            
            selectableGroups = manager!.selectableAttackAdjacentGroups
            groupTouched = selectableGroups.filter{$0.command == touchedUnit.parentCommand!}[0]
            
            var fullCorpsSelected = 0
            var indArtSelected = 0
            for eachGroup in manager!.currentGroupsSelected {
                
                if eachGroup.leaderInGroup {fullCorpsSelected++}
                if eachGroup.fullCommand && eachGroup.units.count == 1 && eachGroup.units[0].unitType == .Art && eachGroup.command.currentLocation!.locationType == .Approach {indArtSelected++}
            }
            if fullCorpsSelected > 0 && fullCorpsSelected <= manager!.corpsCommandsAvail {maySelectAnotherCorps = true}
            if indArtSelected == 1 {maySelectASecondIndArt = true}
            if maySelectAnotherCorps || maySelectASecondIndArt {requiredLocation = manager!.currentGroupsSelected[0].command.currentLocation!}
        } else {
            selectableGroups = manager!.selectableAttackByRoadGroups + manager!.selectableAttackAdjacentGroups
            groupTouched = selectableGroups.filter{$0.command == touchedUnit.parentCommand!}[0]
        }
        
        // Feint or advance after retreat (adjacent groups + rd groups)
        switch (unitAlreadySelected, leaderTouched) {
            
        case (_, true):
            
            var newGroups:[Group] = []
            newGroups = [groupTouched!]
            
            if !manager!.currentGroupsSelected.isEmpty {
            
                for eachGroup in manager!.currentGroupsSelected {
                    if eachGroup.command != touchedUnit.parentCommand! {
                        if eachGroup.leaderInGroup && maySelectAnotherCorps && touchedUnit.parentCommand!.currentLocation! == requiredLocation! {newGroups += [eachGroup]}
                        else {ToggleGroups([eachGroup], makeSelection: .Normal)}
                    }
                }
                
            }
            manager!.currentGroupsSelected = newGroups
            ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Selected)
            
        case (true, false):
            
            let theIndex = manager!.currentGroupsSelected.indexOf{$0.command == touchedUnit.parentCommand!}
            
            // 2-size corps or last unit deselected case
            if (manager!.currentGroupsSelected[theIndex!].units.count == 2 && manager!.currentGroupsSelected[theIndex!].leaderInGroup) || manager!.currentGroupsSelected[theIndex!].units.count == 1 {
                ToggleGroups([groupTouched], makeSelection: .Normal)
            
            // Case where selected units in the group will remain
            } else {
                var theUnits = manager!.currentGroupsSelected[theIndex!].units
                theUnits.removeObject(touchedUnit)
                touchedUnit.selected = .Normal
                manager!.currentGroupsSelected += [Group(theCommand: commandtouched, theUnits: theUnits)]
            }
            
            manager!.currentGroupsSelected.removeAtIndex(theIndex!)
            
        case (false, false):
            
            // Touched an unselected unit outside the selected group
            var theUnits:[Unit] = []
            
            if newGroupTouched {
                
                // 2nd Corps selection...
                if touchedUnit.parentCommand!.activeUnits.count == 2 {
                    if !maySelectAnotherCorps || touchedUnit.parentCommand!.currentLocation! != requiredLocation! {
                        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Normal)
                        manager!.currentGroupsSelected = []
                    }
                    theUnits += touchedUnit.parentCommand!.activeUnits
                }
                else {
                    if !maySelectASecondIndArt || touchedUnit.unitType != .Art || touchedUnit.parentCommand!.currentLocation! != requiredLocation! {
                        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Normal)
                        manager!.currentGroupsSelected = []
                    }
                    theUnits = [touchedUnit]
                }
                
            // Touched an unselected unit within the selected group (can't be a two-unit corps else it would be the leader)
            } else {
                let theIndex = manager!.currentGroupsSelected.indexOf{$0.command == touchedUnit.parentCommand!}
                theUnits = manager!.currentGroupsSelected[theIndex!].units
                theUnits.append(touchedUnit)
                
                // Case where leader is last not selected... (must be selected)
                if theUnits.count == touchedUnit.parentCommand!.activeUnits.count - 1 {theUnits.append(touchedUnit.parentCommand!.theLeader!)}
                
                manager!.currentGroupsSelected.removeAtIndex(theIndex!)
            }
            
            manager!.currentGroupsSelected += [Group(theCommand: commandtouched, theUnits: theUnits)]
            ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Selected)
            
        }
    }
    
    func ToggleBattleWidthUnitSelection(touchedUnit:Unit!, theThreat:Conflict) {
        
        let unitSelectedAlready = touchedUnit.selected == .Selected
        
        var unitsSelected = 0
        var theUnselectedUnit:Unit?
        for eachGroup in theThreat.defenseLeadingUnits!.groups {
            for eachUnit in eachGroup.units {
                if eachUnit.selected == .Selected {unitsSelected++}
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
    
    // Sets the viable moves and orders for a given selection (under move orders)
    func  MoveOrdersAvailable(setCommands:Bool = true) {
    
        // Hide locations, check that we have a selection group then update based on what was touched
        if manager!.currentGroupsSelected.isEmpty {return}
        HideAllLocations(true)

        if setCommands {
            // Set the commands available
            (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected) = OrdersAvailableOnMove(manager!.currentGroupsSelected[0], ordersLeft: ((manager?.corpsCommandsAvail)!, (manager?.indCommandsAvail)!))
        }
            
        // Setup the swipe queue for the selected command
        (adjMoves, attackThreats, mustFeintThreats) = MoveLocationsAvailable(manager!.currentGroupsSelected[0], selectors: (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected), undoOrAct:undoOrAct)
        
        // Reveal all locations if on a start location
        if manager!.currentGroupsSelected[0].command.currentLocationType == .Start {HideAllLocations(false, hiddenLocationsOnly: false)}
    }
    
    func AttackOrdersAvailable(setCommands:Bool = true) {
        
        guard let theConflict = manager!.activeThreat?.conflict else {return}

        if setCommands {
            // Set the commands available
            (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected) = OrdersAvailableOnAttack(manager!.currentGroupsSelected, ordersLeft: (manager!.corpsCommandsAvail, manager!.indCommandsAvail), theConflict: theConflict)
        }
            
        if manager!.phaseOld != .DeclaredLeadingD { // This is attack declaration where movement is possible
            
            var attackNodes:[SKNode] = []
            HideAllLocations(true)
            
            if !manager!.currentGroupsSelected.isEmpty {
                
                let theGroup = manager!.currentGroupsSelected[0]
                attackNodes = AttackMoveLocationsAvailable(theGroup, selectors: (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected), feint: manager!.phaseOld != .RetreatedBeforeCombat, theConflict:theConflict, undoOrAct:undoOrAct)
             
                // Setup the swipe queue for the selected command
                for eachNode in attackNodes {eachNode.hidden = false}
            }
        }
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
        
        ToggleGroups(manager!.currentGroupsSelected, makeSelection: .Normal)
        manager!.currentGroupsSelected = []
        
        HideAllLocations(true)
        ResetSwipeQueue()
        
        (corpsMoveSelector!.selected, corpsDetachSelector!.selected, corpsAttachSelector!.selected, independentSelector!.selected) = (.Off, .Off, .Off, .Off)
    }
    
    func HideAllLocations (hide:Bool, hiddenLocationsOnly:Bool = true) {
        
        if hide {
        
            hiddenLocations = []
            
            for each in manager!.reserves {
                if each.hidden == false {
                    hiddenLocations += [each]
                    each.hidden = true
                }
            }
            for each in manager!.approaches {
                if each.hidden == false {
                    hiddenLocations += [each]
                    each.hidden = true
                }
            }
        } else {
            
            if hiddenLocationsOnly {for each in hiddenLocations {each.hidden = false}}
            else {
                for each in manager!.reserves {each.hidden = false}
                for each in manager!.approaches {each.hidden = false}
            }
        }
    }
    
    func HideAllCommands (hide:Bool) {
        
        for each in (manager!.gameCommands[manager!.actingPlayer]! + manager!.gameCommands[manager!.actingPlayer.Other()!]!) {each.hidden = hide}
    }
    
    func ResetSelectors() {
        corpsMoveSelector?.selected = .Off
        independentSelector?.selected = .Off
        corpsDetachSelector?.selected = .Off
        corpsAttachSelector?.selected = .Off
        //retreatSelector?.selected = .Off
        //guardSelector?.selected = .Off
    }
    
    func HideAllOrderArrows (hide:Bool) {
        
        for eachOrder in manager!.orders {if eachOrder.orderArrow != nil {eachOrder.orderArrow!.hidden = hide}}
        
    }
    
    func ReturnMoveType () -> MoveType {
        if corpsMoveSelector!.selected == .On {return .CorpsMove}
        else if corpsDetachSelector!.selected  == .On {return .CorpsDetach}
        else if independentSelector!.selected == .On {return .IndMove}
        else if manager!.phaseOld == .Setup {return .CorpsMove}
        else {return .None}
    }
        
}






