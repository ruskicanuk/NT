//
//  Manager.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-25.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

// MARK: Game Global Constants

var mapScaleFactor:CGFloat = 1.0

let imageNamesNormal = [133.0:"AUINF3", 132.0:"AUINF2", 131.0:"AUINF1", 123.0:"AUCAV3", 122.0:"AUCAV2", 121.0:"AUCAV1", 111.0:"AUART1", 143.0:"AUINFEL3", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 233.0:"FRINF3", 232.0:"FRINF2", 231.0:"FRINF1", 223.0:"FRCAV3", 222.0:"FRCAV2", 221.0:"FRCAV1", 211.0:"FRART1", 243.0:"FRINFEL3", 242.0:"FRINF2", 241.0:"FRINF1", 251.1:"St Hilaire", 251.2:"Vandamme"]

let imageNamesSelected = [133.0:"AUINF3 Selected", 132.0:"AUINF2 Selected", 131.0:"AUINF1 Selected", 123.0:"AUCAV3 Selected", 122.0:"AUCAV2 Selected", 121.0:"AUCAV1 Selected", 111.0:"AUART1 Selected", 143.0:"AUINFEL3 Selected", 151.1:"Bagration Selected", 151.2:"Dokhturov Selected", 151.3:"Constantine Selected", 233.0:"FRINF3 Selected", 232.0:"FRINF2 Selected", 231.0:"FRINF1 Selected", 223.0:"FRCAV3 Selected", 222.0:"FRCAV2 Selected", 221.0:"FRCAV1 Selected", 211.0:"FRART1 Selected", 243.0:"FRINFEL3 Selected", 251.1:"St Hilaire Selected", 251.2:"Vandamme Selected"]

let imageNamesGreyedOut = [133.0:"AUINF3 Greyed", 132.0:"AUINF2 Greyed", 131.0:"AUINF1 Greyed", 123.0:"AUCAV3 Greyed", 122.0:"AUCAV2 Greyed", 121.0:"AUCAV1 Greyed", 111.0:"AUART1 Greyed", 143.0:"AUINFEL3 Greyed", 151.1:"Bagration Greyed", 151.2:"Dokhturov Greyed", 151.3:"Constantine Greyed", 233.0:"FRINF3 Greyed", 232.0:"FRINF2 Greyed", 231.0:"FRINF1 Greyed", 223.0:"FRCAV3 Greyed", 222.0:"FRCAV2 Greyed", 221.0:"FRCAV1 Greyed", 211.0:"FRART1 Greyed", 243.0:"FRINFEL3 Greyed", 251.1:"St Hilaire Greyed", 251.2:"Vandamme Greyed"]

// Split this into "Off" and "Greyed out"
let imageNamesOff = [133.0:"AUback", 132.0:"AUback", 131.0:"AUback", 123.0:"AUback", 122.0:"AUback", 121.0:"AUback", 111.0:"AUback", 143.0:"AUback", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 233.0:"FRback", 232.0:"FRback", 231.0:"FRback", 223.0:"FRback", 222.0:"FRback", 221.0:"FRback", 211.0:"FRback", 243.0:"FRback", 242.0:"FRback", 241.0:"FRback", 251.1:"St Hilaire", 251.2:"Vandamme"]

//let imageNamesBlank:[Allegience:String] = [.Austrian:"AUback", .French:"FRback"]

let unitHeight:CGFloat = 9.5/1.5
let unitWidth:CGFloat = 56/1.5
let commandOffset:CGFloat = 2.0

/*
Z-positions
Menu: 2000
Elevated (swipe queue): 1000
Units: 100
SKNodes (Commands): 0
Locations: 200
*/

// MARK: Game Types

enum ReviewState {case Front, Middle, Back}

enum Allegience {
    
    case Austrian, French, Neutral, Both
    
    var ID:String {
        switch self {
            case .Austrian: return "Austrian"
            case .French: return "French"
            case .Neutral: return "Neutral"
            case .Both: return "Both"
        }
    }
    
    // Returns true if paramater is the true opposite, otherwise false
    func Opposite(check:Allegience) -> Bool? {
        if self == .Neutral || check == .Neutral {return false}
        else if self == check {return false}
        else {return true}
    }
    
    mutating func Switch () {
        
        if self == .French {self = .Austrian}
        else if self == .Austrian {self = .French}
        
    }
    
    func Other() -> Allegience? {
        if self == .French {return .Austrian}
        else if self == .Austrian {return .French}
        else {return .Neutral}
    }
    
    func ContainsEnemy(check:Allegience) -> Bool {
        if self == .French {if check == .Austrian || check == .Both{return true}}
        else if self == .Austrian {if check == .French || check == .Both{return true}}
        return false
    }
}

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

/*

gameCommands
priorityLosses
priorityLeaderAndBattle

selectableDefenseGroups
selectableRetreatGroups
selectableAttackGroups
selectableAttackByRoadGroups
selectableAttackAdjacentGroups

currentGroupsSelected

repeatAttackGroup
repeatAttackMoveNumber

selectionRetreatReserves

activeThreat

*/


class GameManager {

    var gameCommands:[Allegience:[Command]] = [.Austrian:[], .French:[]]
    var priorityLosses:[Allegience:[Int]] = [.Austrian:[43, 23, 22, 21, 33, 32, 31], .French:[43, 23, 22, 21, 33, 32, 31]]
    var priorityLeaderAndBattle:[Allegience:[Int]] = [.Austrian:[33, 43, 23, 32, 22, 31, 21], .French:[33, 43, 23, 32, 22, 31, 21]]
    
    var selectableDefenseGroups:[Group] = []
    var selectableRetreatGroups:[Group] = []
    var selectableAttackGroups:[Group] = []
    var selectableAttackByRoadGroups:[Group] = []
    var selectableAttackAdjacentGroups:[Group] = []
    
    var currentGroupsSelected:[Group] = []
    //var locationsVisible:[Location] = []
    
    var repeatAttackGroup:Group? // Used to store the group for rare cases of repeat attacks along the rd
    var repeatAttackMoveNumber:Int?
    
    var selectionRetreatReserves:[Reserve] = [] // Stores viable retreat reserves for the current selection
    //var defendingGroups:[Approach:[Group]]? // Used to store defenders for a current attack
    //var attackingGroups:[Approach:[Group]]?
    //var reserveThreats:[GroupConflict] = []
    var activeThreat:GroupConflict?
    
    //var approachThreats:[Approach:Conflict] = [:]
    //var theThreatsRetreatStatus:[Reserve:Bool] = [:] // Stores which mode (retreat or defend) each threat is in
    //var defendingLeading
    
    var approaches = [Approach]()
    var reserves = [Reserve]()
    var orders = [Order]()
    var orderHistory:[Int:[Order]] = [:]
    
    // Phasing and acting player
    let player1:Allegience = .Austrian
   
    // Commands available
    let player1CorpsCommands:Int = 5
    let player1IndCommands:Int = 3
    var player2CorpsCommands:Int = 6
    let player2IndCommands:Int = 4
    
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
    
    // Current phase
    //var phaseNew:newGamePhase = newGamePhase()
    
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
    //var frIndCommandsAvail:Int = 0
    
    var commandLabel = SKLabelNode()
    var indLabel = SKLabelNode()
    var phasingLabel = SKLabelNode()
    var actingLabel = SKLabelNode()
    var turnLabel = SKLabelNode()
    var alliedMoraleLabel = SKLabelNode()
    var frenchMoraleLabel = SKLabelNode()
    
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
    
    // Refers to the menu
    var drawOnNode:SKNode?
    
    init(theMenu:SKNode) {
        drawOnNode = theMenu
    }
    
    // MARK: New Phase
    
    // Triggered by conflict commands (eg. moving into an enemy locale)
    func NewPhase(fight:Int, reverse:Bool = false, playback:Bool = false) -> String {

        // Increments phase if we aren't in play-back mode
        if playback {return "Playback"}
        
        let phaseChange = phaseOld.NextPhase(fight, reverse: reverse) // Moves us to the next phase, returns true if need to swith acting player
        if phaseChange {SideSwith(); actingPlayer.Switch()}
        if orders.last != nil {orders.last?.unDoable = false}
        
        /*
        let thePhaseClass:String!
        if phaseOld == .Setup || phaseOld == .Move {thePhaseClass = "Move"}
        else if phaseOld == .FeintThreat || phaseOld == .NormalThreat {thePhaseClass = "Threat"}
        else if phaseOld == .StoodAgainstNormalThreat || phaseOld == .StoodAgainstFeintThreat || phaseOld == .RetreatedBeforeCombat {thePhaseClass = "Commit"}
        else if phaseOld == .RealAttack {thePhaseClass = "DeclareLeading"}
        else if phaseOld == .DeclaredAttackers {thePhaseClass = "DeclareLeading"}
        //else if phaseOld == .DeclaredLeadingA {thePhaseClass = "DeclareLeading"}
        else if phaseOld == .FeintMove || phaseOld == .RealAttack {thePhaseClass = "Nothing"}
        else {thePhaseClass = "Nothing"}
        */
        
        switch (phaseOld) {
        
        case .Setup, .Move:
            
            // Updates the selected status of the game commands generally after a battle
            for eachCommand in gameCommands[actingPlayer]! {
                for eachUnit in eachCommand.activeUnits {
                    eachUnit.updateSelectedStatus()
                }
                CheckForOneBlockCorps(eachCommand)
            }
            
            for each in orders {
                if each.order != .Move && each.order != .Retreat && each.order != .Feint {each.orderArrow?.removeFromParent()}
            }
            ResetManagerState()
            //ToggleCommands(gameCommands[actingPlayer]!, makeSelectable:true)
        
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
        SideSwith()
        if orders.last != nil {orders.last?.unDoable = false}
        phasingPlayer.Switch()
        actingPlayer.Switch()
        
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

    // MARK: Property Observer functions
    
    func updateCommandLabel() {
        commandLabel.text = "Corps Commands: \(self.corpsCommandsAvail)"
    }
    
    func updateIndLabel() {
        indLabel.text = "Ind. Commands: \(self.indCommandsAvail)"
    }
    
    func updatePhasingLabel() {
        phasingLabel.text = "Phasing Player: \(self.phasingPlayer.ID)"
    }
    
    func updateActingLabel() {
        actingLabel.text = "Acting Player: \(self.actingPlayer.ID)"
    }
    
    func updateTurnLabel() {
        turnLabel.text = "Turn: \(self.turn) Phase: \(self.phaseOld.ID)"
    }
    
    func updateMoraleLabel() {
        alliedMoraleLabel.text = "Allied Morale: \(self.morale[.Austrian]!)"
        frenchMoraleLabel.text = "French Morale: \(self.morale[.French]!)"
    }
    
    // MARK: Manager Support Functions
    
    func turnID() -> Int {
        
        if phasingPlayer == player1 {
            return (turn+1)
        } else {
            return (turn+2)
        }
    }
    
    func setupCommandDashboard() {
        
        phasingLabel.fontSize = 20*mapScaleFactor
        phasingLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(phasingLabel)
        phasingLabel.position = CGPoint(x: -140.0, y: -220.0)
        
        commandLabel.fontSize = 20*mapScaleFactor
        commandLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(commandLabel)
        commandLabel.position = CGPoint(x: -140.0, y: -240.0)
        
        indLabel.fontSize = 20*mapScaleFactor
        indLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(indLabel)
        indLabel.position = CGPoint(x: -140.0, y: -260.0)
        
        actingLabel.fontSize = 20*mapScaleFactor
        actingLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(actingLabel)
        actingLabel.position = CGPoint(x: -140.0, y: -280.0)
        
        turnLabel.fontSize = 20*mapScaleFactor
        turnLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(turnLabel)
        turnLabel.position = CGPoint(x: -140.0, y: -300.0)
        
        alliedMoraleLabel.fontSize = 20*mapScaleFactor
        alliedMoraleLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(alliedMoraleLabel)
        alliedMoraleLabel.position = CGPoint(x: -140.0, y: -320.0)
        
        frenchMoraleLabel.fontSize = 20*mapScaleFactor
        frenchMoraleLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(frenchMoraleLabel)
        frenchMoraleLabel.position = CGPoint(x: -140.0, y: -340.0)
        
        updateMoraleLabel()
        
        phasingPlayer = player1
        actingPlayer = player1
        phaseOld = .Setup
        corpsCommandsAvail = 0
        indCommandsAvail = 0
        
    }
    
    func SideSwith() {
        
        for eachCommand in gameCommands[manager!.actingPlayer]! {
            for eachUnit in eachCommand.activeUnits {
                eachUnit.selected = .Off
            }
        }
        
        for eachCommand in gameCommands[manager!.actingPlayer.Other()!]! {
            for eachUnit in eachCommand.activeUnits {
                eachUnit.selected = .Normal
            }
        }
    }
    
    // Populations the reserve threats
    func SetupThreat() {
        
        let index = self.orders.endIndex-1
        //var theGroupConflicts:[Reserve:[Conflict]] = [:]
        //self.reserveThreats = []
        
        //repeat {
            
            // Break conditions
       //     if index < 0 {break}
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
            //self.approachThreats[theConflict.defenseApproach] = theConflict
       /*
            if theGroupConflicts[theConflict.defenseReserve] == nil {
                theGroupConflicts[theConflict.defenseReserve] = [theConflict]
            } else {
                theGroupConflicts[theConflict.defenseReserve]! += [theConflict]
            }
            
            index--
            
        } while true
        
        for (reserve, theConflicts) in theGroupConflicts {
            self.reserveThreats += [GroupConflict(passReserve: reserve, passConflicts: theConflicts)]
        }
        */
    
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
    
}







