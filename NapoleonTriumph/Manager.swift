//
//  Manager.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-25.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

// MARK: New Phase

/*
enum newGamePhase {
    
    case Setup, Move, Defend, Commit, Feint
    
    init (initPhase:String = "Move") {
        switch initPhase {case "Setup": self = .Setup default: self = .Move}
    }
    
    // Changes the phase returns (whether to switch the acting player, whether to advance the turn)
    mutating func NextPhase (fight:Bool = true) -> (Bool, Bool) {
    
        var secondImpulse:Bool = false
        var switchActing:(Bool, Bool) = (true, false)
        
        switch (self, secondImpulse, fight) {
        
            // Pre-game setup
            case (.Setup, false, _): secondImpulse = true
            case (.Setup, true, _): self = .Move; secondImpulse = false; switchActing = (true, true)
            
            // No attacks or feints - switches player, keeps same phase
            case (.Move, false, false): secondImpulse = true
            case (.Move, true, false): secondImpulse = false; switchActing = (true, true)
            
            // Move phase ends with some hostility, switch to defend phase
            case (.Move, _, true): self = .Defend
                
            // Defender punts it back to the attacker (always attacker choice available during commit)
            case (.Defend, _, _): self = .DeclaredLeadingA

            // Attacker executes feints, commits on attacks
            case (.DeclaredLeadingA, _, _): self = .Feint // Valid defense choices
            
            // ATTACK PROCESSING
                
            // Next player's move
            case (.Feint, _, _): self = .Move; switchActing = (false, true)
                
            default:
                break
                
        }
        
        return switchActing
    }
}
*/

// MARK: Old Phase

enum oldGamePhase {
    
    case Setup, Move, FeintThreat, NormalThreat, StoodAgainstFeintThreat, StoodAgainstNormalThreat, RetreatedBeforeCombat, FeintMove, RealAttack, DeclaredLeadingD, DeclaredAttackers, DeclaredLeadingA, RetreatAfterCombat, PostVictoryFeintMove
    
    var ID:String {
        switch self {
        case .Setup: return "PreGame"
        case .Move: return "Move"
        case .FeintThreat: return "FeintThreat"
        case .NormalThreat: return "NormalThreat"
        case .StoodAgainstFeintThreat: return "StoodAgainstFT"
        case .StoodAgainstNormalThreat: return "StoodAgainstNT"
        case .RetreatedBeforeCombat: return "RetreatedB4"
        case .FeintMove: return "FeintMove"
        case .RealAttack: return "RealAttack"
        case .DeclaredLeadingD: return "DeclaredLeadingD"
        case .DeclaredAttackers: return "DeclaredAttackers"
        case .DeclaredLeadingA: return "DeclaredLeadingA"
        case .RetreatAfterCombat: return "RetreatAfterCombat"
        case .PostVictoryFeintMove: return "PostVictoryFeintMove"
        //default: return "Move"
        }
    }
    
    init (initPhase:String = "Move") {
        switch initPhase {case "PreGame": self = .Setup default: self = .Move}
    }
    
    // Changes the phase based on fight/flight stance and returns whether to switch the acting player
    mutating func NextPhase(fight:Int = 1, reverse:Bool = false) -> Bool {
    
        var switchActing:Bool = true
        
        if !reverse {

            switch (self, fight) {
            
            // Pre-game move (T/F on whether to advance to move)
            //case (.Setup, false):
            //case (.Setup, true): self = .Move
                
            // Attacker move
            case (.Move, 1): self = .NormalThreat
            case (.Move, 2): self = .FeintThreat
            
            // Defender move since "Attacker made a..."
            case (.NormalThreat, 1): self = .StoodAgainstNormalThreat
            case (.NormalThreat, 2): self = .RetreatedBeforeCombat
            case (.FeintThreat, 1): self = .StoodAgainstFeintThreat
            case (.FeintThreat, 2): self = .RetreatedBeforeCombat
            
            // Attacker move since "Defender..."
            case (.StoodAgainstNormalThreat, 1): self = .RealAttack
            case (.StoodAgainstNormalThreat, 2): self = .FeintMove
            case (.StoodAgainstFeintThreat, _): self = .FeintMove
            case (.RetreatedBeforeCombat, 1): self = .Move; switchActing = false
            case (.RetreatedBeforeCombat, 2): self = .FeintThreat // Unusual case of continued attack by rd
                
            // Defender move since "Attacker made a..."
            case (.RealAttack, _): self = .DeclaredLeadingD
            case (.FeintMove, _): self = .Move

            // Attacker move since "Defender..."
            case (.DeclaredLeadingD, _): self = .DeclaredAttackers; switchActing = false
            
            // Attacker move since "Attacker..."
            case (.DeclaredAttackers, _): self = .DeclaredLeadingA

            // <<<INITIAL RESULT PROCESSING>>>
            
            // Defender move since "Attacker..."
            case (.DeclaredLeadingA, 1): self = .RetreatAfterCombat; switchActing = false
            case (.DeclaredLeadingA, 2): self = .PostVictoryFeintMove; switchActing = false
                
            // <<<FINAL RESULT PROCESSING>>>
            
            // Defender move since "Battle resolved, defender lost"
            case (.RetreatAfterCombat, 1): self = .Move
            case (.PostVictoryFeintMove, 1): self = .Move
                
            default: break
                
            }
        
        } else {
            
            switch (self, fight) {
                
            // Pre-game move (T/F on whether to advance to move)
            //case (.Setup, false):
            //case (.Setup, true): self = .Move
                
            case (.NormalThreat, _): self = .Move
            case (.FeintThreat, 1): self = .Move
                
            case (.StoodAgainstNormalThreat, _): self = .NormalThreat
            case (.RetreatedBeforeCombat, 1): self = .NormalThreat
            case (.StoodAgainstFeintThreat, _): self = .FeintThreat
            case (.FeintThreat, 2): self = .RetreatedBeforeCombat // Unusual case of continued attack by rd
            case (.RetreatedBeforeCombat, 2): self = .FeintThreat
                
            case (.RealAttack, _): self = .StoodAgainstNormalThreat
            
            case (.FeintMove, 1): self = .StoodAgainstNormalThreat
            case (.FeintMove, 2): self = .StoodAgainstFeintThreat
            
            case (.DeclaredLeadingD, _): self = .RealAttack
                
            case (.DeclaredAttackers, _): self = .DeclaredLeadingD; switchActing = false
            case (.DeclaredLeadingA, _): self = .DeclaredAttackers
                
            case (.RetreatAfterCombat, _): self = .DeclaredLeadingA; switchActing = false
            case (.PostVictoryFeintMove, _): self = .DeclaredLeadingA; switchActing = false
                
            case (.Move, 1): self = .FeintMove
            case (.Move, 2): self = .RetreatedBeforeCombat; switchActing = false
            case (.Move, 3): self = .RetreatAfterCombat
            case (.Move, 4): self = .PostVictoryFeintMove
                
            default:
                break
                
            }
        }
        
        return switchActing
    }
}

// MARK: Game Manager

class GameManager: NSObject, NSCoding {

    required init(coder aDecoder: NSCoder) {

        super.init()
        //Retrive GameCommands
        let auCommand = aDecoder.decodeObjectForKey("auCommands") as! [Command]
        let frCommand = aDecoder.decodeObjectForKey("frCommands") as! [Command]

        let playerAu:Allegience = .Austrian
        let playerFr:Allegience = .French
        
        gameCommands[playerAu] = auCommand
        gameCommands[playerFr] = frCommand
        
        //Retrive priorityLosses
        let auLosses = aDecoder.decodeObjectForKey("auLosses") as! [Int]
        let frLosses = aDecoder.decodeObjectForKey("frLosses") as! [Int]
        
        let PriorityLossesAu:Allegience = .Austrian
        let PriorityLossesFr:Allegience = .French
        
        priorityLosses[PriorityLossesAu] = auLosses
        priorityLosses[PriorityLossesFr] = frLosses
        //
        
        //Retrive priorityLeaderAndBattle
        let auLeaderAndBattle = aDecoder.decodeObjectForKey("auLeaderAndBattle") as! [Int]
        let frLeaderAndBattle = aDecoder.decodeObjectForKey("frLeaderAndBattle") as! [Int]
        priorityLeaderAndBattle[PriorityLossesAu] = auLeaderAndBattle
        priorityLeaderAndBattle[PriorityLossesFr] = frLeaderAndBattle
        //
        
        selectableDefenseGroups = aDecoder.decodeObjectForKey("selectableDefenseGroups") as! [Group]
        selectableRetreatGroups = aDecoder.decodeObjectForKey("selectableRetreatGroups") as! [Group]
        selectableAttackGroups = aDecoder.decodeObjectForKey("selectableAttackGroups") as! [Group]
        selectableAttackByRoadGroups = aDecoder.decodeObjectForKey("selectableAttackByRoadGroups") as! [Group]
        selectableAttackAdjacentGroups = aDecoder.decodeObjectForKey("selectableAttackAdjacentGroups") as! [Group]
        currentGroupsSelected = aDecoder.decodeObjectForKey("currentGroupsSelected") as! [Group]
        repeatAttackGroup = aDecoder.decodeObjectForKey("repeatAttackGroup") as? Group

        repeatAttackMoveNumber = aDecoder.decodeIntegerForKey("repeatAttackMoveNumber")
        
        activeThreat = aDecoder.decodeObjectForKey("activeThreat") as? GroupConflict
        
     
        approaches = aDecoder.decodeObjectForKey("approaches") as! [NapoleonTriumph.Approach]

        reserves = aDecoder.decodeObjectForKey("reserves") as! [NapoleonTriumph.Reserve]

        orders = aDecoder.decodeObjectForKey("orders") as! [NapoleonTriumph.Order]

        orderHistory = aDecoder.decodeObjectForKey("orderHistory") as! [Int : [Order]]

        
        player1 = self.getAllegience(aDecoder.decodeObjectForKey("player1") as! String)


        player1CorpsCommands = aDecoder.decodeIntegerForKey("player1CorpsCommands")

        
        player1IndCommands = aDecoder.decodeIntegerForKey("player1IndCommands")

        player2CorpsCommands = aDecoder.decodeIntegerForKey("player2CorpsCommands")

        player2IndCommands = aDecoder.decodeIntegerForKey("player2IndCommands")

        orderHistoryTurn = aDecoder.decodeIntegerForKey("orderHistoryTurn")

        phasingPlayer = self.getAllegience(aDecoder.decodeObjectForKey("phasingPlayer") as! String)

        actingPlayer = self.getAllegience(aDecoder.decodeObjectForKey("actingPlayer") as! String)

        scenario = aDecoder.decodeIntegerForKey("scenario")

        day = aDecoder.decodeIntegerForKey("day")

        turn = aDecoder.decodeIntegerForKey("turn")

        night = aDecoder.decodeBoolForKey("night")
        
        phaseOld = self.getGamephase(aDecoder.decodeObjectForKey("phaseOld") as! String)

        corpsCommandsAvail = aDecoder.decodeIntegerForKey("corpsCommandsAvail")

        indCommandsAvail = aDecoder.decodeIntegerForKey("indCommandsAvail")

        //commandLabel = aDecoder.decodeObjectForKey("commandLabel") as! SKLabelNode
        //indLabel = aDecoder.decodeObjectForKey("indLabel") as! SKLabelNode
        //phasingLabel = aDecoder.decodeObjectForKey("phasingLabel") as! SKLabelNode
        //actingLabel = aDecoder.decodeObjectForKey("actingLabel") as! SKLabelNode
        //turnLabel = aDecoder.decodeObjectForKey("turnLabel") as! SKLabelNode
        //alliedMoraleLabel = aDecoder.decodeObjectForKey("alliedMoraleLabel") as! SKLabelNode
        //frenchMoraleLabel = aDecoder.decodeObjectForKey("frenchMoraleLabel") as! SKLabelNode
        
        morale[.French]! = aDecoder.decodeIntegerForKey("morF")

        morale[.Austrian]! = aDecoder.decodeIntegerForKey("morA")

        frReinforcements = aDecoder.decodeBoolForKey("frReinforcements")
        

        heavyCavCommited[.French] = aDecoder.decodeBoolForKey("frheavyCavCommited")

        heavyCavCommited[.Austrian] = aDecoder.decodeBoolForKey("auheavyCavCommited")

        //guardCommitted
        guardCommitted[.French] = aDecoder.decodeBoolForKey("frguardCommitted")
        
        guardCommitted[.Austrian] = aDecoder.decodeBoolForKey("auguardCommitted")

        //guardFailed
        guardFailed[.French] = aDecoder.decodeBoolForKey("frguardFailed")
        
        guardFailed[.Austrian] = aDecoder.decodeBoolForKey("auguardFailed")
        
        heavyCavCommittedCost = aDecoder.decodeIntegerForKey("heavyCavCommittedCost")

        guardCommittedCost = aDecoder.decodeIntegerForKey("guardCommittedCost")

        //drawOnNode = aDecoder.decodeObjectForKey("drawOnNode") as? SKNode
    }
    
    func getGamephase(value:String)->oldGamePhase {
        
        switch value {
        
            case "PreGame": return .Setup
            case "Move": return .Move
            case "FeintThreat": return .FeintThreat
            case "NormalThreat": return .NormalThreat
            case "StoodAgainstFT": return .StoodAgainstFeintThreat
            case "StoodAgainstNT": return .StoodAgainstNormalThreat
            case "RetreatedB4": return .RetreatedBeforeCombat
            case "FeintMove": return .FeintMove
            case "RealAttack": return .RealAttack
            case "DeclaredLeadingD": return .DeclaredLeadingD
            case "DeclaredAttackers": return .DeclaredAttackers
            case "DeclaredLeadingA": return .DeclaredLeadingA
            case "RetreatAfterCombat": return .RetreatAfterCombat
            case "PostVictoryFeintMove": return .PostVictoryFeintMove
            default: return .Setup
        }
    }
    
    func getAllegience(value:String)->Allegience {
        
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
            suggestedAllegience = .Austrian
            
        }

        return suggestedAllegience
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
  
        //Save GameCommands
        let playerAu:Allegience = .Austrian
        let playerFr:Allegience = .French
        let auCommands = gameCommands[playerAu]!
        let frCommands = gameCommands[playerFr]!
        aCoder.encodeObject(auCommands, forKey: "auCommands")
        aCoder.encodeObject(frCommands, forKey: "frCommands")
        //
        
        //Save priorityLosses
        let PriorityLossesAu:Allegience = .Austrian
        let PriorityLossesFr:Allegience = .French
        let auLosses = priorityLosses[PriorityLossesAu]!
        let frLosses = priorityLosses[PriorityLossesFr]! 
        aCoder.encodeObject(auLosses, forKey: "auLosses")
        aCoder.encodeObject(frLosses, forKey: "frLosses")
        //
        
        //Save priorityLeaderAndBattle
        let priorityLeaderAndBattleAu:Allegience = .Austrian
        let priorityLeaderAndBattleFr:Allegience = .French
        let auLeaderAndBattle = priorityLeaderAndBattle[priorityLeaderAndBattleAu]!
        let frLeaderAndBattle = priorityLeaderAndBattle[priorityLeaderAndBattleFr]!
        aCoder.encodeObject(auLeaderAndBattle, forKey: "auLeaderAndBattle")
        aCoder.encodeObject(frLeaderAndBattle, forKey: "frLeaderAndBattle")
        //
        
        
        aCoder.encodeObject(selectableDefenseGroups, forKey: "selectableDefenseGroups")
        aCoder.encodeObject(selectableRetreatGroups, forKey: "selectableRetreatGroups")
        aCoder.encodeObject(selectableAttackGroups, forKey: "selectableAttackGroups")
        aCoder.encodeObject(selectableAttackByRoadGroups, forKey: "selectableAttackByRoadGroups")
        aCoder.encodeObject(selectableAttackAdjacentGroups, forKey: "selectableAttackAdjacentGroups")

        aCoder.encodeObject(currentGroupsSelected, forKey: "currentGroupsSelected")

        aCoder.encodeObject(repeatAttackGroup, forKey: "repeatAttackGroup")

        aCoder.encodeInteger(repeatAttackMoveNumber!, forKey: "repeatAttackMoveNumber")
        
        aCoder.encodeObject(activeThreat, forKey: "activeThreat")
        
        aCoder.encodeObject(approaches, forKey: "approaches")

        aCoder.encodeObject(reserves, forKey: "reserves")

        aCoder.encodeObject(orders, forKey: "orders")

        aCoder.encodeObject(orderHistory, forKey: "orderHistory")

        aCoder.encodeObject(player1.ID, forKey: "player1")

        aCoder.encodeInteger(player1CorpsCommands, forKey: "player1CorpsCommands")

        aCoder.encodeInteger(player1IndCommands, forKey: "player1IndCommands")

        aCoder.encodeInteger(player2CorpsCommands, forKey: "player2CorpsCommands")

        aCoder.encodeInteger(player2IndCommands, forKey: "player2IndCommands")

        aCoder.encodeInteger(orderHistoryTurn, forKey: "orderHistoryTurn")

        aCoder.encodeObject(phasingPlayer.ID, forKey: "phasingPlayer")

        aCoder.encodeObject(actingPlayer.ID, forKey: "actingPlayer")

        aCoder.encodeInteger(scenario, forKey: "scenario")

        aCoder.encodeInteger(day, forKey: "day")

        aCoder.encodeInteger(turn, forKey: "turn")

        aCoder.encodeBool(night, forKey: "night")
        
        aCoder.encodeObject(phaseOld.ID, forKey: "phaseOld")

        aCoder.encodeInteger(corpsCommandsAvail, forKey: "corpsCommandsAvail")

        aCoder.encodeInteger(indCommandsAvail, forKey: "indCommandsAvail")

        aCoder.encodeObject(commandLabel, forKey: "commandLabel")
        aCoder.encodeObject(indLabel, forKey: "indLabel")
        aCoder.encodeObject(phasingLabel, forKey: "phasingLabel")
        aCoder.encodeObject(actingLabel, forKey: "actingLabel")
        aCoder.encodeObject(turnLabel, forKey: "turnLabel")
        aCoder.encodeObject(alliedMoraleLabel, forKey: "alliedMoraleLabel")
        aCoder.encodeObject(frenchMoraleLabel, forKey: "frenchMoraleLabel")

        aCoder.encodeInteger(maxMorale[.French]!, forKey: "maxF")

        aCoder.encodeInteger(maxMorale[.Austrian]!, forKey: "maxA")

        aCoder.encodeInteger(morale[.French]!, forKey: "morF")
        
        aCoder.encodeInteger(morale[.Austrian]!, forKey: "morA")

        aCoder.encodeBool(frReinforcements, forKey: "frReinforcements")

        aCoder.encodeBool(heavyCavCommited[.French]!, forKey: "frheavyCavCommited")

        aCoder.encodeBool(heavyCavCommited[.Austrian]!, forKey: "auheavyCavCommited")

        aCoder.encodeBool(guardCommitted[.French]!, forKey: "frguardCommitted")
        
        aCoder.encodeBool(guardCommitted[.Austrian]!, forKey: "auguardCommitted")

        aCoder.encodeBool(guardFailed[.French]!, forKey: "frguardFailed")
        
        aCoder.encodeBool(guardFailed[.Austrian]!, forKey: "auguardFailed")

        aCoder.encodeInteger(heavyCavCommittedCost, forKey: "heavyCavCommittedCost")

        aCoder.encodeInteger(guardCommittedCost, forKey: "guardCommittedCost")

        aCoder.encodeInteger(guardFailedCost, forKey: "guardFailedCost")

        //aCoder.encodeObject(drawOnNode, forKey: "drawOnNode")
       
    }
    
    var gameCommands:[Allegience:[Command]] = [.Austrian:[], .French:[]]
    var priorityLosses:[Allegience:[Int]] = [.Austrian:[43, 23, 22, 21, 33, 32, 31], .French:[43, 23, 22, 21, 33, 32, 31]]
    var priorityLeaderAndBattle:[Allegience:[Int]] = [.Austrian:[33, 43, 23, 32, 22, 31, 21], .French:[33, 43, 23, 32, 22, 31, 21]]
    
    var selectableDefenseGroups:[Group] = []
    var selectableRetreatGroups:[Group] = []
    var selectableAttackGroups:[Group] = []
    var selectableAttackByRoadGroups:[Group] = []
    var selectableAttackAdjacentGroups:[Group] = []
    
    var currentGroupsSelected:[Group] = []
    
    var repeatAttackGroup:Group? // Used to store the group for rare cases of repeat attacks along the rd
    var repeatAttackMoveNumber:Int?
    
    var selectionRetreatReserves:[Reserve] = [] // Stores viable retreat reserves for the current selection
    var activeThreat:GroupConflict?
    
    var approaches = [Approach]()
    var reserves = [Reserve]()
    var orders = [Order]()
    var orderHistory:[Int:[Order]] = [:]
    
    // Phasing and acting player
    var player1:Allegience = .Austrian
    
    var statePointTracker:ReviewState = .Front
   
    // Commands available
    var player1CorpsCommands:Int = 5
    var player1IndCommands:Int = 3
    var player2CorpsCommands:Int = 6
    var player2IndCommands:Int = 4
    
    var orderHistoryTurn:Int = 1
    
    var phasingPlayer:Allegience = .Austrian {
        didSet {
            if (self.phasingPlayer == player1) {orderHistoryTurn = (2*turn - 1)} else {orderHistoryTurn = 2*turn}
            updatePhasingLabel()
        }
    }
    
    var actingPlayer:Allegience = .Austrian {
        didSet {updateActingLabel()}
    }

    // Current turn
    var scenario:Int = 1 // This is to set game to scenario 1 or 2
    var day:Int = 1
    var night:Bool = false
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
    
    var phaseOld:oldGamePhase = oldGamePhase() {
        didSet {
            updateTurnLabel()
        }
    }
    
    var corpsCommandsAvail:Int = 0 {
        didSet {updateCommandLabel()}
    }
    var indCommandsAvail:Int = 0 {
        didSet {updateIndLabel()}
    }
    
    // Morale
    var maxMorale:[Allegience:Int!] = [ .Austrian: 27, .French: 23]
    var morale:[Allegience:Int!] = [ .Austrian: 27, .French: 23] {
        didSet{updateMoraleLabel()}
    }
    
    var frReinforcements:Bool = false
    
    var heavyCavCommited:[Allegience:Bool] = [ .Austrian: false, .French: false]
    var guardCommitted:[Allegience:Bool] = [ .Austrian: false, .French: false]
    var guardFailed:[Allegience:Bool] = [ .Austrian: false, .French: false]
    
    var heavyCavCommittedCost:Int = 2
    var guardCommittedCost:Int = 4
    var guardFailedCost:Int = 3
    
    override init() {
        phasingPlayer = player1
        actingPlayer = player1
        phaseOld = .Setup
        corpsCommandsAvail = 0
        indCommandsAvail = 0
    }

    // MARK: New Phase
    
    // Triggered by conflict commands (eg. moving into an enemy locale)
    func NewPhase(fight:Int, reverse:Bool = false, playback:Bool = false) -> String {

        // Increments phase if we aren't in play-back mode
        if playback {return "Playback"}
        
        let phaseChange = phaseOld.NextPhase(fight, reverse: reverse) // Moves us to the next phase, returns true if need to swith acting player
        if phaseChange {actingPlayer.Switch()}
        RefreshCommands()
        
        if orders.last != nil {orders.last?.unDoable = false}
        
        switch (phaseOld) {
        
        case .Setup, .Move:
            
            // Updates the selected status of the game commands generally after a battle
            for eachCommand in gameCommands[actingPlayer]! {
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.updateSelectedStatus()
                }
                CheckForOneBlockCorps(eachCommand)
            }
            
            RemoveArrows()
            ResetManagerState()
        
        case .FeintThreat, .NormalThreat:
            
            // Setup the threat-groups and setup the retreat and defense selection groups @ Will need to go through all orders in "new version"
            SetupThreat()
            
            // Return the code (whether forced retreat / defend)
            return ResetRetreatDefenseSelection()
        
        case .StoodAgainstNormalThreat, .RetreatedBeforeCombat, .StoodAgainstFeintThreat:
            
            // Set selectable commands
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            selectableAttackByRoadGroups = SelectableGroupsForAttackByRoad(activeThreat!.conflict)
            selectableAttackAdjacentGroups = SelectableGroupsForAttackAdjacent(activeThreat!.conflict)
            ToggleGroups(selectableAttackByRoadGroups, makeSelection: .Normal)
            ToggleGroups(selectableAttackAdjacentGroups, makeSelection: .Normal)
        
        case .FeintMove:
            
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            SelectableGroupsForFeintDefense(activeThreat!.conflict)
            activeThreat!.conflict.attackApproach.hidden = true
        
        case .RealAttack:
            
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            
            SelectableLeadingGroups(activeThreat!.conflict, thePhase: phaseOld)
            SelectLeadingUnits(activeThreat!.conflict)
            
        case .DeclaredLeadingD:
            
            // Defense leading units visible to attacker
            selectableAttackAdjacentGroups = SelectableGroupsForAttackAdjacent(activeThreat!.conflict)
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            ToggleGroups(selectableAttackAdjacentGroups, makeSelection: .Normal)
            ToggleGroups(activeThreat!.conflict.defenseLeadingUnits!.groups, makeSelection: .Selected)
        
        case .DeclaredAttackers:
            
            // Defense leading units visible to attacker
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            ToggleGroups(activeThreat!.conflict.attackGroup!.groups, makeSelection: .Normal)
            ToggleGroups(activeThreat!.conflict.defenseGroup!.groups, makeSelection: .NotSelectable)
            ToggleGroups(activeThreat!.conflict.defenseLeadingUnits!.groups, makeSelection: .Selected)
            
            SelectableLeadingGroups(activeThreat!.conflict, thePhase: phaseOld)
            SelectLeadingUnits(activeThreat!.conflict)
            
        case .DeclaredLeadingA:
            
            // Attack leading units visible to defender
            ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
            ToggleGroups(activeThreat!.conflict.attackLeadingUnits!.groups, makeSelection: .Selected)
            
            if activeThreat!.conflict.mayCounterAttack {
                ToggleGroups(activeThreat!.conflict.counterAttackGroup!.groups, makeSelection: .Normal)
                SelectLeadingUnits(activeThreat!.conflict)
            }
            
        case .RetreatAfterCombat: break
            
        case .PostVictoryFeintMove:
            
            //ToggleCommands(gameCommands[actingPlayer]!, makeSelectable: false)
            ToggleGroups(GroupsIncludeLeaders(activeThreat!.conflict.defenseGroup!.groups), makeSelection: .Normal)
            
        }
        return "Nothing"
    }
    
    // MARK: New Turn
    
    func NewTurn() {
        
        // Save the previous phasing player's orders
        orderHistory[orderHistoryTurn] = orders
        for each in orders {each.orderArrow?.removeFromParent()}
        orders = []
        
        // Set turn and commands available
        if phasingPlayer != player1 {
            turn++
            corpsCommandsAvail = player1CorpsCommands
            indCommandsAvail = player1IndCommands
        
        } else if phaseOld != .Setup {
            corpsCommandsAvail = player2CorpsCommands
            indCommandsAvail = player2IndCommands
        }
        
        // Finished pre-game and set turn based on selected
        if phaseOld == .Setup && phasingPlayer != player1 {
            if scenario == 1 {turn = 12}
            phaseOld = .Move
        }
        
        // Any Move turn, set units available to defend
        if phaseOld == .Move {
            
            // Reset reserve state
            for eachReserve in reserves {eachReserve.ResetReserveState()}
            
            for eachCommand in gameCommands[actingPlayer]! + gameCommands[actingPlayer.Other()!]! {
                eachCommand.moveNumber = 0
                eachCommand.movedVia = .None
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.wasInBattle = false
                    eachUnit.alreadyDefended = false // ; eachUnit.hasMoved = false this is set with observer
                }
            }
        }
        
        // Reset game-state
        for eachApproach in approaches {eachApproach.mayArtAttack = true; eachApproach.mayNormalAttack = true}
        ResetManagerState()
        
        // Always switch side, phasing and acting player
        
        if orders.last != nil {orders.last?.unDoable = false}
        phasingPlayer.Switch()
        actingPlayer.Switch()
        RefreshCommands()
        
    }
    
    func ResetManagerState() {
        
        selectableDefenseGroups = []
        selectableRetreatGroups = []
        selectableAttackGroups = []
        selectableAttackByRoadGroups = []
        selectableAttackAdjacentGroups = []
        
        currentGroupsSelected = []
        repeatAttackGroup = nil
        repeatAttackMoveNumber = nil
        selectionRetreatReserves = []
        activeThreat = nil
    }

    // MARK: Manager Support Functions
    
    func turnID() -> Int {
        
        if phasingPlayer == player1 {
            return (turn+1)
        } else {
            return (turn+2)
        }
    }
    
    func RefreshCommands() {
        
        for eachCommand in gameCommands[manager!.actingPlayer]! {
            for eachUnit in eachCommand.activeUnits {
                eachUnit.selected = .Normal
            }
        }
        
        for eachCommand in gameCommands[manager!.actingPlayer.Other()!]! {
            for eachUnit in eachCommand.activeUnits {
                eachUnit.selected = .Off
            }
        }
    }
    
    // Populations the reserve threats
    func SetupThreat() {
        
        let index = self.orders.endIndex-1

        guard let theConflict = self.orders[index].theConflict else {return}
        activeThreat = GroupConflict(passReserve: theConflict.defenseReserve, passConflict: theConflict)
        
        // Captures second attack over same location (resets those units that were involved in the first conflict)
        if activeThreat!.conflict.defenseApproach.mayNormalAttack && !activeThreat!.conflict.defenseApproach.mayArtAttack {
            for eachCommand in theConflict.defenseApproach.occupants + theConflict.defenseReserve.occupants {
                for eachUnit in eachCommand.activeUnits {
                    if eachUnit.approachDefended != nil && activeThreat!.conflict.defenseApproach == eachUnit.approachDefended {
                        eachUnit.alreadyDefended = false
                        eachUnit.approachDefended = nil
                    }
                }
            }
        }
    }
    
    // Returns retreat mode (for the retreat selector)
    func ResetRetreatDefenseSelection () -> String {
        
        //for eachGroup in reserveThreats {
            
        ToggleCommands(gameCommands[actingPlayer]!, makeSelection: .Off)
        
        // Determine selectable defend groups (those which can defend)
        selectableDefenseGroups = SelectableGroupsForDefense(activeThreat!.conflict)
        
        // Determine selectable retreat groups (everything in the locale)
        selectableRetreatGroups = SelectableGroupsForRetreat(activeThreat!.conflict) // Get this to return available reserves
        
        // Determines whether there is a forced retreat condition
        (activeThreat!.mustRetreat, activeThreat!.mustDefend) = CheckForcedRetreatOrDefend(activeThreat!)

        // Surrender Case
        if activeThreat!.mustRetreat == true && activeThreat!.mustDefend == true {activeThreat!.retreatMode = true; return "TurnOnSurrender"}
        
        // If not surrender case and must retreat is on
        if activeThreat!.mustRetreat {activeThreat!.retreatMode = true}
        
        // After we finish all threats for a reserve, set the available move-to locations and toggle selectable groups on
        if !activeThreat!.retreatMode { // All threats for a given reserve must be in the same initial threat-mode
            
            // Turns on the selectable units
            ToggleGroups(selectableDefenseGroups, makeSelection: .Normal)
            
            // Ensure each attack threat is visible (normally this is set automatically when defense mode is set)
            //for eachThreat in eachGroup.conflicts {eachThreat.defenseApproach.hidden = false}
            
            return "TurnOnFeint"
            
        } else {
            
            // Turns on the selectable units
            ToggleGroups(selectableRetreatGroups, makeSelection: .Normal)
            
            return "TurnOnRetreat"
        }
    }
    
    func PostBattleRetreatOrSurrender() -> String {
            
        // Determine selectable retreat groups (everything in the locale)
        selectableRetreatGroups = SelectableGroupsForRetreat(activeThreat!.conflict)
        
        // Determines whether there is a forced retreat condition
        let (_, mustDefend) = CheckForcedRetreatOrDefend(activeThreat!)
        
        // Surrender Case
        if mustDefend == true {return "TurnOnSurrender"}
        else if selectableRetreatGroups.isEmpty {return "TurnOnSkip"}
        else {activeThreat!.retreatMode = true; ToggleGroups(selectableRetreatGroups, makeSelection: .Normal); return "TurnOnRetreat"}
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
    
    func RemoveArrows() {
        for each in orders {
            if each.order != .Move && each.order != .Retreat && each.order != .Feint {each.orderArrow?.removeFromParent()}
        }
    }
    
}

