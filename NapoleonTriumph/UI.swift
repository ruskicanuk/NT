//
//  UI.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-01.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

import Foundation
import SpriteKit

// MARK: UI Orders

// Order to move (corps, detach or independent)
func MoveUI(touchedNodeFromView:SKNode) {
    
    let returnType = ReturnMoveType()
    if returnType == .None {return Void()}
    let theGroup = manager!.groupsSelected[0]
    
    // Sets up command order usage (free if already moved)
    var commandUsage:Bool?
    if manager!.phaseNew == .Setup {}
    else if theGroup.fullCommand && theGroup.command.hasMoved {}
    else if independentButton.buttonState == .On {commandUsage = false}
    else {commandUsage = true}
    
    let newOrder = Order(groupFromView: manager!.groupsSelected[0], touchedNodeFromView: touchedNodeFromView, orderFromView: .Move, corpsOrder: commandUsage, moveTypePassed: returnType)
    
    undoOrAct = newOrder.ExecuteOrder()
    manager!.orders += [newOrder]
    
    switch (manager!.phaseNew) {
        
    case .Setup: break
        
    case .Move:
        
        // Reselect (other than for detach and attach orders)
        if !newOrder.moveCommands.isEmpty && newOrder.moveCommands[0]!.count == 1 && (newOrder.moveType == .CorpsMove || newOrder.moveType == .IndMove) {
            manager!.groupsSelected = [Group(theCommand: newOrder.moveCommands[0]![0], theUnits: manager!.groupsSelected[0].units)]
            MoveOrdersAvailable()
        }
        
    case .PreRetreatOrFeintMoveOrAttackDeclare:
        
        if activeConflict == nil {break}
        
        manager!.groupsSelected = [Group(theCommand: newOrder.moveCommands[0]![0], theUnits: manager!.groupsSelected[0].units)]
        
        AttackOrdersAvailable()
        undoOrAct = true
        if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
        
    default: break
        
    }
}

// Order to threaten (may later attack or feint)
func AttackThreatUI(touchedNodeFromView:SKNode) {
    
    // Create an order, execute and deselect everything
    let newOrder = Order(groupFromView: manager!.groupsSelected[0], touchedNodeFromView: touchedNodeFromView, orderFromView: .Threat, corpsOrder: independentButton.buttonState != .On, moveTypePassed: ReturnMoveType())
    
    newOrder.ExecuteOrder()
    manager!.orders += [newOrder]
    
    if guardButton.buttonState == .On {
        newOrder.theConflict!.guardAttack = true
    }
}

// Order to retreat
func RetreatUI(touchedNodeFromView:Reserve) {
    
    if activeConflict == nil {return}
    
    let retreatSelection = GroupSelection(theGroups: manager!.groupsSelectable)
    
    let newOrder = Order(passedConflict: activeConflict!, theGroupSelection: retreatSelection, touchedReserveFromView: touchedNodeFromView, orderFromView: .Retreat)
    newOrder.ExecuteOrder()
    manager!.orders += [newOrder]
    
    // Hide the retreat reserves
    for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: false)}
    
    // Resets selectable defense group
    RetreatPreparation()
}

func DefendAgainstFeintUI(touchedNodeFromView: Location, feintSelection:GroupSelection) {
    
    let newOrder = Order(passedConflict: activeConflict!, theGroupSelection: feintSelection, touchedReserveFromView: touchedNodeFromView, orderFromView: .Feint)
    
    newOrder.ExecuteOrder()
    manager!.orders += [newOrder]
}

// Order to reduce unit strength
func ReduceUnitUI(passedGroup:Group, theGroupConflict:GroupConflict) {
    
    // Create an order
    let newOrder = Order(passedConflict: activeConflict!, theUnit: passedGroup.units[0], orderFromView: .Reduce)
    
    // Execute the order and add to order array
    newOrder.ExecuteOrder()
    manager!.orders += [newOrder]
}

// MARK: Unit Selection Functions

// Return true if you can run the MoveUnitSelection function (false if you are triggering attach command)
func MoveGroupUnitSelection(touchedUnit:Unit, touchedCount:Int) -> Bool {
    
    var sameCommand:Bool = false
    var touchedLeader:Bool = false
    var selectedUnit:Bool = false
    var unitsSelected:Bool = true
    
    var theCommand:Command!
    var theUnits:[Unit] = []
    
    // If current selection has something, set the command and units to the 1st current selection, otherwise the command is new
    if !manager!.groupsSelected.isEmpty {
        theCommand = manager!.groupsSelected[0].command
        theUnits = manager!.groupsSelected[0].units
    } else {
        let theParent = touchedUnit.parent as! Command
        theCommand = theParent
    }
    
    // If its a new command touched, check for attach or change selection
    if touchedUnit.parent != theCommand {
        sameCommand = false
        if CheckIfViableAttach(manager!.groupsSelected[0], touchedUnit: touchedUnit) && corpsAttachButton.buttonState == .On {return false}
        theCommand = touchedUnit.parentCommand
    } else if theCommand.hasLeader && theCommand.theLeader!.selected == .NotSelectable {
        sameCommand = false
    } else {
        sameCommand = true
    }
    
    if touchedUnit.selected == .NotSelectable {return true}
    if touchedUnit.unitType == .Ldr {touchedLeader = true}
    if touchedUnit.selected == .Selected {selectedUnit = true}
    if theUnits.count == 0 {unitsSelected = false}
    
    // If the command is in repeat attack mode, any touch is treated like a leader touch
    if theCommand.moveNumber > 0 && theCommand.hasLeader {touchedLeader = true}
    
    switch (touchedLeader, selectedUnit, sameCommand, unitsSelected) {
        
    case (true, _, _, _):
        
        // Leader always deselects whatever is selected then selects all in its command (including self)
        if touchedCount == 1 {
            ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
            theUnits = theCommand.units.filter{$0.selected == .Normal}
            for eachUnit in theUnits {eachUnit.selected = .Selected}
        }
        else if touchedCount == 2 {
            ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
            theUnits = [touchedUnit]
            touchedUnit.selected = .Selected
        }
        
    case (false, true, _, _):
        
        // Selected unit (toggle)
        if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        
    case (false, false, true, _):
        
        // New unit in the same group
        if selectedUnit {touchedUnit.selected = .Normal; theUnits.removeObject(touchedUnit)} else {touchedUnit.selected = .Selected; theUnits += [touchedUnit]}
        
    case (false, false, false, _):
        
        // New unit in a different group
        ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
        touchedUnit.selected = .Selected
        theUnits = [touchedUnit]
    }
    
    // Case where all but leader is selected
    if theUnits.count == theCommand.activeUnits.count - 1 && theCommand.theLeader?.selected == .Normal {theCommand.theLeader?.selected = .Selected; theUnits += [theCommand.theLeader!]}
    
    if theUnits.count > 0 {
        manager!.groupsSelected = [Group(theCommand: theCommand, theUnits: theUnits)]
    } else {
        manager!.groupsSelected = []
    }
    
    return true
}

// Sets the defense/retreat selection when a threat is made (returns the reserve area of the threat group)
func DefenseGroupUnitSelection(touchedUnit:Unit, retreatMode:Bool = false, theTouchedThreat:GroupConflict, touchedCount:Int) -> Reserve? {
    
    var theReserve:Reserve!
    
    if touchedUnit.selected == .NotSelectable || touchedUnit.selected == .Off {return nil}
    
    let parentCommand = touchedUnit.parentCommand!
    
    if parentCommand.currentLocation!.locationType == .Reserve {
        theReserve = parentCommand.currentLocation as! Reserve
    } else if parentCommand.currentLocation!.locationType == .Approach {
        theReserve = (parentCommand.currentLocation as! Approach).ownReserve
    } else {
        return nil
    }
    
    //ToggleGroups(manager!.groupsSelectable, makeSelection: .Normal)
    for eachReserve in manager!.selectionRetreatReserves {RevealLocation(eachReserve, toReveal: false)}
    activeGroupConflict = theTouchedThreat
    
    if touchedUnit.unitType == .Ldr { // Always select all if selecting the leader
        
        if let indexOfCommand = manager!.groupsSelectable.indexOf({$0.command == parentCommand}) {
            let leaderUnits:[Unit] = manager!.groupsSelectable[indexOfCommand].nonLdrUnits
            for eachUnit in leaderUnits {eachUnit.selected = .Selected} // eachUnit.zPosition = 100
            if retreatMode {touchedUnit.selected = .Selected}
            
            if touchedCount == 2 {
                for eachUnit in leaderUnits {eachUnit.selected = .Normal}
            }
        }
    }
        
    else { // Normal click mode
        
        if touchedUnit.selected == .Selected {
            
            touchedUnit.selected = .Normal
            if !retreatMode && !parentCommand.hasLeader {ActivateDetached(theReserve, theGroups: manager!.groupsSelectable, makeSelection: .Normal)}
            
        } else {
            
            if !retreatMode && !parentCommand.hasLeader {
                ActivateDetached(theReserve, theGroups: manager!.groupsSelectable, makeSelection: .NotSelectable)
            }
            touchedUnit.selected = .Selected
            
            // Select leader if its the last unselected
            if retreatMode && touchedUnit.parentCommand!.hasLeader && touchedUnit.parentCommand!.theLeader!.selected != .Selected {
                var allUnitsSelected = true
                for eachUnit in touchedUnit.parentCommand!.nonLeaderUnits {if eachUnit.selected != .Selected {allUnitsSelected = false; break}}
                if allUnitsSelected {touchedUnit.parentCommand!.theLeader!.selected = .Selected}
            }
        }
    }
    
    return theReserve
    
}

func FeintDefenseUnitSelection(touchedUnit:Unit, touchedCount: Int) {
    
    switch (touchedUnit.unitType == .Ldr, touchedUnit.selected == .Selected) {
        
    case (true, _):
        
        for eachUnit in touchedUnit.parentCommand!.activeUnits {
            if eachUnit.selected == .Normal {eachUnit.selected = .Selected}
            if touchedCount == 2 && eachUnit.unitType != .Ldr {eachUnit.selected = .Normal}
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
    if leaderStillSelected == nil && selectedCount == touchedUnit.parentCommand!.activeUnits.count - 1 { // Case of the hanging units
        touchedUnit.parentCommand!.theLeader!.selected = .Selected
    }
}

func LeadingUnitSelection(touchedUnit:Unit) {
    
    if touchedUnit.unitType == .Ldr {return}
    if touchedUnit.selected == .Selected {touchedUnit.selected = .Normal}
    else {touchedUnit.selected = .Selected}
}

// Function updates selectionGroups based on what unit is selected
func AttackGroupUnitSelection(touchedUnit:Unit!, realAttack:Bool, theTouchedThreat:Conflict, touchedCount:Int) {
    
    var leaderTouched = touchedUnit.unitType == .Ldr
    let unitAlreadySelected = touchedUnit.selected == .Selected
    
    var groupTouched:Group!
    
    var newGroupTouched:Bool = true
    for eachGroup in manager!.groupsSelected {
        if eachGroup.command == touchedUnit.parentCommand! {newGroupTouched = false; break}
    }
    
    // The selected group
    let commandtouched = touchedUnit.parentCommand!
    
    var maySelectAnotherCorps = false
    var maySelectASecondIndArt = false
    var requiredLocation:Location?
    
    groupTouched = manager!.groupsSelectable.filter{$0.command == touchedUnit.parentCommand!}[0]
    
    // Real attack, setup detection of the corner cases (art, guard and multi corps)
    if realAttack {
        
        var fullCorpsSelected = 0
        var indArtSelected = 0
        for eachGroup in manager!.groupsSelected {
            
            if eachGroup.leaderInGroup {fullCorpsSelected++}
            if eachGroup.fullCommand && eachGroup.units.count == 1 && eachGroup.units[0].unitType == .Art && eachGroup.command.currentLocation!.locationType == .Approach {indArtSelected++}
        }
        if fullCorpsSelected > 0 && fullCorpsSelected <= manager!.corpsCommandsAvail {maySelectAnotherCorps = true}
        if indArtSelected == 1 {maySelectASecondIndArt = true}
        if maySelectAnotherCorps || maySelectASecondIndArt {requiredLocation = manager!.groupsSelected[0].command.currentLocation!}
    }
    
    var theUnits:[Unit] = []
    
    // If the command is in repeat attack mode, any touch is treated like a leader touch
    if groupTouched.command.moveNumber > 0 && groupTouched.command.hasLeader {leaderTouched = true}
    
    // Feint or advance after retreat (adjacent groups + rd groups)
    switch (unitAlreadySelected, leaderTouched) {
        
    case (_, true):
        
        var newGroups:[Group] = [groupTouched!]
        
        if touchedCount == 1 {
            
            if !manager!.groupsSelected.isEmpty {
                
                for eachGroup in manager!.groupsSelected {
                    if eachGroup.command != touchedUnit.parentCommand! {
                        if eachGroup.leaderInGroup && maySelectAnotherCorps && touchedUnit.parentCommand!.currentLocation! == requiredLocation! {newGroups += [eachGroup]}
                        else {ToggleGroups([eachGroup], makeSelection: .Normal)}
                    }
                }
            }
            manager!.groupsSelected = newGroups
            
        } else if touchedCount == 2 {
            
            manager!.groupsSelected.removeObject(groupTouched)
            ToggleGroups([groupTouched], makeSelection: .Normal)
            if manager!.groupsSelected.isEmpty {
                manager!.groupsSelected = [Group(theCommand: touchedUnit.parentCommand!, theUnits: [touchedUnit])]
            } else {
                manager!.groupsSelected += [Group(theCommand: touchedUnit.parentCommand!, theUnits: [touchedUnit])]
            }
        }
        
    case (true, false):
        
        let theIndex = manager!.groupsSelected.indexOf{$0.command == touchedUnit.parentCommand!}
        
        theUnits = manager!.groupsSelected[theIndex!].units
        theUnits.removeObject(touchedUnit)
        touchedUnit.selected = .Normal
        theUnits = AdjustSelectionForLeaderRulesActiveThreat(theUnits)
        
        manager!.groupsSelected.removeAtIndex(theIndex!)
        
        if theUnits.count > 0 {
            manager!.groupsSelected += [Group(theCommand: commandtouched, theUnits: theUnits)]
        }
        
    case (false, false):
        
        // Touched an unselected unit outside the selected group
        if newGroupTouched {
            
            // 2nd Corps selection...
            if touchedUnit.parentCommand!.activeUnits.count >= 2 {
                if !maySelectAnotherCorps || touchedUnit.parentCommand!.currentLocation! != requiredLocation! {
                    ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
                    manager!.groupsSelected = []
                }
            }
            else {
                if !maySelectASecondIndArt || touchedUnit.unitType != .Art || touchedUnit.parentCommand!.currentLocation! != requiredLocation! {
                    ToggleGroups(manager!.groupsSelected, makeSelection: .Normal)
                    manager!.groupsSelected = []
                }
            }
            theUnits = [touchedUnit]
            
            // Touched an unselected unit within the selected group (can't be a two-unit corps else it would be the leader)
        } else {
            let theIndex = manager!.groupsSelected.indexOf{$0.command == touchedUnit.parentCommand!}
            theUnits = manager!.groupsSelected[theIndex!].units
            theUnits.append(touchedUnit)
            
            manager!.groupsSelected.removeAtIndex(theIndex!)
        }
        
        theUnits = AdjustSelectionForLeaderRulesActiveThreat(theUnits)
        manager!.groupsSelected += [Group(theCommand: commandtouched, theUnits: theUnits)]
    }
    ToggleGroups(manager!.groupsSelected, makeSelection: .Selected)
}

// Sets the viable moves and orders for a given selection (under move orders)
func  MoveOrdersAvailable(refreshOrders:Bool = true) {
    
    // Hide locations, check that we have a selection group then update based on what was touched
    if manager!.groupsSelected.isEmpty {return}
    
    if manager!.groupsSelected[0].command.turnEnteredMap == manager!.turn && manager!.groupsSelected[0].fullCommand && manager!.groupsSelected[0].command.moveNumber > 0 && !manager!.groupsSelected[0].command.secondMoveUsed {
        repeatAttackButton.buttonState = .On
    } else {
        repeatAttackButton.buttonState = .Off
    }
    
    // Commands available
    if refreshOrders {
        (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState) = OrdersAvailableOnMove(manager!.groupsSelected[0], ordersLeft: ((manager!.corpsCommandsAvail), (manager!.indCommandsAvail)))
    }
    
    // Setup the swipe queue for the selected command
    (adjMoves, attackThreats, mustFeintThreats) = MoveLocationsAvailable(manager!.groupsSelected[0], selectors: (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState), undoOrAct:undoOrAct)
    
    // Reveal available moves
    var possibleGuardAttack = false
    var actualGuardAttack = false
    for each in attackThreats {
        if CheckIfGuardAttackViable(manager!.groupsSelected[0], theApproach: each) {possibleGuardAttack = true}
        //each.hidden = false
    }
    if possibleGuardAttack {
        if guardButton.buttonState == .On {
            actualGuardAttack = true
            for each in attackThreats {
                if CheckIfGuardAttackViable(manager!.groupsSelected[0], theApproach: each) {RevealLocation(each)}
            }
        }
        else {
            guardButton.buttonState = .Option
            for each in attackThreats {RevealLocation(each)}
        }
    } else {
        guardButton.buttonState = .Off
        for each in attackThreats {RevealLocation(each)}
    }
    if !actualGuardAttack {
        for each in mustFeintThreats {RevealLocation(each)}
        for each in adjMoves {RevealLocation(each)}
    }
}

func AttackOrdersAvailable(setCommands:Bool = true) {
    
    if activeConflict == nil {return}
    
    if setCommands {
        // Set the commands available
        (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState) = OrdersAvailableOnAttack(manager!.groupsSelected, theConflict: activeConflict!)
    }
    
    var attackNodes:[SKNode] = []
    
    if !manager!.groupsSelected.isEmpty {
        
        if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
            
            let theGroup = manager!.groupsSelected[0]
            attackNodes = AttackMoveLocationsAvailable(theGroup, selectors: (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState), feint: !activeGroupConflict!.retreatMode, theConflict: activeConflict!, undoOrAct:undoOrAct)
            
            // Setup the swipe queue for the selected command
            for eachNode in attackNodes {RevealLocation(eachNode)}
            
        } else if manager!.phaseNew == .SelectAttackGroup {
            if activeConflict!.defenseApproach.approachSelector!.selected == .Option {
                endTurnButton.buttonState = .Option
            } else {
                if CheckEndTurnStatus() {endTurnButton.buttonState = .On} else {endTurnButton.buttonState = .Off}
            }
        }
    }
}