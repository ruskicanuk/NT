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

let imageNamesNormal = [133.0:"AUINF3", 132.0:"AUINF2", 131.0:"AUINF1", 123.0:"AUCAV3", 122.0:"AUCAV2", 121.0:"AUCAV1", 111.0:"AUART1", 143.0:"AUINFEL3", 142.0:"AUINF2", 141.0:"AUINF1", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 233.0:"FRINF3", 232.0:"FRINF2", 231.0:"FRINF1", 223.0:"FRCAV3", 222.0:"FRCAV2", 221.0:"FRCAV1", 211.0:"FRART1", 243.0:"FRINFEL3", 242.0:"FRINF2", 241.0:"FRINF1", 251.1:"St Hilaire", 251.2:"Vandamme"]

let imageNamesSelected = [133.0:"AUCAV3H", 132.0:"AUCAV3H", 131.0:"AUCAV3H", 123.0:"AUCAV3H", 122.0:"AUCAV3H", 121.0:"AUCAV3H", 111.0:"AUCAV3H", 142.0:"AUCAV3H", 141.0:"AUCAV3H", 143.0:"AUCAV3H", 151.1:"BagrationH", 151.2:"Dokhturov", 151.3:"Constantine", 233.0:"FRINF2H", 232.0:"FRINF2H", 231.0:"FRINF2H", 223.0:"FRINF2H", 222.0:"FRINF2H", 221.0:"FRINF2H", 211.0:"FRINF2H", 243.0:"FRINF2H", 242.0:"FRINF2H", 241.0:"FRINF2H", 251.1:"DavoutH", 251.2:"DavoutH"]

let imageNamesNotSelectable = [133.0:"AUback", 132.0:"AUback", 131.0:"AUback", 123.0:"AUback", 122.0:"AUback", 121.0:"AUback", 111.0:"AUback", 143.0:"AUback", 142.0:"AUback", 141.0:"AUback", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 233.0:"FRback", 232.0:"FRback", 231.0:"FRback", 223.0:"FRback", 222.0:"FRback", 221.0:"FRback", 211.0:"FRback", 243.0:"FRback", 242.0:"FRback", 241.0:"FRback", 251.1:"St Hilaire", 251.2:"Vandamme"]

let imageNamesBlank:[Allegience:String] = [.Austrian:"AUback", .French:"FRback"]

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

enum newGamePhase {
    
    case PreGame, Move, Defend, Commit, Feint
    
    init (initPhase:String = "Move") {
        switch initPhase {case "PreGame": self = .PreGame default: self = .Move}
    }
    
    // Changes the phase returns (whether to switch the acting player, whether to advance the turn)
    mutating func NextPhase (fight:Bool = true) -> (Bool, Bool) {
    
        var secondImpulse:Bool = false
        var switchActing:(Bool, Bool) = (true, false)
        
        switch (self, secondImpulse, fight) {
        
            // Pre-game setup
            case (.PreGame, false, _): secondImpulse = true
            case (.PreGame, true, _): self = .Move; secondImpulse = false; switchActing = (true, true)
            
            // No attacks or feints - switches player, keeps same phase
            case (.Move, false, false): secondImpulse = true
            case (.Move, true, false): secondImpulse = false; switchActing = (true, true)
            
            // Move phase ends with some hostility, switch to defend phase
            case (.Move, _, true): self = .Defend
                
            // Defender punts it back to the attacker (always attacker choice available during commit)
            case (.Defend, _, _): self = .Commit

            // Attacker executes feints, commits on attacks
            case (.Commit, _, _): self = .Feint // Valid defense choices
            
            // ATTACK PROCESSING
                
            // Next player's move
            case (.Feint, _, _): self = .Move; switchActing = (false, true)
                
            default:
                break
                
        }
        
        return switchActing
    }
}

enum oldGamePhase {
    
    case PreGame, Move, FeintThreat, NormalThreat, FTDefend, NTDefend, PreRetreat, FeintMove, FeintRespond, RealAttack, LeadingDefense, Commit, PostRetreat, ApproachResponse
    
    var ID:String {
        switch self {
            case .PreGame: return "PreGame"
            case .FeintThreat: return "FeintThreat"
            case .NormalThreat: return "NormalThreat"
            case .FTDefend: return "FTDefend"
            case .NTDefend: return "NTDefend"
            case .PreRetreat: return "PreRetreat"
            case .FeintMove: return "FeintMove"
            case .FeintRespond: return "FeintRespond"
            case .RealAttack: return "RealAttack"
            case .LeadingDefense: return "LeadingDefense"
            case .Commit: return "Commit"
            case .PostRetreat: return "PostRetreat"
            case .ApproachResponse: return "ApproachResponse"
            default: return "Move"
        }
    }
    
    init (initPhase:String = "Move") {
        switch initPhase {case "PreGame": self = .PreGame default: self = .Move}
    }
    
    // Changes the phase based on fight/flight stance and returns whether to switch the acting player
    mutating func NextPhase(fight:Int = 1, reverse:Bool = false) -> Bool {
    
        var switchActing:Bool = true
        
        if !reverse {

            switch (self, fight) {
            
            // Pre-game move (T/F on whether to advance to move)
            //case (.PreGame, false):
            //case (.PreGame, true): self = .Move
                
            // Attacker move
            case (.Move, 1): self = .NormalThreat
            case (.Move, 2): self = .FeintThreat
            
            // Defender move
            case (.NormalThreat, 1): self = .NTDefend
            case (.NormalThreat, 2): self = .PreRetreat
            case (.FeintThreat, 1): self = .FTDefend
            case (.FeintThreat, 2): self = .PreRetreat
            
            // Attacker move
            case (.NTDefend, 1): self = .RealAttack
            case (.NTDefend, 2): self = .FeintMove
            case (.FTDefend, _): self = .FeintMove
            case (.PreRetreat, _): self = .Move; switchActing = false
                
            // Defender move
            case (.RealAttack, _): self = .LeadingDefense
            case (.FeintMove, _): self = .FeintRespond

            // Attacker move
            case (.LeadingDefense, _): self = .Commit
            case (.FeintRespond, _): self = .Move; switchActing = false

            // ATTACK PROCESSING
                
            // Defender move (true = attacker won)
            case (.Commit, 1): self = .PostRetreat
            case (.Commit, 2): self = .ApproachResponse
                
            // Attacker move
            case (.PostRetreat, _): self = .Move; switchActing = false
                
            default:
                break
                
            }
        
        } else {
            
            switch (self, fight) {
                
            // Pre-game move (T/F on whether to advance to move)
            //case (.PreGame, false):
            //case (.PreGame, true): self = .Move
                
            // Attacker move
            case (.NormalThreat, _): self = .Move
            case (.FeintThreat, _): self = .Move
                
            // Defender move
            case (.NTDefend, _): self = .NormalThreat
            case (.PreRetreat, 1): self = .NormalThreat
            case (.FTDefend, _): self = .FeintThreat
            case (.PreRetreat, 2): self = .FeintThreat
                
            // Attacker move
            case (.RealAttack, _): self = .NTDefend
            case (.FeintMove, 1): self = .NTDefend
            case (.FeintMove, 2): self = .FTDefend
            case (.Move, 2): self = .PreRetreat; switchActing = false
                
            // Defender move
            case (.LeadingDefense, _): self = .RealAttack
            case (.FeintRespond, _): self = .FeintMove
                
            // Attacker move
            case (.Commit, _): self = .LeadingDefense
            case (.Move, 1): self = .FeintRespond; switchActing = false
                
            // ATTACK PROCESSING
                
            // Defender move (true = attacker won)
            case (.PostRetreat, 1): self = .Commit
            case (.ApproachResponse, 2): self = .Commit
                
            // Attacker move
            case (.Move, 3): self = .PostRetreat; switchActing = false
                
            default:
                break
                
            }
        }
        
        return switchActing
    }
}

// MARK: Game Manager

class GameManager {

    var gameCommands:[Allegience:[Command]] = [.Austrian:[], .French:[]]
    var selectableDefenseGroups:[Group] = []
    var selectableRetreatGroups:[Group] = []
    var currentGroupsSelected:[Group] = []
    var selectionRetreatReserves:[Reserve] = [] // Stores viable retreat reserves for the current selection
    //var defendingGroups:[Approach:[Group]]? // Used to store defenders for a current attack
    //var attackingGroups:[Approach:[Group]]?
    var reserveThreats:[GroupConflict] = []
    var approachThreats:[Approach:Conflict] = [:]
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
    var day:Int = 1
    var night:Bool = false
    var turn:Int = 1 {
        didSet {
            if turn == 12 {night = true} else if night == true {night = false}
            if turn > 12 {day = 2} else {day = 1}
            updateTurnLabel()
        }
    }
    
    // Current phase
    var phaseNew:newGamePhase = newGamePhase()
    
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
    
    // Morale
    var auMoraleMax:Int = 27
    var frMoraleMax:Int = 23
    var auMorale:Int = 27
    var frMorale:Int = 23
    
    var frReinforcements:Bool = false
    var auHeavyCavUsed:Bool = false
    var frHeavyCavUsed:Bool = false
    var auGuardFailed:Bool = false
    var frGuardFailed:Bool = false
    var auGuardUsed:Bool = false
    var frGuardUsed:Bool = false
    
    var heavyCavCommitCost:Int = 2
    var guardCommitCost:Int = 4
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
        
        let phaseChange:Bool = phaseOld.NextPhase(fight, reverse: reverse) // Moves us to the next phase, returns true if need to swith acting player
        if phaseChange {SideSwith(); actingPlayer.Switch()}
        if orders.last != nil {orders.last?.unDoable = false}
        
        // Set the phase-class (enums giving me hell on multi case selections)
        let thePhaseClass:String!
        if phaseOld == .PreGame || phaseOld == .Move {thePhaseClass = "Move"}
        else if phaseOld == .FeintThreat || phaseOld == .NormalThreat {thePhaseClass = "Threat"}
        else if phaseOld == .NTDefend || phaseOld == .FTDefend || phaseOld == .PreRetreat {thePhaseClass = "Commit"}
        else {thePhaseClass = "Move"}
        
        switch (thePhaseClass) {
        
        case "Move":
            
            ToggleCommands(gameCommands[actingPlayer]!, makeSelectable:true)
        
        case ("Threat"):
            
            // Setup the threat-groups and setup the retreat and defense selection groups @ Will need to go through all orders in "new version"
            SetupThreats()
            
            // Return the code (whether forced retreat / defend)
            return ResetRetreatDefenseSelection()
            
        default:
            break
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
        
        } else if phaseOld != .PreGame {
            corpsCommandsAvail = player2CorpsCommands
            indCommandsAvail = player2IndCommands
        }
        
        // Finished pre-game
        if phaseOld == .PreGame && phasingPlayer != player1 {phaseOld = .Move}
        
        // Any Move turn, set units available to defend
        if phaseOld == .Move {
            
            // Reset reserve state
            for eachReserve in reserves {eachReserve.ResetReserveState()}
            
            for eachCommand in gameCommands[actingPlayer]! {
                //eachCommand.availableToDefend = eachCommand.units.filter{$0.unitType != .Ldr}
                eachCommand.moveNumber = 0
                eachCommand.movedVia = .None
                for eachUnit in eachCommand.activeUnits {if eachUnit.unitType != .Ldr {eachUnit.alreadyDefended = false}}
            }
            for eachCommand in gameCommands[actingPlayer.Other()!]! {
                //eachCommand.availableToDefend = eachCommand.units
                eachCommand.moveNumber = 0
                eachCommand.movedVia = .None
                for eachUnit in eachCommand.activeUnits {if eachUnit.unitType != .Ldr {eachUnit.alreadyDefended = false}}
            }
        }
        
        // Reset conflict arrays
        selectableDefenseGroups = []
        selectableRetreatGroups = []
        currentGroupsSelected = []
        selectionRetreatReserves = []
        reserveThreats = []
        approachThreats = [:]
        
        // Always switch side, phasing and acting player
        SideSwith()
        if orders.last != nil {orders.last?.unDoable = false}
        phasingPlayer.Switch()
        actingPlayer.Switch()
        
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
    
    // MARK: Manager Support Functions
    
    func turnID() -> Int {
        
        if phasingPlayer == player1 {
            return (turn+1)
        } else {
            return (turn+2)
        }
    }
    
    func setupCommandDashboard() {
        
        //phasingLabel.text = "Phasing Player: \(self.phasingPlayer)"
        phasingLabel.fontSize = 20*mapScaleFactor
        phasingLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(phasingLabel)
        phasingLabel.position = CGPoint(x: -80.0, y: -220.0)
        
        // Add the commands available dash-board
        //commandLabel.text = "Corps Commands: \(self.corpsCommandsAvail)"
        commandLabel.fontSize = 20*mapScaleFactor
        commandLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(commandLabel)
        commandLabel.position = CGPoint(x: -80.0, y: -240.0)
        
        //indLabel.text = "Ind. Commands: \(self.indCommandsAvail)"
        indLabel.fontSize = 20*mapScaleFactor
        indLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(indLabel)
        indLabel.position = CGPoint(x: -80.0, y: -260.0)
        
        //actingLabel.text = "Acting Player: \(self.actingPlayer)"
        actingLabel.fontSize = 20*mapScaleFactor
        actingLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(actingLabel)
        actingLabel.position = CGPoint(x: -80.0, y: -280.0)
        
        //turnLabel.text = "Turn: \(self.turn) Phase: \(self.phaseOld)"
        turnLabel.fontSize = 20*mapScaleFactor
        turnLabel.fontColor = SKColor.blackColor()
        drawOnNode!.addChild(turnLabel)
        turnLabel.position = CGPoint(x: -80.0, y: -300.0)
        
        //menu = theMenu
        //print(theMenu)
        // Initializes the labels
        phasingPlayer = player1
        actingPlayer = player1
        phaseOld = .PreGame
        corpsCommandsAvail = 0
        indCommandsAvail = 0
        
    }
    
    func SideSwith() {
        
        for eachCommand in gameCommands[manager!.actingPlayer]! {
            //eachCommand.userInteractionEnabled = false
            for eachUnit in eachCommand.activeUnits {
                if eachUnit.unitType != .Ldr {eachUnit.selected = .Off}
            }
        }
        
        for eachCommand in gameCommands[manager!.actingPlayer.Other()!]! {
            //eachCommand.userInteractionEnabled = true
            for eachUnit in eachCommand.activeUnits {
                if eachUnit.unitType != .Ldr {eachUnit.selected = .Normal}
            }
        }
    }
    
    // Populations the reserve threats
    func SetupThreats() {
        
        var index = self.orders.endIndex-1
        var theGroupConflicts:[Reserve:[Conflict]] = [:]

        repeat {
            
            // Break conditions
            if index < 0 {break}
            guard let theConflict = self.orders[index].theConflict else {break}
            
            //if !(self.orders[index].order == .FeintThreat || self.orders[index].order == .NormalThreat) {break}
        
            self.approachThreats[theConflict.defenseApproach] = theConflict
            
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
    
    }
    
    // Returns retreat mode (for the retreat selector)
    func ResetRetreatDefenseSelection () -> String {
        
        for eachGroup in reserveThreats {
            
            ToggleCommands(gameCommands[actingPlayer]!, makeSelectable:false)
            
            // Determine selectable defend groups (those which can defend)
            selectableDefenseGroups = SelectableGroupsFromConflict(eachGroup.conflicts[0])
            
            // Determine selectable retreat groups (everything in the locale)
            selectableRetreatGroups = SelectableGroupsForRetreat(eachGroup.conflicts[0]) // Get this to return available reserves
            
            // Determines whether there is a forced retreat condition
            (eachGroup.mustRetreat, eachGroup.mustDefend) = CheckForcedRetreatOrDefend(eachGroup)
            //print(eachGroup.mustRetreat)
            // Surrender Case
            if eachGroup.mustRetreat == true && eachGroup.mustDefend == true {eachGroup.retreatMode = true; return "TurnOnSurrender"}
            
            // If not surrender case and must retreat is on
            if eachGroup.mustRetreat {eachGroup.retreatMode = true}
            
            // After we finish all threats for a reserve, set the available move-to locations and toggle selectable groups on
            if !eachGroup.retreatMode { // All threats for a given reserve must be in the same initial threat-mode
                
                // Turns on the selectable units
                ToggleGroups(selectableDefenseGroups, makeSelection: .Normal)
                
                // Ensure each attack threat is visible (normally this is set automatically when defense mode is set)
                for eachThreat in eachGroup.conflicts {eachThreat.defenseApproach.hidden = false}
                
                return "TurnOnFeint"
                
            } else {
                
                // Turns on the selectable units
                ToggleGroups(selectableRetreatGroups, makeSelection: .Normal)
                
                return "TurnOnRetreat"
                
            }
        }
        return "TurnOnNothing"
    }
    
}







