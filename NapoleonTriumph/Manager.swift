//
//  Manager.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-25.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

// MARK: New Phase

enum newGamePhase {
    
    case Setup, Move, Commit, RetreatOrDefenseSelection, SelectDefenseLeading, PreRetreatOrFeintMoveOrAttackDeclare, SelectAttackGroup, SelectAttackLeading, FeintResponse, SelectCounterGroup, PostCombatRetreatAndVictoryResponseMoves
    
    init (initPhase:String = "Setup") {
        switch initPhase {
        case "Setup": self = .Setup
        default: self = .Move
        }
    }
    
    // Changes the phase returns (whether to switch the acting player, whether to advance the turn)
    mutating func NextPhase (reverse:Bool = false) -> Bool {
        
        var switchActing = false
        
        if reverse {
            
            switch self {
                
            case .Commit: self = .Move
            
            case .SelectDefenseLeading: self = .RetreatOrDefenseSelection
            
            case .SelectAttackLeading: self = .SelectAttackGroup
            
            case .SelectAttackGroup: self = .PreRetreatOrFeintMoveOrAttackDeclare

            case .PostCombatRetreatAndVictoryResponseMoves: self = .SelectCounterGroup
            
            case .SelectCounterGroup: self = .FeintResponse
                
            default: break
            }
            
        } else {
            
            switch self {
                
            case .Move: self = .Commit
            
            case .Commit: self = .RetreatOrDefenseSelection; switchActing = true
            
            case .RetreatOrDefenseSelection: self = .SelectDefenseLeading
            
            case .SelectDefenseLeading: self = .PreRetreatOrFeintMoveOrAttackDeclare; switchActing = true
            
            case .PreRetreatOrFeintMoveOrAttackDeclare: self = .SelectAttackGroup
            
            case .SelectAttackGroup: self = .SelectAttackLeading
            
            case .SelectAttackLeading: self = .FeintResponse; switchActing = true
            
            case .FeintResponse: self = .SelectCounterGroup
            
            case .SelectCounterGroup: self = .PostCombatRetreatAndVictoryResponseMoves
            
            case .PostCombatRetreatAndVictoryResponseMoves: self = .Move; switchActing = true
                
            default: break
            }
        }
        
        return switchActing
    }
    
    var ID:String {
        switch self {
        case .Setup: return "Setup"
        case .Move: return "Move"
        case .Commit: return "Commit"
        case .RetreatOrDefenseSelection: return "RetreatOrDefenseSelection"
        case .SelectDefenseLeading: return "SelectDefenseLeading"
        case .PreRetreatOrFeintMoveOrAttackDeclare: return "PreRetreatOrFeintMoveOrAttackDeclare"
        case .SelectAttackGroup: return "SelectAttackGroup"
        case .SelectAttackLeading: return "SelectAttackLeading"
        case .FeintResponse: return "FeintResponse"
        case .SelectCounterGroup: return "SelectCounterGroup"
        case .PostCombatRetreatAndVictoryResponseMoves: return "PostCombatRetreatAndVictoryResponseMoves"
        }
    }
}

// MARK: Game Manager

class GameManager: NSObject, NSCoding {
    
    // MARK: Initializers

    // Loead Game Initializer
    required init(coder aDecoder: NSCoder) {

        super.init()
        
        decodeWithCoder(aDecoder)

    }
    
    // New Game Initializer
    override init() {
        
        phasingPlayer = player1
        actingPlayer = player1
        phaseNew = .Setup // ### Switch this later to .Setup, set to move for testing
        corpsCommandsAvail = 0
        indCommandsAvail = 0
        
        morale[player1] = maxMorale[player1]
        morale[player2] = maxMorale[player2]
    }
    
    // MARK: Manager Objects
    
    // Constants
    
    let player1:Allegience = .Austrian
    let player2:Allegience = .French
    
    let player1CorpsCommands:Int = 5
    let player1IndCommands:Int = 3
    // Player 2 corps commands is a variable (losing or gaining commands possible)
    let player2IndCommands:Int = 4
    
    let heavyCavCommittedCost:Int = 2
    let guardCommittedCost:Int = 4
    let guardFailedCost:Int = 3
    let frCalledReinforcementMoraleCost:Int = -4
    
    // Variables not saved
    
    var statePointTracker:ReviewState = .Front
    
    var groupsSelected:[Group] = []
    var groupsSelectable:[Group] = []
    var groupsSelectableByRd:[Group] = []
    var groupsSelectableAdjacent:[Group] = []
    var selectionRetreatReserves:[Reserve] = [] // Stores viable retreat reserves for the current selection
    
    var revealedLocations:[SKNode] = []
    var hiddenLocations:[SKNode] = []
    
    // Game Settings
    
    var scenario:Int = 1 // This is to set game to scenario 1 or 2 (December 1 or December 2)
    var gameMode:String = "Normal" // Normal = simultaneous attacks, Traditional = infinite single-threats
    var generalThreatsPossible:Int = 2
    var maxMorale:[Allegience:Int!] = [ .Austrian: 27, .French: 23]
    var multiPlayerMatch:Bool = false
    var frAI:Bool = false
    var auAI:Bool = false
    
    // Game Variables
    
    var gameCommands:[Allegience:[Command]] = [.Austrian:[], .French:[]]
    
    var priorityLosses:[Allegience:[Int]] = [.Austrian:[43, 23, 22, 21, 33, 32, 31], .French:[43, 23, 22, 21, 33, 32, 31]]
    var priorityLeaderAndBattle:[Allegience:[Int]] = [.Austrian:[33, 43, 23, 32, 22, 31, 21], .French:[33, 43, 23, 32, 22, 31, 21]]
    
    var localeThreats:[GroupConflict] = []
    var staticLocations:[SKNode] = [] // Used to store currently active conflicts
    
    var approaches = [Approach]()
    var reserves = [Reserve]()
    var orders = [Order]()
    var orderHistoryIndex:Int = 0
    var orderHistory:[Int:[Order]] = [:]
    var generalThreatsMade:Int = 0 // Stores how many general-threats have been made during the turn
    
    var phasingPlayer:Allegience = .Austrian {
        didSet {
            //if (self.phasingPlayer == player1) {orderHistoryTurn = (2*turn - 1)} else {orderHistoryTurn = 2*turn}
            updatePhasingLabel()
        }
    }

    var actingPlayer:Allegience = .Austrian {
        didSet {updateActingLabel()}
    }
    
    var day:Int = 1
    
    var turn:Int = 1 {
        didSet {
            if turn == 11 {
                
                night = true
                
                // Gain of half morale (rounded down)
                let frMoraleGain = Int((maxMorale[.French]! - morale[.French]!) / 2)
                let auMoraleGain = Int((maxMorale[.Austrian]! - morale[.Austrian]!) / 2)
                morale[.French] = morale[.French]! + frMoraleGain
                morale[.Austrian] = morale[.Austrian]! + auMoraleGain
                
            } else if night == true {night = false}
            
            if turn > 11 {day = 2} else {day = 1}
            updateTurnLabel()
        }
    }
    
    var night:Bool = false
    
    var phaseNew:newGamePhase = newGamePhase() {
        didSet {
            updateTurnLabel()
        }
    }
    
    var player2CorpsCommands:Int = 6 // French corps commands can change over time
    
    var corpsCommandsAvail:Int = 0 {
        didSet {updateCommandLabel()}
    }
    var indCommandsAvail:Int = 0 {
        didSet {updateIndLabel()}
    }
    var phantomCorpsCommand:Int = 0 {
        didSet {
            updatePhantomLabelState()
        }
    }
    var phantomIndCommand:Int = 0 {
        didSet {
            updatePhantomLabelState()
        }
    }
    
    // Morale
    var morale:[Allegience:Int] = [:] {
        didSet{updateMoraleLabel()}
    }
    
    var frReinforcementsCalled:Bool = false
    var heavyCavCommited:[Allegience:Bool] = [ .Austrian: false, .French: false]
    var guardCommitted:[Allegience:Bool] = [ .Austrian: false, .French: false]
    var guardFailed:[Allegience:Bool] = [ .Austrian: false, .French: false]
    
    // MARK: New Phase
    
    // Triggered by conflict commands (eg. moving into an enemy locale)
    func NewPhase(reverse:Bool = false, playback:Bool = false) -> String {

        var availableCount = 0
        var theSingleConflict:Conflict?
        
        // Increments phase if we aren't in play-back mode
        if playback {return "Playback"}
        let phaseChange = phaseNew.NextPhase(reverse) // Moves us to the next phase, returns true if need to swith acting player
        if phaseChange {actingPlayer.Switch()}
    
        RefreshCommands() // Switches block visibility

        switch phaseNew {
        
        case .Move:
            
            // Updates the selected status of the game commands generally after a battle and ensures 1-block corps are handled
            for eachCommand in gameCommands[actingPlayer]! {
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.updateSelectedStatus()
                }
                CheckForOneBlockCorps(eachCommand)
            }
            
            RemoveNonMovementArrows(orders)
            ResetConflictsState()
            RefreshCommands()
            endTurnButton.buttonState = .On
        
        case .Commit:
            
            endTurnButton.buttonState = .On
        
        case .RetreatOrDefenseSelection:
            
            endTurnButton.buttonState = .Off
            generalThreatsMade++
            SetupThreats()
            
            for eachLocaleConflict in localeThreats {
                for eachConflict in eachLocaleConflict.conflicts {
                    if !eachConflict.approachConflict {
                        availableCount++
                        theSingleConflict = eachConflict
                    }
                }
            }
            
        // Static: All Groups
        
        case .SelectDefenseLeading:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        RevealLocation(eachConflict.defenseApproach, toReveal: false)
                        staticLocations.removeObject(eachConflict.defenseApproach)
                        eachConflict.defenseApproach.approachSelector!.selected = .Off
                    }
                } else {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if !eachConflict.approachDefended {
                            
                            eachConflict.defenseGroup = GroupSelection(theGroups: [])
                            eachConflict.defenseLeadingUnits = GroupSelection(theGroups: [])
                            eachConflict.defenseApproach.approachSelector!.selected = .On
                            
                        } else {
                            
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            availableCount++
                            theSingleConflict = eachConflict
                        }
                    }
                }
            }

        // Static: All non-retreats
        
        case .PreRetreatOrFeintMoveOrAttackDeclare:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        RevealLocation(eachConflict.defenseApproach, toReveal: true)
                        staticLocations += [eachConflict.defenseApproach]
                        eachConflict.defenseApproach.approachSelector!.selected = .Option
                        availableCount++
                        theSingleConflict = eachConflict
                    }
                } else {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.guardAttack {
                            eachConflict.defenseApproach.approachSelector!.selected = .On
                            eachConflict.realAttack = true
                        } else if !eachConflict.approachDefended {
                            eachConflict.defenseApproach.approachSelector!.selected = .On
                        } else {
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            availableCount++
                            theSingleConflict = eachConflict
                        }
                    }
                }
            }
        
        // Static: All conflicts
        
        case .SelectAttackGroup:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        RevealLocation(eachConflict.defenseApproach, toReveal: false)
                        staticLocations.removeObject(eachConflict.defenseApproach)
                        eachConflict.defenseApproach.approachSelector!.selected = .Off
                    }
                } else {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.realAttack || !eachConflict.approachDefended {

                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            availableCount++
                            theSingleConflict = eachConflict
                        }
                        else {
                            
                            RevealLocation(eachConflict.defenseApproach, toReveal: false)
                            staticLocations.removeObject(eachConflict.defenseApproach)
                            eachConflict.defenseApproach.approachSelector!.selected = .Off
                        }
                    }
                }
            }
            
        // Static: All real attacks
        
        case .SelectAttackLeading:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if !eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.realAttack {
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            availableCount++
                            theSingleConflict = eachConflict
                        } else if !eachConflict.approachDefended {
                            eachConflict.attackLeadingUnits = GroupSelection(theGroups: [])
                            eachConflict.defenseApproach.approachSelector!.selected = .On
                        }
                    }
                }
            }
            
        // Static: All real attacks
            
        case .FeintResponse:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if !eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.realAttack || !eachConflict.approachDefended {
                            RevealLocation(eachConflict.defenseApproach, toReveal: false)
                            staticLocations.removeObject(eachConflict.defenseApproach)
                            eachConflict.defenseApproach.approachSelector!.selected = .Off
                            eachConflict.counterAttackLeadingUnits = nil
                        } else {
                            eachConflict.defenseApproach.approachSelector!.selected = .Option
                            RevealLocation(eachConflict.defenseApproach, toReveal: true)
                            staticLocations += [eachConflict.defenseApproach]
                            availableCount++
                            theSingleConflict = eachConflict
                            
                            eachConflict.defenseApproach.mayNormalAttack = false
                            eachConflict.defenseApproach.mayArtAttack = false
                        }
                    }
                }
            }
            
        // Static: All feints
        
        case .SelectCounterGroup:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if !eachLocaleConflict.retreatMode {
                    for eachConflict in eachLocaleConflict.conflicts {
                        if eachConflict.realAttack {
                            
                            InitialBattleProcessing(eachConflict)
                            RevealLocation(eachConflict.defenseApproach, toReveal: true)
                            staticLocations += [eachConflict.defenseApproach]
                            
                            // Only allow for counter-attack if its
                            if eachConflict.mayCounterAttack {
                                eachConflict.defenseApproach.approachSelector!.selected = .Option
                                availableCount++
                                theSingleConflict = eachConflict
                            } else {
                                eachConflict.counterAttackLeadingUnits = GroupSelection(theGroups: [])
                            }
                            
                        } else if !eachConflict.approachDefended {
                            
                            RevealLocation(eachConflict.defenseApproach, toReveal: true)
                            staticLocations += [eachConflict.defenseApproach]
                            InitialBattleProcessing(eachConflict)
                            eachConflict.counterAttackLeadingUnits = GroupSelection(theGroups: [])
                            
                            eachConflict.defenseApproach.approachSelector!.selected = .On
                            
                        } else {
                            RevealLocation(eachConflict.defenseApproach, toReveal: false)
                            staticLocations.removeObject(eachConflict.defenseApproach)
                            eachConflict.defenseApproach.approachSelector!.selected = .Off
                        }
                    }
                }
            }
            
        // Static: All real attacks
            
        case .PostCombatRetreatAndVictoryResponseMoves:
            
            endTurnButton.buttonState = .Off
            for eachLocaleConflict in localeThreats {
                if !eachLocaleConflict.retreatMode {
                    
                    for eachConflict in eachLocaleConflict.conflicts {
                        
                        if eachConflict.realAttack || !eachConflict.approachDefended {
                            
                            FinalBattleProcessing(eachConflict)
                        
                            if eachConflict.conflictFinalWinner == .Neutral {
                                
                                PostBattleMove(eachConflict, artAttack: true)
                                
                                RevealLocation(eachConflict.defenseApproach, toReveal: false)
                                staticLocations.removeObject(eachConflict.defenseApproach)
                                eachConflict.defenseApproach.approachSelector!.selected = .Off

                            // Defender wins
                            } else if eachConflict.conflictFinalWinner == eachConflict.defenseSide {
                                
                                ProcessDefenderWin(eachConflict)
                                
                                // Skip where defenders in the approach
                                if eachConflict.approachConflict {

                                    RevealLocation(eachConflict.defenseApproach, toReveal: false)
                                    manager!.staticLocations.removeObject(eachConflict.defenseApproach)
                                    eachConflict.defenseApproach.approachSelector!.selected = .Off
                                
                                // Skip where defenders in the approach
                                } else {
                                    
                                    // Double check that defenders remain to move into position (otherwise skip to Move)
                                    let doubleCheckExistance = GroupSelection(theGroups: eachConflict.defenseGroup!.groups, selectedOnly: false)
                                    if doubleCheckExistance.groupSelectionStrength <= 0 {
                                        RevealLocation(eachConflict.defenseApproach, toReveal: false)
                                        manager!.staticLocations.removeObject(eachConflict.defenseApproach)
                                        eachConflict.defenseApproach.approachSelector!.selected = .Off
                                    } else {
                                        availableCount++
                                        theSingleConflict = eachConflict
                                        eachConflict.defenseApproach.approachSelector!.selected = .Option
                                    }
                                }
                                
                            // Attacker wins
                            } else {
                                
                                if eachConflict.approachDefended {eachConflict.parentGroupConflict!.someEmbattledAttackersWon = true}
                                
                                eachConflict.parentGroupConflict!.retreatMode = true
                                eachConflict.parentGroupConflict!.mustRetreat = true
                                eachConflict.parentGroupConflict!.mustDefend = false
                                
                                eachConflict.defenseApproach.approachSelector!.selected = .Option
                                availableCount++
                                theSingleConflict = eachConflict
                            }
                        }
                    }
                }
            }
            
        // Static: All non-art battles
        
        default: break
            
        }

        if HumanPlayer(actingPlayer) {
            
            aiThinkingStartTime = nil
            aiThinking = false
            
            // If there is one and only one conflict then select it, if there is zero then skip to next phase
            if phaseNew != .Move && phaseNew != .Commit {
                
                ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .NotSelectable)
                if availableCount == 0 {NewPhase()}
                else if availableCount == 1 && theSingleConflict != nil {
                    if activeConflict != nil {ResetActiveConflict(activeConflict!)}
                    activeConflict = theSingleConflict!
                    SetupActiveConflict()
                }
            }
            
        } else {
            
            aiThinkingStartTime = CFAbsoluteTimeGetCurrent()
            aiThinking = true
            
        }
        
        // Ensure last order is undoable unless in commit-phase
        if !orders.isEmpty && phaseNew != .Commit {orders.last!.unDoable = false}
        
        return "Normal"
    }
    
    // MARK: New Turn
    
    func NewTurn() {
        
        // Save the orders
        orderHistory[orderHistoryIndex] = orders
        orderHistoryIndex++
        for each in orders {each.orderArrow?.removeFromParent()}
        orders = []
        
        ResetState(true, groupsSelectable: true, hideRevealed: true, orderSelectors: true, otherSelectors: true)

        // Set turn and commands available
        if phasingPlayer != player1 {
            turn++
            corpsCommandsAvail = player1CorpsCommands
            indCommandsAvail = player1IndCommands
        
        } else if phaseNew != .Setup {
            corpsCommandsAvail = player2CorpsCommands
            indCommandsAvail = player2IndCommands
        }
        
        // Finished pre-game and set turn based on selected
        if phaseNew == .Setup && phasingPlayer != player1 {
            if scenario == 1 {turn = 12}
            phaseNew = .Move
        }
        
        // Any Move turn, set units available to defend
        if phaseNew == .Move {
            
            // Reset reserve state
            for eachReserve in reserves {eachReserve.ResetReserveState()}
            
            for eachCommand in gameCommands[actingPlayer]! + gameCommands[actingPlayer.Other()!]! {
                eachCommand.moveNumber = 0
                eachCommand.movedVia = .None
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.wasInBattle = false
                    eachUnit.approachDefended = nil
                }
            }
            for eachApproach in approaches {eachApproach.mayArtAttack = true
                eachApproach.mayNormalAttack = true
            }
        }
        ResetConflictsState()
        generalThreatsMade = 0
        
        // Always switch side, phasing and acting player
        if orders.last != nil {orders.last?.unDoable = false}
        phasingPlayer.Switch()
        actingPlayer.Switch()
        RefreshCommands()
        
        if HumanPlayer(actingPlayer) {
            aiThinkingStartTime = nil
            aiThinking = false
        } else {
            ai[actingPlayer]!.setupAI()
            aiThinkingStartTime = CFAbsoluteTimeGetCurrent()
            aiThinking = true
        }
        
        // Turn on AI if its not a human player
    }
    
    func ResetConflictsState() {

        // Reset conflict-related attributes
        for eachLocaleThreat in localeThreats {
            for eachConflict in eachLocaleThreat.conflicts {
                
                if (eachConflict.realAttack || !eachConflict.approachDefended) && eachConflict.conflictFinalWinner == eachConflict.defenseSide.Other() {
                    PostBattleMove(eachConflict, artAttack: false)
                }
                
                for eachUnit in eachConflict.threateningUnits {
                    eachUnit.threatenedConflict = nil
                    eachUnit.assigned = "None"
                }
                eachConflict.defenseApproach.threatened = false
                eachConflict.threateningUnits = []
                eachConflict.defenseApproach.approachSelector!.selected = .Off
                eachConflict.defenseApproach.zPosition = 200
            }
        }
        activeConflict = nil
        endTurnButton.buttonState = .On
        
        phantomCorpsCommand = 0
        phantomIndCommand = 0
        selectionRetreatReserves = []
        localeThreats = []
        staticLocations = []
        HideAllLocations(true)
    }

    // MARK: Manager Functions
    
    func PhantomOrderCheck(existingIsCorpsOrder:Bool, addExistingOrderToPool:Bool = true) -> (Int, Int) {
        var corpsPossible = 0
        var indPossible = 0
        var adjustment = 0
        if addExistingOrderToPool {adjustment = 1}
        if existingIsCorpsOrder {
            corpsPossible = corpsCommandsAvail - phantomCorpsCommand + adjustment
            indPossible = indCommandsAvail - phantomIndCommand
        } else {
            corpsPossible = corpsCommandsAvail - phantomCorpsCommand
            indPossible = indCommandsAvail - phantomIndCommand + adjustment
        }
        return (corpsPossible, indPossible)
    }
    
    func turnID() -> Int {
        
        if phasingPlayer == player1 {
            return (turn+1)
        } else {
            return (turn+2)
        }
    }
    
    // Sets acting player commands to normal, non-acting to off
    func RefreshCommands() {
        
        if HumanPlayer(actingPlayer) {
            
            for eachCommand in gameCommands[manager!.actingPlayer]! {
                if turn >= eachCommand.turnMayEnterMap {
                    for eachUnit in eachCommand.activeUnits {
                        eachUnit.selected = .Normal
                    }
                } else {
                    for eachUnit in eachCommand.activeUnits {
                        eachUnit.selected = .NotSelectable
                    }
                }
            }
            
            for eachCommand in gameCommands[manager!.actingPlayer.Other()!]! {
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.selected = .Off
                }
            }
            
        } else {
    
            for eachCommand in gameCommands[manager!.actingPlayer.Other()!]! {
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.selected = .NotSelectable
                }
            }
        }
    }

    
    // Populations the reserve threats
    func SetupThreats() {
        
        var index = self.orders.endIndex-1
        var theReserveConflicts:[Reserve:[Conflict]] = [:]
        
        while index >= 0 {
        
            if orders[index].theConflict != nil && !(orders[index].order! != .Threat) {
                
                let newConflict = self.orders[index].theConflict

                RevealLocation(newConflict!.defenseApproach, toReveal: true)
                staticLocations += [newConflict!.defenseApproach]
                newConflict!.defenseApproach.approachSelector!.selected = .Option
                
                if theReserveConflicts[newConflict!.defenseReserve] == nil {
                   theReserveConflicts[newConflict!.defenseReserve] = [newConflict!]
                } else {
                   theReserveConflicts[newConflict!.defenseReserve]! += [newConflict!]
                }
            } else {break}
            
            index--
        }
        
        // Setup the group-conflicts
        for (reserve, conflicts) in theReserveConflicts {
            localeThreats += [GroupConflict(passReserve: reserve, passConflicts: conflicts)]
        }
    
    }
    
    // Returns true if game-end demoralization victory
    func ReduceMorale(losses:Int, side:Allegience, mayDemoralize:Bool) -> Bool {
        
        let newMorale = morale[side]! - losses
        
        if newMorale <= 0 && !mayDemoralize {
            morale[side] = 1
        } else if newMorale <= 0 && mayDemoralize {
            morale[side] = 0
        } else {
            morale[side] = newMorale
        }
        if morale[side] > 0 {return false} else {return true}
    }
    
    func RemoveNonMovementArrows(theOrders:[Order]) {
        for each in theOrders {
            if each.order != .Move && each.order != .Retreat && each.order != .Feint {each.orderArrow?.removeFromParent()}
        }
    }
    
    // MARK: Save Support
    
    func getAllegience(value:String) -> Allegience {
        
        var suggestedAllegience:Allegience!
        switch value {
        case "Austrian":
            suggestedAllegience = .Austrian
        case "French":
            suggestedAllegience = .French
        case "Neutral":
            suggestedAllegience = .Neutral
        case "Both":
            suggestedAllegience = .Both
        default:
            suggestedAllegience = .Neutral
            
        }
        return suggestedAllegience
    }
    
    func getGamephase(value:String) -> newGamePhase {
        
        switch value {
            
        case "Setup": return .Setup
        case "Move": return .Move
        case "Commit": return .Commit
        case "RetreatOrDefenseSelection": return .RetreatOrDefenseSelection
        case "SelectDefenseLeading": return .SelectDefenseLeading
        case "PreRetreatOrFeintMoveOrAttackDeclare": return .PreRetreatOrFeintMoveOrAttackDeclare
        case "SelectAttackGroup": return .SelectAttackGroup
        case "SelectAttackLeading": return .SelectAttackLeading
        case "FeintResponse": return .FeintResponse
        case "SelectCounterGroup": return .SelectCounterGroup
        case "PostCombatRetreatAndVictoryResponseMoves": return .PostCombatRetreatAndVictoryResponseMoves
        default: return .Move
        }
    }
    
    func HumanPlayer(player:Allegience) -> Bool {
        if player == .French && frAI {
            return false
        }
        else if player == .Austrian && auAI {
            return false
        }
        return true
    }
    
    // MARK: Encoder / Decoder

    func encodeWithCoder(aCoder: NSCoder) {
        
        // Game settings
        
        aCoder.encodeInteger(scenario, forKey: "scenario")
        
        aCoder.encodeObject(gameMode, forKey: "gameMode")
        
        aCoder.encodeInteger(generalThreatsPossible, forKey: "generalThreatsPossible")
        
        aCoder.encodeInteger(maxMorale[player1]!, forKey: "auMaxMorale")
        aCoder.encodeInteger(maxMorale[player2]!, forKey: "frMaxMorale")
        
        // Game Variables
        
        aCoder.encodeObject(gameCommands[player1], forKey: "auCommands")
        aCoder.encodeObject(gameCommands[player2], forKey: "frCommands")
        
        aCoder.encodeObject(priorityLosses[player1], forKey: "auPriorityLosses")
        aCoder.encodeObject(priorityLosses[player2], forKey: "frPriorityLosses")
        
        aCoder.encodeObject(priorityLeaderAndBattle[player1], forKey: "auPriorityLeaderAndBattle")
        aCoder.encodeObject(priorityLeaderAndBattle[player2], forKey: "frPriorityLeaderAndBattle")
        
        aCoder.encodeObject(localeThreats, forKey: "localeThreats")
        
        aCoder.encodeObject(staticLocations, forKey: "staticLocations")
        
        aCoder.encodeObject(approaches, forKey: "approaches")
        
        aCoder.encodeObject(reserves, forKey: "reserves")
        
        aCoder.encodeObject(orders, forKey: "orders")
        
        aCoder.encodeInteger(orderHistoryIndex, forKey: "orderHistoryIndex")
        
        aCoder.encodeObject(orderHistory, forKey: "orderHistory")
        
        aCoder.encodeInteger(generalThreatsMade, forKey: "generalThreatsMade")
        
        aCoder.encodeObject(phasingPlayer.ID, forKey: "phasingPlayer")
        
        aCoder.encodeObject(actingPlayer.ID, forKey: "actingPlayer")
        
        aCoder.encodeInteger(day, forKey: "day")
        
        aCoder.encodeInteger(turn, forKey: "turn")
        
        aCoder.encodeBool(night, forKey: "night")
        
        aCoder.encodeObject(phaseNew.ID, forKey: "phaseNew")
        
        aCoder.encodeInteger(player2CorpsCommands, forKey: "player2CorpsCommands")
        
        aCoder.encodeInteger(corpsCommandsAvail, forKey: "corpsCommandsAvail")
        
        aCoder.encodeInteger(indCommandsAvail, forKey: "indCommandsAvail")
        
        aCoder.encodeInteger(phantomCorpsCommand, forKey: "phantomCorpsCommand")
        
        aCoder.encodeInteger(phantomIndCommand, forKey: "phantomIndCommand")
        
        aCoder.encodeInteger(morale[player1]!, forKey: "auMorale")
        aCoder.encodeInteger(morale[player2]!, forKey: "frMorale")
        
        aCoder.encodeBool(frReinforcementsCalled, forKey: "frReinforcementsCalled")
        
        aCoder.encodeBool(heavyCavCommited[player1]!, forKey: "auHeavyCavCommited")
        aCoder.encodeBool(heavyCavCommited[player2]!, forKey: "frHeavyCavCommited")
        
        aCoder.encodeBool(guardCommitted[player1]!, forKey: "auGuardCommitted")
        aCoder.encodeBool(guardCommitted[player2]!, forKey: "frGuardCommitted")
        
        aCoder.encodeBool(guardFailed[player1]!, forKey: "auGuardFailed")
        aCoder.encodeBool(guardFailed[player2]!, forKey: "frGuardFailed")
        
    }
    
    func decodeWithCoder(aDecoder: NSCoder) {
        
        // Game settings
        
        scenario = aDecoder.decodeIntegerForKey("scenario")
        
        gameMode = aDecoder.decodeObjectForKey("gameMode") as! String
        
        generalThreatsPossible = aDecoder.decodeIntegerForKey("generalThreatsPossible")
        
        maxMorale[player1] = aDecoder.decodeIntegerForKey("auMaxMorale")
        maxMorale[player2] = aDecoder.decodeIntegerForKey("frMaxMorale")
        
        // Game Variables
        
        gameCommands[player1] = (aDecoder.decodeObjectForKey("auCommands") as! [Command])
        gameCommands[player2] = (aDecoder.decodeObjectForKey("frCommands") as! [Command])
        
        priorityLosses[player1] = (aDecoder.decodeObjectForKey("auPriorityLosses") as! [Int])
        priorityLosses[player2] = (aDecoder.decodeObjectForKey("frPriorityLosses") as! [Int])
        
        priorityLeaderAndBattle[player1] = (aDecoder.decodeObjectForKey("auPriorityLeaderAndBattle") as! [Int])
        priorityLeaderAndBattle[player2] = (aDecoder.decodeObjectForKey("frPriorityLeaderAndBattle") as! [Int])
        
        localeThreats = aDecoder.decodeObjectForKey("localeThreats") as! [NapoleonTriumph.GroupConflict]
        
        staticLocations = aDecoder.decodeObjectForKey("staticLocations") as! [SKNode]
        
        approaches = aDecoder.decodeObjectForKey("approaches") as! [NapoleonTriumph.Approach]
        
        reserves = aDecoder.decodeObjectForKey("reserves") as! [NapoleonTriumph.Reserve]
        
        orders = aDecoder.decodeObjectForKey("orders") as! [NapoleonTriumph.Order]
        
        orderHistoryIndex = aDecoder.decodeIntegerForKey("orderHistoryIndex")
        
        orderHistory = aDecoder.decodeObjectForKey("orderHistory") as! [Int : [Order]]
        
        generalThreatsMade = aDecoder.decodeIntegerForKey("generalThreatsMade")
        
        phasingPlayer = self.getAllegience(aDecoder.decodeObjectForKey("phasingPlayer") as! String)
        
        actingPlayer = self.getAllegience(aDecoder.decodeObjectForKey("actingPlayer") as! String)
        
        day = aDecoder.decodeIntegerForKey("day")
        
        turn = aDecoder.decodeIntegerForKey("turn")
        
        night = aDecoder.decodeBoolForKey("night")
        
        phaseNew = self.getGamephase(aDecoder.decodeObjectForKey("phaseNew") as! String)
        
        player2CorpsCommands = aDecoder.decodeIntegerForKey("player2CorpsCommands")
        
        corpsCommandsAvail = aDecoder.decodeIntegerForKey("corpsCommandsAvail")
        
        indCommandsAvail = aDecoder.decodeIntegerForKey("indCommandsAvail")
        
        phantomCorpsCommand = aDecoder.decodeIntegerForKey("phantomCorpsCommand")
        
        phantomIndCommand = aDecoder.decodeIntegerForKey("phantomIndCommand")
        
        morale[player1] = (aDecoder.decodeObjectForKey("auMorale") as! Int)
        morale[player2] = (aDecoder.decodeObjectForKey("frMorale") as! Int)
        
        frReinforcementsCalled = aDecoder.decodeBoolForKey("frReinforcementsCalled")
        
        heavyCavCommited[player1] = (aDecoder.decodeObjectForKey("auHeavyCavCommited") as! Bool)
        heavyCavCommited[player2] = (aDecoder.decodeObjectForKey("frHeavyCavCommited") as! Bool)
        
        guardCommitted[player1] = (aDecoder.decodeObjectForKey("auGuardCommitted") as! Bool)
        guardCommitted[player2] = (aDecoder.decodeObjectForKey("frGuardCommitted") as! Bool)
        
        guardFailed[player1] = (aDecoder.decodeObjectForKey("auGuardFailed") as! Bool)
        guardFailed[player2] = (aDecoder.decodeObjectForKey("frGuardFailed") as! Bool)
        
    }
}

