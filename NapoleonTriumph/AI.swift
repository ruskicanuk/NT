//
//  AI.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-10-22.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

/*

Rule Changes:
(1) Simultaneous battles [print game: reveal viable threat]
(2) Cannot Rd-attack with 2+ corps (ie. if defender defends then only 1-block cav can rd-feint)
(3) If defender retreats b4 combat, attacker moves as if there is no defender was there - eg. a 2+ corps with all inf could rd-move into the battle area as long as other restrictions were restricted (adjacent 2+ enemy corps for instance) (in print game must show that had capacity to threaten a stalwart defender)

*/

/*

***Strategic Goals***

OUTPUT:
-Reduce morale
-Preserve morale
-Capture stars
-Defend stars
-Organized advance
-Organized defense

INPUT:
-Game turn
-Morale

***Attributes***

OUTPUT:
-Commands (size, narrow/wide inf attack, cav attack, art attack, defense, counter)
-Battle lines (line nodes, node exposure)
-Stars (ownership, distance, supply path
-Opportunistic locales (non cav exposed to retreat, losing a battle or a feint)

INPUT:
-Commands
-Stars

***Roles***

OUTPUT:
-Harasser
-Screener
-Goal
-Support
-Organize

INPUT:
-Strategic goals
-Attributes

***Assignments***

OUTPUT:
-Move
-Attack
-Attach
-Hold
-Act priority
-Move priority

INPUT:
-Strategic goals
-Roles

***Order***

OUTPUT:
-Command/Unit to

INPUT:
-Assignments

***Battle***

OUTPUT:
-Feint/real (Attacker)
-Feint response (Defender)

INPUT:
-Assignments

*/

import SpriteKit

// MARK: Auto AI

func SelectLeadingUnits(theConflict:Conflict) {
    
    var selectionsAvailable = true
    var attackLeadingArtPossible = false

    repeat {
        
        let (_, selectable) = SelectableLeadingGroups(theConflict, thePhase: manager!.phaseNew)
        let unitsRemaining = SelectableUnits(selectable)
    
        if unitsRemaining.isEmpty {selectionsAvailable = false}
            
        else {
            
            // Check if artillery is possible
            var count = 0
            if count == 0 && (manager!.phaseNew == .SelectAttackLeading) && (unitsRemaining[0].parentCommand!.currentLocation == theConflict.attackApproach) && theConflict.attackMoveType != .CorpsMove && (theConflict.attackApproach.turnOfLastArtVolley < manager!.turn - 1 || (theConflict.attackApproach.hillApproach && !theConflict.defenseApproach.hillApproach)) && theConflict.defenseApproach.mayArtAttack {attackLeadingArtPossible = true}
            count++
            
            let unitPriority = manager!.priorityLeaderAndBattle[manager!.actingPlayer]!
            
            switch (theConflict.wideBattle, theConflict.approachConflict, manager!.phaseNew) {
    
            case (true, false, .SelectDefenseLeading): // Defenders in reserve, wide (same type, same corps, guard = inf)
            
                var theFinalInf:[Command:[Unit]] = [:]
                var theFinalCav:[Command:[Unit]] = [:]
                
                for eachUnit in unitsRemaining {
                    
                    if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) || eachUnit.unitType == .Grd {
    
                        if theFinalInf[eachUnit.parentCommand!] == nil {
                            theFinalInf[eachUnit.parentCommand!] = [eachUnit]
                        } else {
                            theFinalInf[eachUnit.parentCommand!] = theFinalInf[eachUnit.parentCommand!]! + [eachUnit]
                        }
                    
                    } else if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 {
                        
                        if theFinalCav[eachUnit.parentCommand!] == nil {
                            theFinalCav[eachUnit.parentCommand!] = [eachUnit]
                        } else {
                            theFinalCav[eachUnit.parentCommand!] = theFinalCav[eachUnit.parentCommand!]! + [eachUnit]
                        }
                    }
                    
                }
    
                var theLargestPair = 0
                var overideUnitPriority:[Unit] = []
                for (_, eachUnitArray) in theFinalInf {
                    if eachUnitArray.count > 1 {
                        let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}.sort{$0.unitType == .Inf && $1.unitType == .Grd}
                        let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                        if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                    }
                }
                for (_, eachUnitArray) in theFinalCav {
                    if eachUnitArray.count > 1 {
                        let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                        let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                        if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                    }
                }
                
                if overideUnitPriority == [] {
                    let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                    if unitToSelect != nil {unitToSelect?.selected = .Selected} else {selectionsAvailable = false}
                } else {
                    overideUnitPriority[0].selected = .Selected
                    overideUnitPriority[1].selected = .Selected
                }
    
            case (true, _, .SelectAttackLeading): // Attackers, wide (same type, guard != inf)
                
            var theFinalInf:[Unit] = []
            var theFinalGrd:[Unit] = []
            var theFinalCav:[Unit] = []
            var flagArt = false
            
            for eachUnit in unitsRemaining {
                
                if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) {theFinalInf += [eachUnit]}
                else if eachUnit.unitType == .Grd {theFinalGrd += [eachUnit]}
                else if (eachUnit.unitType == .Cav && eachUnit.unitStrength > 1) {theFinalCav += [eachUnit]}
                else if eachUnit.unitType == .Art && attackLeadingArtPossible {
                    eachUnit.selected = .Selected
                    flagArt = true
                    break
                }
            }
            if flagArt {break}
    
            var theLargestPair = 0
            var overideUnitPriority:[Unit] = []

            if theFinalInf.count > 1 {
                let theComparisonArray = theFinalInf.sort{$0.unitStrength > $1.unitStrength}
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            if theFinalGrd.count > 1 {
                let theComparisonArray = theFinalGrd
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            if theFinalCav.count > 1 {
                let theComparisonArray = theFinalCav.sort{$0.unitStrength > $1.unitStrength}
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            
            if overideUnitPriority == [] {
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                if unitToSelect != nil {unitToSelect?.selected = .Selected} else {selectionsAvailable = false}
            } else {
                overideUnitPriority[0].selected = .Selected
                overideUnitPriority[1].selected = .Selected
            }
            
            case (_, _, .SelectCounterGroup): // Counter-attackers, all situations (same type, same corps, guard != inf)
                
            var theFinalInf:[Command:[Unit]] = [:]
            var theFinalGrd:[Command:[Unit]] = [:]
            var theFinalCav:[Command:[Unit]] = [:]
            
            for eachUnit in unitsRemaining {
                
                if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) && theConflict.conflictInitialWinner == theConflict.defenseSide.Other()! {
                    
                    if theFinalInf[eachUnit.parentCommand!] == nil {
                        theFinalInf[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalInf[eachUnit.parentCommand!] = theFinalInf[eachUnit.parentCommand!]! + [eachUnit]
                    }
                    
                } else if eachUnit.unitType == .Grd && theConflict.conflictInitialWinner == theConflict.defenseSide.Other()! {
                    
                    if theFinalGrd[eachUnit.parentCommand!] == nil {
                        theFinalGrd[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalGrd[eachUnit.parentCommand!] = theFinalGrd[eachUnit.parentCommand!]! + [eachUnit]
                    }
                    
                } else if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 && theConflict.conflictInitialWinner != .Neutral {
                    
                    if theFinalCav[eachUnit.parentCommand!] == nil {
                        theFinalCav[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalCav[eachUnit.parentCommand!] = theFinalCav[eachUnit.parentCommand!]! + [eachUnit]
                    }
                }
            }
            
            var theLargestPair = 0
            var overideUnitPriority:[Unit] = []
            for (_, eachUnitArray) in theFinalInf {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            for (_, eachUnitArray) in theFinalGrd {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            for (_, eachUnitArray) in theFinalCav {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            
            if overideUnitPriority == [] {
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                if unitToSelect != nil {unitToSelect?.selected = .Selected} else {selectionsAvailable = false}
    
            } else {
                overideUnitPriority[0].selected = .Selected
                overideUnitPriority[1].selected = .Selected
            }
                
            case (false, false, .SelectDefenseLeading), (_, true, .SelectDefenseLeading), (false, _, .SelectAttackLeading): // Defenders in reserve, narrow (simple priority), Defenders in approach, any (simple priority), Attackers, narrow (simple priority)
                
                var flagArt = false
                
                // Selects artillery if its in the group
                if manager!.phaseNew == .SelectAttackLeading && attackLeadingArtPossible {
                    for eachUnit in unitsRemaining {
                        if eachUnit.unitType == .Art {
                            eachUnit.selected = .Selected
                            flagArt = true
                            break
                        }
                    }
                }
                if flagArt {break}
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                if unitToSelect != nil {unitToSelect?.selected = .Selected} else {selectionsAvailable = false}
             
            default: break
                
            }
    
        }
    
    } while selectionsAvailable
    
    (manager!.groupsSelected, manager!.groupsSelectable) = SelectableLeadingGroups(theConflict, thePhase: manager!.phaseNew)
}

// MARK: AI Engine

class AI {
    
    // Overall Strategic Objective
    enum StrategicGoal {case ReduceMorale, PreserveMorale, CaptureStars, DefendStars, LineManeuvers}
    
    // Role for each individual group
    enum GroupRole {case Harasser, Screener, StrategicGoal, Support, Organize}

    var aiLocales:[AILocale] = []
    
    var aiGroups:[AIGroup] = [] // Groups with stored orders
    var aiCommands:[AICommand] = [] // Commands with a specified role
    var enemyCommands:[Command] = [] // Enemy commands (no role required)
    
    // Attributes
    var aiAdjToEnemyCommands:[Command] = []
    var aiRdAttackPossibleCommands:[Command] = []
    var aiNoAttackPossibleCommands:[Command] = []
    
    var aiInfAttackStrength:[Command:Int] = [:]
    var aiCavAttackStrength:[Command:Int] = [:]
    var aiArtAttackStrength:[Command:Int] = [:]
    var aiGrdAttackStrength:[Command:Int] = [:]
    
    
    let side:Allegience
    var armyGoal:StrategicGoal?
    var aiGroupRoles:[Group:GroupRole] = [:]
    var ownArmyStrength:Int = 0
    var enemyArmyStrength:Int = 0
    
    // Stars
    //var proximateStars
    //var defendedStars
    
    // Lines
    // Use pre-defined lines based on game condition and side
    
    //var relativeMorale:Int
    
    init(passedSide:Allegience) {
        side = passedSide

    }
    
    func processAITurnStrategy() {
        
        // Identify commands for both sides
        aiUpdateCommands()

        // Initialize the locales
        aiLocales = []
        for eachReserve in manager!.reserves {
            let newAILocale = AILocale(passedReserve: eachReserve)
            aiLocales += [newAILocale]
        }
        refreshLocaleThreats()
        
        // Establish army goal
        aiUpdateStrategicGoal()
        
        // Establish group roles
        //aiUpdateGroupRoles()
        
        // Establish group orders and move priority
        //aiUpdateGroupOrders()
    }
    
    func aiUpdateStrategicGoal() {
        
        switch (manager!.frReinforcementsCalled, side) {
            
        case (true, .Austrian): armyGoal = .ReduceMorale
            
        case (false, .Austrian): armyGoal = .ReduceMorale
            
        case (true, .French): armyGoal = .ReduceMorale
            
        case (false, .French): armyGoal = .ReduceMorale
            
        default: break
             
        }
    }
    
    func aiUpdateAttributes() {
        
        // Army Strength
        for eachCommand in aiCommands {
            ownArmyStrength += eachCommand.aiCommand.unitsTotalStrength
        }
        for eachCommand in enemyCommands {
            enemyArmyStrength += eachCommand.unitsTotalStrength
        }
        
        // Code for finding opportunities to win battles, force retreats, etc
    }
    
    func aiUpdateCommandRoles() {
        
        for eachCommand in aiCommands {
            
            switch (armyGoal!, side) {
                
            case (.ReduceMorale, .Austrian): break
                
            case (.ReduceMorale, .French): break
                
            case (.PreserveMorale, _): break
                
            case (.CaptureStars, .Austrian): break
                
            case (.DefendStars, .Austrian): break
                
            case (.CaptureStars, .French): break
                
            case (.DefendStars, .French): break
                
            case (.LineManeuvers, .Austrian): break
                
            case (.LineManeuvers, .French): break
                
            default: break
                
            }
        }
    }
    
    func GroupRoles(theCommand:Command) {
        
    }
    
    func aiUpdateStrategicLine() {
        
        switch (manager!.frReinforcementsCalled, side) {
            
        case (true, .Austrian): break
            
        case (false, .Austrian): break
            
        case (true, .French): break
            
        case (false, .French): break
            
        default: break
            
        }
    }
    
    func aiGroupAssignments() {
        
    }
    
    func aiUpdateCommands() {
        
        aiCommands = []
        for eachCommand in manager!.gameCommands[side]! {
            let newAICommand = AICommand(passedCommand: eachCommand)
            aiCommands += [newAICommand]
        }
        enemyCommands = manager!.gameCommands[side.Other()!]!
    }
    
    // Returns the supply paths possible between the star-location and
    func SupplyPaths() {
        
    }
    
    func refreshLocaleThreats() {
        // Refresh the AI Locales
        for localeAI in aiLocales {
            localeAI.updateCurrentThreats()
            localeAI.updateNextTurnThreats()
        }
    }
    
    func setupAIGroups() {
        
        // Create new AI Commands
        for eachCommand in aiCommands {
            if eachCommand.aiCommand.currentLocationType == .Start {continue}
            let newAIGroup = AIGroup(passedUnits: eachCommand.aiCommand.activeUnits)
            aiGroups += [newAIGroup]
            newAIGroup.updateCurrentThreats(newAIGroup.aiCommand)
        }
    }
    
    // Process AI thinking, returns false if no action taken (time to end AI's turn), returns true if action taken which means more thinking will be done
    func AIEngine() -> Bool {

        switch manager!.phaseNew {
            
        case .Setup: return false
        
        case .Move:
            
            for eachAIGroup in aiGroups {
                if eachAIGroup.group.nonLdrUnitCount == 3 && eachAIGroup.aiCommand.moveNumber < 1 {
                    manager!.groupsSelected = [eachAIGroup.group]
                    break
                }
            }
            
            if manager!.groupsSelected.count == 0 {return false}
            
            (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState) = OrdersAvailableOnMove(manager!.groupsSelected[0], ordersLeft: ((manager!.corpsCommandsAvail), (manager!.indCommandsAvail)))
                
            // Setup the swipe queue for the selected command
            (adjMoves, attackThreats, mustFeintThreats) = MoveLocationsAvailable(manager!.groupsSelected[0], selectors: (corpsMoveButton.buttonState, corpsDetachButton.buttonState, corpsAttachButton.buttonState, independentButton.buttonState), undoOrAct:undoOrAct)
            
            var moveToLocation:Location?
            if adjMoves.count > 0 {
                moveToLocation = adjMoves[0]
                MoveUI(moveToLocation!)
                return true
            }
            
        default: break
            
        }
        
        return false
    }

}
