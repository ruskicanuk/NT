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

// AI Variables
var ai:[Allegience:AI] = [:]
var aiThinking:Bool = false
var aiTurn:Bool = false
var aiThinkingStartTime:CFTimeInterval?

// Available locations
var adjMoves:[Location] = []
var attackThreats:[Approach] = []
var mustFeintThreats:[Approach] = []

// Limits user touching
var undoOrAct:Bool = false {

    didSet {
    
        if undoOrAct {
        
            endTurnButton.buttonState = .Off
        
        } else {
        
            switch manager!.phaseNew {
            case .Move: endTurnButton.buttonState = .On
            default: break
        
            }
        
        }
    
    }

}

var zoomedMode:Bool = false {

    didSet {
        
        updateZoomLevel()
    
    }

}

class GameScene: SKScene, NSXMLParserDelegate {
    
    // MARK: Main Properties
    
    var viewController:GameViewController!
    
    // Playback properties
    var selectedStatePoint:ReviewState = .Front
    
    var statePoint:ReviewState = .Front {
        didSet {
            var relevantOrders:[Order] = []
            if statePoint == .Front && manager!.phaseNew == .Move {
                if manager!.orders.count > 0 {relevantOrders = manager!.orders}
                manager!.RemoveNonMovementArrows(relevantOrders)
            } else if statePoint == .Middle && manager!.phaseNew == .Move {
                if manager!.orderHistoryIndex > 0 {relevantOrders = manager!.orderHistory[manager!.orderHistoryIndex-1]!}
                manager!.RemoveNonMovementArrows(relevantOrders)
            }
            manager!.statePointTracker = statePoint // Stores current state
            updatePlaybackState() // Label
        }
    }
    
    // Playback timing
    var fastFwdIndex:Int = 0
    var fastFwdExecuted:CFTimeInterval = 0
    
    var disableTouches = false
    
    // Hold touch
    var touchStartTime:CFTimeInterval?
    var holdNode:SKNode?
    
    // Name of Selectors
    let mapName:String = "Map"
    let commandName:String = "Command"
    let unitName:String = "Unit"
    let approachName:String = "Approach"
    let reserveName:String = "Reserve"
    
    // Stores name of selection
    var selectionCase:String = ""
    
    // MARK: Swiping Properties and Function

    var swipeStartPoint:CGPoint?
    var swipeStart:Bool = false
    var swipeDown:Bool = false
    var swipeUp:Bool = false
    var swipeQueue = [SKNode?]()
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
        else {swipeQueue[swipeQueueIndex]!.zPosition = 200}
        
        if swipeQueue[nextIndex] is Command {(swipeQueue[nextIndex] as! Command).SetUnitsZ(1000)}
        else {swipeQueue[nextIndex]!.zPosition = 1000}

        swipeQueueIndex = nextIndex
    }
    
    func ResetSwipeQueue() {
        
        for eachObject in swipeQueue {
            if eachObject is Command {(eachObject as! Command).SetUnitsZ(100)}
            else {eachObject!.zPosition = 200}
        }
        
        swipeQueue = []
        swipeQueueIndex = 0
        newSwipeQueue = true
    }
    
    // MARK: Move To View
    
    override func didMoveToView(view: SKView) {
        
        mapScaleFactor = setupMap()
        setupMenu()
        setupCommandDashboard()
        
        // Save loader
        let sManager = StateManager()
        
        if sManager.games.count > 0
        {
            manager = sManager.games.first
        }
        else
        {
            // Setup game-manager
            manager = GameManager()
            chooseAI()
        }
        
        // Initialize AI
        if manager!.auAI {
            ai[.Austrian] = AI(passedSide: .Austrian)
        }
        if manager!.frAI {
            ai[.French] = AI(passedSide: .French)
        }

        // Updates the command labels
        updateCommandLabel()
        updateIndLabel()
        updatePhasingLabel()
        updateActingLabel()
        updateTurnLabel()
        updateMoraleLabel()
        updatePlaybackState()
        
        //Parse xml file to finish map setup
        parseXMLFileWithName("MapBuilder")
        linkApproaches()
        linkReserves()
        
        // Hide the locations
        HideAllLocations(true)
        
        // ### Remove later for setup phase
        manager!.NewTurn()
        manager!.NewTurn()
        manager!.NewTurn()
    }
    
    func chooseAI() {
        
        if frenchAIChoice.buttonState == .On {
            manager!.frAI = true
            manager!.auAI = false
            manager!.multiPlayerMatch = false
        } else if austrianAIChoice.buttonState == .On {
            manager!.frAI = false
            manager!.auAI = true
            manager!.multiPlayerMatch = false
        } else if bothAIChoice.buttonState == .On {
            manager!.frAI = true
            manager!.auAI = true
            manager!.multiPlayerMatch = false
        } else if noAIChoice.buttonState == .On {
            manager!.frAI = false
            manager!.auAI = false
            manager!.multiPlayerMatch = true
        }
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
            
            if each is SKShapeNode {
                
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
            countTouches += 1
        }
        
        return touchedNode
    }
    
    // Called when screen is pressed and held for a period of 1 second
    func HoldTouch() {
        
        // Safety drill
        guard let touchedUnit = holdNode as? Unit else {holdNode = nil; return}
        guard let touchedParent = touchedUnit.parent as? Command else {holdNode = nil; return}
        if activeConflict == nil {holdNode = nil; return}
        
        if ReduceStrengthIfRetreat(touchedUnit, theLocation:touchedParent.currentLocation!, theGroupConflict:activeGroupConflict!, retreatMode:(retreatButton.buttonState == .Option)) {
            ReduceUnitUI(Group(theCommand: touchedParent, theUnits: [touchedUnit]), theGroupConflict:activeGroupConflict!)
        }

        holdNode = nil
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
    }
    
    // MARK: Touches
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches || aiThinking || aiTurn || aiTurn {return Void()}
        
        // Find the touched nodes
        let touch = touches.first as UITouch!
        let mapLocation:CGPoint? = touch.locationInNode(NTMap)
        
        //let acceptableDistance:CGFloat = mapScaleFactor*50
        if mapLocation == nil {return Void()}
        let touchedNodesMap = self.nodesAtPoint(mapLocation!)

        if newSwipeQueue {
            //for eachCommand in manager!.gameCommands[manager!.actingPlayer]! {
                //let distanceFromCommandSelected = DistanceBetweenTwoCGPoints(eachCommand.position, Position2: mapLocation!)
                //if distanceFromCommandSelected < acceptableDistance {
                //TODO: Find the solution for below 2 commented lines
                //swipeQueue += [eachCommand]
                //}
            //}
            swipeQueueIndex = 0
            newSwipeQueue = false
        }
        
        if !swipeQueue.isEmpty {
            swipeStartPoint = mapLocation
            swipeStart = true
        }
        if manager!.phaseNew == .PostCombatRetreatAndVictoryResponseMoves || manager!.phaseNew == .RetreatOrDefenseSelection {
            holdNode = theTouchedNode(touchedNodesMap, mapLocation: mapLocation!)
            touchStartTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    // ### May want to replace with more elegant swipe (as was done for zooming)
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        if statePoint != .Front || disableTouches || aiThinking || aiTurn {return Void()}
        
        // Start if initial tap met the right conditions (Command is selected + tap is close enough)
        if swipeStart {
            
            let touch = touches.first as UITouch!
            let mapLocation = touch.locationInNode(NTMap)
            let yRequiredForSwipe:CGFloat = mapScaleFactor*20.0
            
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
        
        // Exit if in rewind mode
        if statePoint != .Front || aiThinking || aiTurn {return}
        if manager!.phaseNew == .Commit && manager!.gameMode == "Traditional" {return}
        
        touchStartTime = nil
        holdNode = nil
        if disableTouches {return}

        //Find the selected node within the map and the scene
        let touch = touches.first as UITouch!
        let mapLocation = touch.locationInNode(NTMap)

        let touchedCount:Int = touch.tapCount

        let touchedNodesMap = self.nodesAtPoint(mapLocation)
        var touchedNode:SKNode? = theTouchedNode(touchedNodesMap, mapLocation:mapLocation, touchedCount:touchedCount)

        // UndoOrAct allows only approach, reserve touching
        
        if touchedNode == NTMap {
            print("MapTouch", terminator: "\n")
            if undoOrAct {return}
            selectionCase = mapName
        } else if touchedNode is Approach {
            print("ApproachTouch", terminator: "\n")
            selectionCase = approachName
        } else if touchedNode is Reserve {
            print("ReserveTouch", terminator: "\n")
            selectionCase = reserveName
        } else if touchedNode is Command {
            print("CommandTouch Units: \((touchedNode as! Command).units.count) Active Units: \((touchedNode as! Command).activeUnits.count)", terminator: "\n")
            if undoOrAct {return}
            selectionCase = mapName
        } else if touchedNode is Unit {
            print("UnitTouch", terminator: "\n")
            if undoOrAct {return}
            selectionCase = unitName
        } else {
            if undoOrAct {return}
            ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: true, otherSelectors: true)
            print("NothingTouch", terminator: "\n")
        }
        
        // This makes selection the same as touching the leader in zoomed out mode
        if selectionCase == mapName && touchedCount == 2 {
            let touchLocation = touch.locationInView(view!)
            viewController.zoomToPoint(touchLocation, zoomLevel: 3.1)
            //viewController.setZoomScale(4.1, animated: true)
            return
        } else if !zoomedMode && selectionCase == unitName {
            
            let touchedUnit = touchedNode as? Unit
            
            if touchedUnit != nil && touchedUnit!.unitType != .Ldr && touchedUnit!.parentCommand!.hasLeader && touchedUnit!.parentCommand!.theLeader!.selected != .NotSelectable && touchedUnit!.parentCommand!.theLeader!.selected != .Off {
                touchedNode = touchedUnit!.parentCommand!.theLeader!
            } else if touchedUnit != nil && touchedUnit!.unitType != .Ldr && touchedUnit!.parentCommand!.hasLeader && (touchedUnit!.parentCommand!.theLeader!.selected == .NotSelectable || touchedUnit!.parentCommand!.theLeader!.selected == .Off) {
                return
            }
        }
        
        if !zoomedMode && touchedCount >= 2 {
            return
        }
        
        // Touch Processing
        switch (manager!.phaseNew, selectionCase) {
        
        // MARK: Move Touch
            
        case (.Setup, unitName):
            
            // Safety Check
            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .Off || touchedUnit.selected == .NotSelectable {break}
            
            HideAllLocations(false)

        case (.Move, unitName), (.Commit, unitName):
            
            // Safety Check
            guard let touchedUnit = touchedNode as? Unit else {break}
            
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .Off {break}

            if MoveGroupUnitSelection(touchedUnit, touchedCount: touchedCount) {
                if touchedUnit.selected == .NotSelectable {break}
                ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: false)
                MoveOrdersAvailable()
            }
                
            // Attach scenario
            else if manager!.phaseNew == .Move {
                
                // Create an order
                let newOrder = Order(groupFromView: manager!.groupsSelected[0], touchedUnitFromView: touchedUnit, orderFromView: .Attach)
                
                // Execute the order and add to order array
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
                
                ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
            }
            
        case (.Setup, mapName), (.Move, mapName), (.Commit, mapName):
            
            ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
            
        case (.Setup, reserveName), (.Move, reserveName):
            
            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: true)
            if touchedNode != nil && !manager!.groupsSelected.isEmpty {MoveUI(touchedNode!)}
            
        case (.Setup, approachName), (.Move, approachName), (.Commit, approachName):
            
            guard let touchedApproach = touchedNode as? Approach else {break}
            
            if !manager!.groupsSelected.isEmpty && manager!.groupsSelected.count == 1 {
                if attackThreats.contains(touchedApproach) {
                    AttackThreatUI(touchedNode!, mustFeint: false)
                    if manager!.phaseNew == .Move {manager!.NewPhase()}
                    ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                } else if mustFeintThreats.contains(touchedApproach) {
                    AttackThreatUI(touchedNode!, mustFeint: true)
                    if manager!.phaseNew == .Move {manager!.NewPhase()}
                    ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                } else {
                    ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: true)
                    MoveUI(touchedNode!)
                }
            }
            
        // MARK: Conflict Touch
            
        case (.RetreatOrDefenseSelection, approachName), (.SelectDefenseLeading, approachName), (.SelectAttackLeading, approachName), (.SelectCounterGroup, approachName), (.PreRetreatOrFeintMoveOrAttackDeclare, approachName), (.SelectAttackGroup, approachName), (.FeintResponse, approachName), (.PostCombatRetreatAndVictoryResponseMoves, approachName):
            
            // Safety check
            guard let touchedApproach = touchedNode as? Approach else {break}
            var maySelectConflict = true
            if undoOrAct && activeConflict != nil && activeConflict!.defenseApproach.approachSelector!.selected == .Option {maySelectConflict = false}
            
            if touchedApproach.approachSelector!.selected != .Off && maySelectConflict {
         
                ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                undoOrAct = false
                
                for eachLocaleConflict in manager!.localeThreats {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.defenseApproach == touchedApproach {
                            if activeConflict != nil {ResetActiveConflict(activeConflict!)}
                            activeConflict = eachConflict
                            break
                        }
                    }
                }
                SetupActiveConflict()
                
            // Case where the approach is selected for movement-purposes
            } else if touchedApproach.approachSelector!.selected == .Off && !manager!.groupsSelected.isEmpty {
                
                if manager!.phaseNew == .FeintResponse || manager!.phaseNew == .PostCombatRetreatAndVictoryResponseMoves {
                    let theSelectionGroup = GroupSelection(theGroups: GroupsIncludeLeaders(activeConflict!.defenseGroup!.groups))
                    DefendAgainstFeintUI(touchedApproach, feintSelection: theSelectionGroup)
                    ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: false, otherSelectors: false)
                } else {
                    MoveUI(touchedNode!)
                    ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
                }

                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
            }

        // MARK: Pre-retreat or Defend
        
        case (.RetreatOrDefenseSelection, unitName):
            
            // Safety drill
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off || touchedUnit.unitSide != manager!.actingPlayer {break}
            if !activeGroupConflict!.retreatMode && activeConflict!.approachDefended {break}
            
            DefenseGroupUnitSelection(touchedUnit, retreatMode:(retreatButton.buttonState == .On || retreatButton.buttonState == .Option), theTouchedThreat: activeGroupConflict!, touchedCount: touchedCount)
            
            manager!.groupsSelected = GroupSelection(theGroups: manager!.groupsSelectable).groups
            
            if activeGroupConflict!.retreatMode {
                retreatButton.buttonState = CheckRetreatViable(manager!.groupsSelected)
            }
            
            if !manager!.groupsSelected.isEmpty && !activeGroupConflict!.retreatMode {
                endTurnButton.buttonState = .Option
            } else {
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
            }

        case (.RetreatOrDefenseSelection, reserveName), (.PostCombatRetreatAndVictoryResponseMoves, reserveName):
            
            guard let touchedReserve = touchedNode as? Reserve else {break}
            RetreatUI(touchedReserve)

            if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
            
        case (.RetreatOrDefenseSelection, mapName):
            
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: false)
            if retreatButton.buttonState == .On || retreatButton.buttonState == .Option {
                retreatButton.buttonState = .Option
                for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: false)}
            }
            
            if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
        
        // MARK: Attack Moves and Declaration Touch
        
        case (.PreRetreatOrFeintMoveOrAttackDeclare, unitName), (.SelectAttackGroup, unitName):

            // Safety checks
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare && touchedUnit.fixed {break}
            
            // When touching the opposing side's selected unit
            if touchedUnit.parentCommand!.commandSide.Opposite(manager!.actingPlayer)! {
                ToggleBattleWidthUnitSelection(touchedUnit, theThreat: activeConflict!)
                break
            }
            
            // 1st: Updates which units are selected, 2nd: Updates orders available, 3rd update locations
            AttackGroupUnitSelection(touchedUnit, realAttack:(manager!.phaseNew == .SelectAttackGroup), theTouchedThreat: activeConflict!, touchedCount: touchedCount)
            AttackOrdersAvailable()
            
            if manager!.phaseNew == .SelectAttackGroup {
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
                else if manager!.groupsSelected.isEmpty {endTurnButton.buttonState = .Off}
                else {endTurnButton.buttonState = .Option}
            }
            if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare && manager!.groupsSelected.isEmpty && !activeGroupConflict!.retreatMode {commitButton.buttonState = .Option}
            else {commitButton.buttonState = .Off}
            
        case (.PreRetreatOrFeintMoveOrAttackDeclare, mapName), (.SelectAttackGroup, mapName):
            
            // Safety checks
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
            
            if manager!.phaseNew == .SelectAttackGroup {
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
                break
            }
            
            // Setup buttons
            if activeGroupConflict!.retreatMode || activeConflict!.mustFeint {commitButton.buttonState = .Off}
            else if activeConflict!.guardAttack {guardButton.buttonState = .On; commitButton.buttonState = .Option}
            else {commitButton.buttonState = .Option}
            
        case (.PreRetreatOrFeintMoveOrAttackDeclare, reserveName):

            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
            if touchedNode != nil && activeConflict != nil && !manager!.groupsSelected.isEmpty {MoveUI(touchedNode!)}
            
        // MARK: Select Leading Units
        
        case (.SelectDefenseLeading, unitName), (.SelectAttackLeading, unitName), (.SelectCounterGroup, unitName):
            
            // Safety checks
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: false, orderSelectors: false, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            
            LeadingUnitSelection(touchedUnit)
            (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(activeConflict!, thePhase: manager!.phaseNew)
            
        case (.SelectDefenseLeading, mapName), (.SelectAttackLeading, mapName), (.SelectCounterGroup, mapName):
            
            // Safety checks
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: false)
            
            (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(activeConflict!, thePhase: manager!.phaseNew)
            
        // MARK: Feint Defense
            
        case (.FeintResponse, unitName):
            
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: false, orderSelectors: false, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {break}
            
            FeintDefenseUnitSelection(touchedUnit, touchedCount: touchedCount)
            
            let theSelectionGroup = GroupSelection(theGroups: GroupsIncludeLeaders(activeConflict!.defenseGroup!.groups))
            manager!.groupsSelected = theSelectionGroup.groups
            var movableUnits = false
            for eachGroup in theSelectionGroup.groups {
                if eachGroup.nonLdrUnitCount == 0 {
                    movableUnits = false
                    break
                } else {
                    movableUnits = true
                }
            }
            
            // If end-turn condition yet to be reached (if not, run the selection and show the approach)
            if movableUnits {
                activeConflict!.defenseApproach.approachSelector!.selected = .Off
                activeConflict!.defenseApproach.zPosition = 200
            }
            
        case (.FeintResponse, mapName):

            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: false, orderSelectors: false, otherSelectors: false)
            
            let theSelectionGroup = GroupSelection(theGroups: GroupsIncludeLeaders(activeConflict!.defenseGroup!.groups))
            for eachGroup in theSelectionGroup.groups {
                for eachUnit in eachGroup.units {
                    eachUnit.selected = .Normal
                }
            }
            ResetState(true, groupsSelectable: false, hideRevealed: false, orderSelectors: false, otherSelectors: false)

            activeConflict!.defenseApproach.approachSelector!.selected = .Option
            endTurnButton.buttonState = .Off
            SetupActiveConflict()
            
        // MARK: Post Combat Retreat or Feint
        
        case (.PostCombatRetreatAndVictoryResponseMoves, unitName):
            
            // Safety drill
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
            guard let touchedUnit = touchedNode as? Unit else {break}
            if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off || touchedUnit.unitSide != manager!.actingPlayer || touchedUnit.fixed {break}
            
            if activeGroupConflict!.retreatMode {
            
                DefenseGroupUnitSelection(touchedUnit, retreatMode: true, theTouchedThreat: activeGroupConflict!, touchedCount: touchedCount)
                manager!.groupsSelected = GroupSelection(theGroups: manager!.groupsSelectable).groups
                retreatButton.buttonState = CheckRetreatViable(manager!.groupsSelected)

            } else {
                
                FeintDefenseUnitSelection(touchedUnit, touchedCount: touchedCount)
                
                let theSelectionGroup = GroupSelection(theGroups: GroupsIncludeLeaders(activeConflict!.defenseGroup!.groups))
                manager!.groupsSelected = theSelectionGroup.groups
                var movableUnits = false
                for eachGroup in theSelectionGroup.groups {
                    if eachGroup.nonLdrUnitCount == 0 {
                        movableUnits = false
                        break
                    } else {
                        movableUnits = true
                    }
                }
                
                // If end-turn condition yet to be reached (if not, run the selection and show the approach)
                if movableUnits {
                    activeConflict!.defenseApproach.approachSelector!.selected = .Off
                    activeConflict!.defenseApproach.zPosition = 200
                }
            }
            
            //if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
            
        case (.PostCombatRetreatAndVictoryResponseMoves, mapName):
            
            if activeConflict == nil || activeConflict!.defenseApproach.approachSelector!.selected == .On {break}
            ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
            
            if activeConflict!.parentGroupConflict!.retreatMode {
                retreatButton.buttonState = .Option
                for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: false)}
            } else {
                
            }
            
            activeConflict!.defenseApproach.approachSelector!.selected = .Option
            endTurnButton.buttonState = .Off
            SetupActiveConflict()
            
        default: break
            
        }
    }

    // MARK: Fast-fwd & Rewind
    
    // Fast-fwd cycle
    func CycleOrdersFwd(direction:Bool = true) {

        switch (statePoint, direction) {
            
        case (.Back, true):
            
            if manager!.orderHistoryIndex == 0 || fastFwdIndex == manager!.orderHistory[manager!.orderHistoryIndex-1]!.endIndex {
                fastFwdIndex = 0
                statePoint = .Middle
                disableTouches = false
            } else {
                let historicalOrders = manager!.orderHistory[manager!.orderHistoryIndex-1]!
                historicalOrders[fastFwdIndex].ExecuteOrder(false, playback: true)
                
                fastFwdIndex += 1
            }
            
        case (.Middle, true):
        
            if fastFwdIndex == manager!.orders.endIndex {
                fastFwdIndex = 0
                statePoint = .Front
                disableTouches = false
            } else {
                let historicalOrders = manager!.orders
                historicalOrders[fastFwdIndex].ExecuteOrder(false, playback: true)

                fastFwdIndex += 1
            }
        
        default:
            break
            
        }
    }
    
    // MARK: Update
    
    // Runs several times a second
    override func update(currentTime: CFTimeInterval) {
        
        // Holding down functionality
        if aiThinking && aiThinkingStartTime != nil {
            let aiThinkTime = CFAbsoluteTimeGetCurrent() - aiThinkingStartTime!
            if aiThinkTime > 1.0 {
                //ai[manager!.actingPlayer]!.aiUpdateCommands()
                if ai[manager!.actingPlayer]!.AIEngine() {
                    aiThinkingStartTime = CFAbsoluteTimeGetCurrent()
                } else {
                    aiThinking = false
                    aiTurn = true
                    aiThinkingStartTime = nil
                    endTurnButton.buttonState = .On
                }
            }
        return
        }
        
        // Holding down functionality
        if touchStartTime != nil {
            let touchHoldTime = CFAbsoluteTimeGetCurrent() - touchStartTime!
            if touchHoldTime > 1.0 {
                HoldTouch()
                touchStartTime = nil
                holdNode = nil
            }
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
            NTMap.addChild(newApproach)
            manager!.approaches += [newApproach]
            
        case "Reserve"?:
            
            let xmlDict = attributeDict
            let newReserve:Reserve = Reserve(theDict: xmlDict, scaleFactor: mapScaleFactor, reserveLocation:true)
            NTMap.addChild(newReserve)
            manager!.reserves += [newReserve]
            
        case "Command"?:
            
            let xmlDict = attributeDict
            let newCommand:Command = Command(theDict: xmlDict)
            
            if newCommand.loc == "Reserve" {
            
                newCommand.currentLocation?.occupants.removeObject(newCommand)
                newCommand.currentLocation = manager!.reserves.filter { $0.name == newCommand.locID }.first
                
                // Setup turn units may enter map
                let currentReserve = newCommand.currentLocation as! Reserve
                if currentReserve.offMap && newCommand.hasLeader && newCommand.theLeader!.unitCode == 251.1 {newCommand.turnMayEnterMap = 2}
                else if currentReserve.offMap && newCommand.hasLeader && newCommand.theLeader!.unitCode == 251.2 {newCommand.turnMayEnterMap = 6}
                
                newCommand.moveNumber = 0
                
            } else if newCommand.loc == "Approach" {
                
                newCommand.currentLocation?.occupants.removeObject(newCommand)
                newCommand.currentLocation = manager!.approaches.filter { $0.name == newCommand.locID }.first
                newCommand.moveNumber = 0
            }
            
            newCommand.currentLocation?.occupants += [newCommand]
            
            NTMap.addChild(newCommand)
            manager!.gameCommands[newCommand.commandSide]! += [newCommand]
            
        default:
            break
        }
    }
    
    /*
    private func openSelectScene() {

        let viewSize = CGSize(width: view!.bounds.size.width/2, height: view!.bounds.size.width/2)
        let selectScene = SelectScene(size: viewSize)
        let transition = SKTransition.fadeWithDuration(0.4)
        
        selectView.hidden = false
        selectView.presentScene(selectScene, transition: transition)
        //selectScene.scaleMode = .AspectFill
    }
    */
    
    // Setup map
    func setupMap () -> CGFloat {
        
        NTMap = SKSpriteNode(imageNamed: "MapBoardMedium")
        
        if NTMap != nil {
        
        var setMapX:CGFloat
        var setMapY:CGFloat
        let sceneSizeX:CGFloat = self.size.width
        let sceneSizeY:CGFloat = self.size.height
        let mapSizeX:CGFloat = NTMap.size.width
        let mapSizeY:CGFloat = NTMap.size.height
            
        let sceneAspect:CGFloat = sceneSizeY / sceneSizeX
        let mapAspect:CGFloat = mapSizeY / mapSizeX
            
            if sceneAspect >= mapAspect {
                setMapX = sceneSizeX
                setMapY = setMapX*mapAspect
            } else {
                setMapY = sceneSizeY
                setMapX = setMapY*(1/mapAspect)
            }
            
        NTMap.anchorPoint = CGPoint(x: 0.0,y: 0.0)
        NTMap.size = CGSize(width: setMapX, height: setMapY)
        NTMap.position = CGPoint(x: 0.0, y: 0.0)
        NTMap.zPosition = 0.0
            
        self.addChild(NTMap)
        
        return (setMapX/editorPixelWidth)
        
        //Nil case
        } else {
        
        return 1.0
        }
    }
    
    // Setup menu
    func setupMenu () {
        
        // ### Temporary until UI dev phase
        labelMenu.hidden = false
        baseMenu.hidden = false
        frenchAIChoice.hidden = true
        austrianAIChoice.hidden = true
        noAIChoice.hidden = true
        bothAIChoice.hidden = true
        // ###
        
        var topPosition:CGFloat = 5*mapScaleFactor
        var rightPosition:CGFloat = 5*mapScaleFactor
        
        let undoImage = UIImage.init(named: "black_marker")!
        undoButton = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, undoImage.size.width*mapScaleFactor, undoImage.size.height*mapScaleFactor))
        undoButton.setImage(undoImage, forState: UIControlState.Normal)
        undoButton.addTarget(self, action:#selector(GameScene.undoTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(undoButton)
        
        topPosition += 0
        rightPosition = undoImage.size.width*mapScaleFactor + 10*mapScaleFactor

        let endTurnImage = UIImage.init(named: "blue_marker")!
        endTurnButton = UIStateButton.init(initialState: .Option, theRect: CGRectMake(rightPosition, topPosition, endTurnImage.size.width*mapScaleFactor, endTurnImage.size.height*mapScaleFactor))
        endTurnButton.setImage(endTurnImage, forState: UIControlState.Normal)
        endTurnButton.addTarget(self, action:#selector(GameScene.endTurnTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(endTurnButton)
        
        topPosition += endTurnImage.size.height*mapScaleFactor + 10*mapScaleFactor
        rightPosition = 5*mapScaleFactor
        
        let terrainImage = UIImage.init(named: "FRback")!
        terrainButton = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, terrainImage.size.width*mapScaleFactor, terrainImage.size.height*mapScaleFactor))
        terrainButton.setImage(terrainImage, forState: UIControlState.Normal)
        terrainButton.addTarget(self, action:#selector(GameScene.hideTerrainTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(terrainButton)
        
        topPosition += terrainImage.size.height*mapScaleFactor + 10*mapScaleFactor
        rightPosition = 5*mapScaleFactor
        
        let rewindImage = UIImage.init(named: "icon_red_down")!
        rewindButton = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, rewindImage.size.width*2*mapScaleFactor, rewindImage.size.height*2*mapScaleFactor))
        rewindButton.setImage(rewindImage, forState: UIControlState.Normal)
        rewindButton.addTarget(self, action:#selector(GameScene.rewindTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        rewindButton.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        baseMenu.addSubview(rewindButton)
        
        topPosition += 0
        rightPosition = rewindImage.size.width*2*mapScaleFactor + 1*mapScaleFactor
        
        let fastFwdImage = UIImage.init(named: "icon_blue_down")!
        fastfwdButton = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, fastFwdImage.size.width*2*mapScaleFactor, fastFwdImage.size.height*2*mapScaleFactor))
        fastfwdButton.setImage(fastFwdImage, forState: UIControlState.Normal)
        fastfwdButton.addTarget(self, action:#selector(GameScene.fastFwdTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        fastfwdButton.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        baseMenu.addSubview(fastfwdButton)
        
        topPosition += rewindImage.size.height*2*mapScaleFactor + 1*mapScaleFactor
        rightPosition = 5*mapScaleFactor
        
        let corpsMoveImage = UIImage.init(named: "corps_move_mark")!
        corpsMoveButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, corpsMoveImage.size.width*2*mapScaleFactor, corpsMoveImage.size.height*2*mapScaleFactor))
        corpsMoveButton.setImage(corpsMoveImage, forState: UIControlState.Normal)
        corpsMoveButton.addTarget(self, action:#selector(GameScene.corpsMoveTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(corpsMoveButton)
        
        rightPosition += corpsMoveImage.size.width*2*mapScaleFactor + 5*mapScaleFactor
        
        let corpsDetachImage = UIImage.init(named: "corps_detach_mark")!
        corpsDetachButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, corpsDetachImage.size.width*2*mapScaleFactor, corpsDetachImage.size.height*2*mapScaleFactor))
        corpsDetachButton.setImage(corpsDetachImage, forState: UIControlState.Normal)
        corpsDetachButton.addTarget(self, action:#selector(GameScene.corpsDetachTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(corpsDetachButton)
        
        rightPosition += corpsDetachImage.size.width*2*mapScaleFactor + 5*mapScaleFactor
        
        let corpsAttachImage = UIImage.init(named: "corps_attach_mark")!
        corpsAttachButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, corpsAttachImage.size.width*mapScaleFactor, corpsAttachImage.size.height*mapScaleFactor))
        corpsAttachButton.setImage(corpsAttachImage, forState: UIControlState.Normal)
        corpsAttachButton.addTarget(self, action:#selector(GameScene.corpsAttachTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(corpsAttachButton)
        
        rightPosition += corpsAttachImage.size.width*mapScaleFactor + 5*mapScaleFactor
        
        let independentImage = UIImage.init(named: "independent_mark")!
        independentButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, independentImage.size.width*mapScaleFactor, independentImage.size.height*mapScaleFactor))
        independentButton.setImage(independentImage, forState: UIControlState.Normal)
        independentButton.addTarget(self, action:#selector(GameScene.independentMoveTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(independentButton)
        
        topPosition += independentImage.size.height*mapScaleFactor + 10*mapScaleFactor
        rightPosition = 5*mapScaleFactor
        
        let retreatImage = UIImage.init(named: "AustrianFlag")!
        retreatButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, retreatImage.size.width*2*mapScaleFactor, retreatImage.size.height*2*mapScaleFactor))
        retreatButton.setImage(retreatImage, forState: UIControlState.Normal)
        retreatButton.addTarget(self, action:#selector(GameScene.retreatTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(retreatButton)
        
        rightPosition = retreatImage.size.width*2*mapScaleFactor + 10*mapScaleFactor
        
        let commitImage = UIImage.init(named: "Commit")!
        commitButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, commitImage.size.width*2*mapScaleFactor, commitImage.size.height*2*mapScaleFactor))
        commitButton.setImage(commitImage, forState: UIControlState.Normal)
        commitButton.addTarget(self, action:#selector(GameScene.commitTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(commitButton)
        
        topPosition += commitImage.size.height*2*mapScaleFactor + 10*mapScaleFactor
        rightPosition = 5*mapScaleFactor
        
        let guardAttackImage = UIImage.init(named: "FRINFEL3")!
        guardButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, guardAttackImage.size.width*mapScaleFactor, guardAttackImage.size.height*mapScaleFactor))
        guardButton.setImage(guardAttackImage, forState: UIControlState.Normal)
        guardButton.addTarget(self, action:#selector(GameScene.guardAttackTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(guardButton)
        
        topPosition += guardAttackImage.size.height*mapScaleFactor + 10*mapScaleFactor
        
        let repeatAttackImage = UIImage.init(named: "Vandamme")!
        repeatAttackButton = UIStateButton.init(initialState: .Off, theRect: CGRectMake(rightPosition, topPosition, repeatAttackImage.size.width*mapScaleFactor, repeatAttackImage.size.height*mapScaleFactor))
        repeatAttackButton.setImage(repeatAttackImage, forState: UIControlState.Normal)
        repeatAttackButton.addTarget(self, action:#selector(GameScene.repeatAttackTrigger) , forControlEvents: UIControlEvents.TouchUpInside)
        baseMenu.addSubview(repeatAttackButton)
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
    
    // MARK: Menu functions
    
    func hideTerrainTrigger() {
        
        if disableTouches || aiThinking || aiTurn {return}
        
        if terrainButton.buttonState == .Normal {
            terrainButton.buttonState = .On
            HideAllCommands(true)
            HideAllOrderArrows(true)
            TempHideAllRevealedLocations(true)
            HideAllSelectors(true)
        } else {
            terrainButton.buttonState = .Normal
            HideAllCommands(false)
            HideAllOrderArrows(false)
            TempHideAllRevealedLocations(false)
            HideAllSelectors(false)
        }
    }
    
    func fastFwdTrigger() {
    
        if terrainButton.buttonState == .On || undoOrAct || disableTouches || aiThinking || aiTurn {return}
        
        if statePoint == .Middle {
        
            // Remove order arrows from previous turn
            if manager!.orderHistoryIndex > 1 && manager!.orderHistory[manager!.orderHistoryIndex-1] != nil {
                for eachOrder in manager!.orderHistory[manager!.orderHistoryIndex-1]! {eachOrder.orderArrow?.removeFromParent()}
            }
            
            disableTouches = true
            selectedStatePoint = .Front
            
        } else if statePoint == .Back {
            
            disableTouches = true
            selectedStatePoint = .Middle
        }
    }
    
    func rewindTrigger() {
        
        if terrainButton.buttonState == .On || undoOrAct || disableTouches || aiThinking || aiTurn {return}
        
        // Rewind to the end of the current turn
        if statePoint == .Front {

            for var rewindIndex = manager!.orders.endIndex-1; rewindIndex >= 0; rewindIndex -= 1 {
                manager!.orders[rewindIndex].ExecuteOrder(true, playback: true)
            }
                
            selectedStatePoint = .Middle
            statePoint = .Middle
        
        } else if statePoint == .Middle && manager!.orderHistoryIndex > 1 && manager!.orderHistory[manager!.orderHistoryIndex-1] != nil { // Not the first turn and exists orders in the previous turn
        
            let historicalOrders = manager!.orderHistory[manager!.orderHistoryIndex-1]!
            undoOrAct = false
            
            for var rewindIndex = historicalOrders.endIndex-1; rewindIndex >= 0; rewindIndex -= 1 {
                historicalOrders[rewindIndex].ExecuteOrder(true, playback: true)
            }
            
            selectedStatePoint = .Back
            statePoint = .Back
        }
    }
    
    // Do nothing functions
    func corpsMoveTrigger() {
        
    }
    
    func corpsAttachTrigger() {
        
    }
    
    func corpsDetachTrigger() {
        
        if statePoint != .Front || undoOrAct || terrainButton.buttonState == .On || disableTouches || aiThinking || aiTurn {return}
        
        if corpsDetachButton.buttonState == .Option {
            
            corpsDetachButton.buttonState = .On
            independentButton.buttonState = .Option
            
            if manager!.phaseNew == .Move || manager!.phaseNew == .Commit {
                ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
                MoveOrdersAvailable(false)
            }
        }
    }
    
    func independentMoveTrigger() {
        
        if statePoint != .Front || undoOrAct || terrainButton.buttonState == .On || disableTouches || aiThinking || aiTurn {return}
    
        if independentButton.buttonState == .Option {
            corpsDetachButton.buttonState = .Option
            independentButton.buttonState = .On
            
            if manager!.phaseNew == .Move || manager!.phaseNew == .Commit {
                ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: false, otherSelectors: false)
                MoveOrdersAvailable(false)
            }
        }
    }
    
    func retreatTrigger() {
        
        if statePoint != .Front || (activeConflict != nil && activeConflict!.defenseApproach.approachSelector!.selected == .On) || undoOrAct || terrainButton.buttonState == .On || manager!.phaseNew != .RetreatOrDefenseSelection || disableTouches || aiThinking || aiTurn {return}
        
        var allUnitsSelectable = false
        let alreadySelected = manager!.groupsSelected
        ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: false, otherSelectors: false)
    
        // In retreat mode, not flagged as must retreat, no reductions made
        if activeGroupConflict!.retreatMode && !activeGroupConflict!.mustRetreat {
            
            activeGroupConflict!.retreatMode = false
            
            retreatButton.buttonState = .Possible
            endTurnButton.buttonState = .Off
            
            manager!.groupsSelectable = SelectableGroupsForDefense(activeConflict!)
        
        // In defend mode, not flagged as must defend
        } else if !activeGroupConflict!.retreatMode && !activeGroupConflict!.mustDefend {
            
            activeGroupConflict!.retreatMode = true
            
            retreatButton.buttonState = .Option
            endTurnButton.buttonState = .Off
 
            manager!.groupsSelectable = SelectableGroupsForRetreat(activeConflict!)
            
            // Code to see if all units selected are within the selectable group
            allUnitsSelectable = true
            /*
            for eachGroup in alreadySelected {
                let matchingUnitsRequired = eachGroup.units.count
                var matchingUnits = 0
                for eachGroupSelected in manager!.groupsSelectable {
                    let inCommon = Array(Set(eachGroup.units).intersect(Set(eachGroupSelected.units)))
                    matchingUnits += inCommon.count
                }
                if matchingUnits != matchingUnitsRequired {allUnitsSelectable = false}
            }
            */
        }
        
        ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
        if allUnitsSelectable {
            manager!.groupsSelected = alreadySelected
            ToggleGroups(manager!.groupsSelected, makeSelection: .Selected)
            retreatButton.buttonState = CheckRetreatViable(manager!.groupsSelected)
        }
    }
    
    func commitTrigger() {
        
        if statePoint != .Front || undoOrAct || terrainButton.buttonState == .On || manager!.phaseNew != .PreRetreatOrFeintMoveOrAttackDeclare || disableTouches || aiThinking || aiTurn {return}
    
        if commitButton.buttonState == .Option {
            commitButton.buttonState = .On
            
            let newOrder = Order(passedConflict: activeConflict!, orderFromView: .ConfirmAttack)
            newOrder.ExecuteOrder()
            manager!.orders += [newOrder]
        }
        
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
        
    }
    
    func guardAttackTrigger() {
        
        if statePoint != .Front || undoOrAct || terrainButton.buttonState == .On || !(manager!.phaseNew == .Move || manager!.phaseNew == .Commit) || disableTouches || aiThinking {return}
        
        if guardButton.buttonState == .Option {guardButton.buttonState = .On}
        else if guardButton.buttonState == .On {guardButton.buttonState = .Option}
        MoveOrdersAvailable()
        
    }
    
    func repeatAttackTrigger() {
        
        if statePoint != .Front || undoOrAct || terrainButton.buttonState == .On || !(manager!.phaseNew == .Move || manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare) || disableTouches || aiThinking || aiTurn {return}
        
        if repeatAttackButton.buttonState == .On {
            repeatAttackButton.buttonState = .Off
            
            let newOrder = Order(groupFromView: manager!.groupsSelected[0], orderFromView: .RepeatMove)
            newOrder.ExecuteOrder()
            manager!.orders += [newOrder]
        }
        MoveOrdersAvailable()
    }
    
    // MARK: End Turn
    
    func endTurnTrigger() {
        
        if endTurnButton.buttonState == .Off || statePoint != .Front || terrainButton.buttonState == .On || disableTouches || aiThinking {return}
        //if undoOrAct && !(endTurnButton.buttonState == .On && manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare) {}
        
        // AI finished actions case
        if !manager!.HumanPlayer(manager!.actingPlayer) {
            aiTurn = false
            if manager!.phaseNew == .Setup || manager!.phaseNew == .Move {
                manager!.NewTurn()
            } else {
                manager!.NewPhase()
            }
            return
        }
        
        switch (manager!.phaseNew) {
            
        // Pre-game phase
        case .Setup, .Move:
            
            undoOrAct = false
            manager!.NewTurn()
            
        // Finished assigning threats
        case .Commit, .FeintResponse, .PostCombatRetreatAndVictoryResponseMoves:
            
            if activeConflict != nil {ResetActiveConflict(activeConflict!)}
            ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: true, otherSelectors: true)
            undoOrAct = false
            manager!.NewPhase()
            
        // Defender confirming their leading units
        case .RetreatOrDefenseSelection, .SelectDefenseLeading, .SelectAttackLeading, .SelectCounterGroup, .PreRetreatOrFeintMoveOrAttackDeclare, .SelectAttackGroup:
        
            var theOrder:OrderType?
            
            switch manager!.phaseNew {
                case .RetreatOrDefenseSelection: theOrder = .Defend
                case .SelectDefenseLeading: theOrder = .LeadingDefense
                case .SelectAttackLeading: theOrder = .LeadingAttack
                case .SelectCounterGroup: theOrder = .LeadingCounterAttack
                case .SelectAttackGroup: theOrder = .AttackGroupDeclare

                default: break
            }
            
            // Selected for that conflict
            if endTurnButton.buttonState == .Option {
                
                let newOrder = Order(passedConflict: activeConflict!, orderFromView: theOrder!)
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
                
                // Reset status
                let theLeading = GroupSelection(theGroups: manager!.groupsSelectable)
                ToggleGroups(manager!.groupsSelectable, makeSelection: .NotSelectable)
                ToggleGroups(theLeading.groups, makeSelection: .Selected)

                activeConflict!.defenseApproach.approachSelector!.selected = .On
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
  
            // End of phase
            } else if endTurnButton.buttonState == .On {
                
                if activeConflict != nil {ResetActiveConflict(activeConflict!)}
                ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                undoOrAct = false
                manager!.NewPhase()
            }
            
        default: break // PreSetup state
        }
    }

    // MARK: Undo
    
    func undoTrigger() {
        
        if statePoint != .Front || terrainButton.buttonState == .On || disableTouches || aiThinking || aiTurn {return}
        
        // Ensures there are orders to undo and that we aren't in locked mode
        if (manager!.orders.count > 0 && manager!.orders.last!.unDoable) {
            
            let theOrder = manager!.orders.last!
            
            switch (manager!.phaseNew) {
                
            case .Move, .Setup:
                
                undoOrAct = theOrder.ExecuteOrder(true)
                ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
                manager!.groupsSelected = [theOrder.baseGroup!]
                ToggleGroups(manager!.groupsSelected, makeSelection: .Selected)

                let realMoveNumber = theOrder.baseGroup!.command.moveNumber - theOrder.baseGroup!.command.repeatMoveNumber
                
                if undoOrAct || realMoveNumber > 0 {
                    ResetState(false, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                    
                    MoveOrdersAvailable()
                } else {
                    ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                }
                
            case .Commit:
                
                theOrder.ExecuteOrder(true)
                ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                
                if manager!.orders.count == 1 || manager!.orders[manager!.orders.endIndex-2].order! != .Threat {
                    manager!.NewPhase(true, playback: false)
                }
                
            case .RetreatOrDefenseSelection:
                
                theOrder.ExecuteOrder(true, playback: false)
                ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                
                theOrder.theConflict!.defenseApproach.approachSelector!.selected = .Option
                ResetActiveConflict(theOrder.theConflict!)
                activeConflict = theOrder.theConflict!
                SetupActiveConflict()
                
                if activeConflict!.guardAttack {guardButton.buttonState = .On} else {guardButton.buttonState = .Off}
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
                
            case .SelectDefenseLeading, .SelectAttackLeading, .SelectCounterGroup, .SelectAttackGroup:
                
                theOrder.ExecuteOrder(true, playback: false)
                ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)

                theOrder.theConflict!.defenseApproach.approachSelector!.selected = .Option
                ResetActiveConflict(theOrder.theConflict!)
                activeConflict = theOrder.theConflict!
                SetupActiveConflict()

                if activeConflict!.guardAttack {guardButton.buttonState = .On} else {guardButton.buttonState = .Off}
                if manager!.phaseNew == .SelectAttackGroup {endTurnButton.buttonState = .Off} else {endTurnButton.buttonState = .Option}
                
            case .PreRetreatOrFeintMoveOrAttackDeclare:
            
                switch theOrder.order! {
                    
                case .Move:

                    theOrder.ExecuteOrder(true)
                    ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)

                    let moveFromBase = theOrder.baseGroup!.command.moveNumber - theOrder.baseGroup!.command.repeatMoveNumber
                    
                    theOrder.theConflict!.defenseApproach.approachSelector!.selected = .Option
                    RevealLocation(theOrder.theConflict!.defenseApproach, toReveal: true)
                    
                    if activeConflict != nil {ResetActiveConflict(activeConflict!)}
                    activeConflict = theOrder.theConflict!
                    SetupActiveConflict()
                    
                    if moveFromBase > 0 {

                        if theOrder.endLocation.locationType == .Approach {
                            theOrder.theConflict!.defenseApproach.approachSelector!.selected = .On
                        }
                        
                        manager!.groupsSelected = [theOrder.baseGroup!]
                        ToggleGroups(manager!.groupsSelected, makeSelection: .Selected)
                        
                        undoOrAct = true
                        AttackOrdersAvailable()

                    } else {

                        undoOrAct = false

                    }
                    if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
                    
                case .ConfirmAttack:
                    
                    theOrder.theConflict!.defenseApproach.approachSelector!.selected = .Option
                    ResetActiveConflict(theOrder.theConflict!)
                    activeConflict = theOrder.theConflict!
                    SetupActiveConflict()

                    endTurnButton.buttonState = .Off
                    commitButton.buttonState = .Option
                
                default: break
                    
                }
                
            case .FeintResponse, .PostCombatRetreatAndVictoryResponseMoves:
                
                theOrder.ExecuteOrder(true, playback: false)
                ResetState(true, groupsSelectable: false, hideRevealed: true, orderSelectors: true, otherSelectors: true)
                
                theOrder.theConflict!.defenseApproach.approachSelector!.selected = .Option
                ResetActiveConflict(theOrder.theConflict!)
                activeConflict = theOrder.theConflict!
                SetupActiveConflict()
                
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On}
                else {endTurnButton.buttonState = .Off}
                
            default: break // PreGame phase
            }
            manager!.orders.removeLast()
        }
    }
}

// MARK: Support (Hiding)

func HideAllCommands (hide:Bool) {
    
    for each in (manager!.gameCommands[manager!.actingPlayer]! + manager!.gameCommands[manager!.actingPlayer.Other()!]!) {each.hidden = hide}
}

func RevealLocation(toStore:SKNode, toReveal:Bool = true) {
    
    if aiThinking || aiTurn {return}
    
    if toReveal {
        if manager!.hiddenLocations.contains(toStore) {
            toStore.hidden = false
            manager!.revealedLocations += [toStore]
            manager!.hiddenLocations.removeObject(toStore)
        }
        
    } else {
        if manager!.revealedLocations.contains(toStore) {
            toStore.hidden = true
            manager!.hiddenLocations += [toStore]
            manager!.revealedLocations.removeObject(toStore)
        }
    }
}

func HideAllRevealedLocations(hide:Bool = true) {
    
    if hide {
        for eachNode in Set(manager!.revealedLocations).subtract(Set(manager!.staticLocations)) {
            eachNode.hidden = true
            manager!.hiddenLocations += [eachNode]
            eachNode.zPosition = 200
        }
        manager!.revealedLocations = manager!.staticLocations
    } else {
        for eachNode in manager!.hiddenLocations {
            eachNode.hidden = false
            manager!.revealedLocations += [eachNode]
        }
        manager!.hiddenLocations = []
    }
}

func HideAllLocations(hide:Bool) {
    
    manager!.revealedLocations = []
    manager!.hiddenLocations = []
    manager!.staticLocations = []
    for each in manager!.reserves as [SKNode] + manager!.approaches as [SKNode] {
        each.hidden = hide
        if hide {
            manager!.hiddenLocations += [each]
        } else {
            manager!.revealedLocations += [each]
        }
    }
}

func TempHideAllRevealedLocations(hide:Bool) {
    
    for each in manager!.revealedLocations {each.hidden = hide}
}

func HideAllOrderArrows (hide:Bool) {
    
    for eachOrder in manager!.orders {if eachOrder.orderArrow != nil {eachOrder.orderArrow!.hidden = hide}}
    
}

func HideAllSelectors (hide:Bool) {
    
    for eachApproach in manager!.approaches {eachApproach.approachSelector!.selectionBox?.hidden = hide}
    
}

// MARK: Support (Other)

func ResetState(groupselected:Bool = false, groupsSelectable:Bool = false, hideRevealed:Bool = false, orderSelectors:Bool = false, otherSelectors: Bool = false) {
    
    if groupselected {
        ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
        manager!.groupsSelected = []
    }
    if groupsSelectable {
        ToggleGroups(manager!.groupsSelectable, makeSelection: .NotSelectable)
        manager!.groupsSelectable = []
    }
    if hideRevealed {HideAllRevealedLocations()}
    if orderSelectors {
        (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState) = (.Off, .Off, .Off, .Off)
    }
    if otherSelectors {
        (guardButton.buttonState, retreatButton.buttonState, commitButton.buttonState, repeatAttackButton.buttonState) = (.Off, .Off, .Off, .Off)
    }
}

func ReturnMoveType () -> MoveType {
    if corpsMoveButton.buttonState == .On {return .CorpsMove}
    else if corpsDetachButton.buttonState  == .On {return .CorpsDetach}
    else if independentButton.buttonState == .On {return .IndMove}
    else if manager!.phaseNew == .Setup {return .CorpsMove}
    else {return .None}
}