//
//  Display.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-11-07.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

/*
Z-positions
Menu: 2000
Elevated (swipe queue): 1000
Units: 100
SKNodes (Commands): 0
Locations: 200
*/

// MARK: Global Constants

var mapScaleFactor:CGFloat = 1.0

let imageNamesNormal = [133.0:"AUINF3", 132.0:"AUINF2", 131.0:"AUINF1", 123.0:"AUCAV3", 122.0:"AUCAV2", 121.0:"AUCAV1", 111.0:"AUART1", 143.0:"AUINFEL3", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 151.4:"Kollowrath", 233.0:"FRINF3", 232.0:"FRINF2", 231.0:"FRINF1", 223.0:"FRCAV3", 222.0:"FRCAV2", 221.0:"FRCAV1", 211.0:"FRART1", 243.0:"FRINFEL3", 242.0:"FRINF2", 241.0:"FRINF1", 251.1:"St Hilaire", 251.2:"Vandamme", 251.3:"Bessieres", 251.4:"Legrand", 251.5:"Lannes"]

let imageNamesSelected = [133.0:"AUINF3 Selected", 132.0:"AUINF2 Selected", 131.0:"AUINF1 Selected", 123.0:"AUCAV3 Selected", 122.0:"AUCAV2 Selected", 121.0:"AUCAV1 Selected", 111.0:"AUART1 Selected", 143.0:"AUINFEL3 Selected", 151.1:"Bagration Selected", 151.2:"Dokhturov Selected", 151.3:"Constantine Selected", 151.4:"Kollowrath Selected", 233.0:"FRINF3 Selected", 232.0:"FRINF2 Selected", 231.0:"FRINF1 Selected", 223.0:"FRCAV3 Selected", 222.0:"FRCAV2 Selected", 221.0:"FRCAV1 Selected", 211.0:"FRART1 Selected", 243.0:"FRINFEL3 Selected", 251.1:"St Hilaire Selected", 251.2:"Vandamme Selected", 251.3:"Bessieres Selected", 251.4:"Legrand Selected", 251.5:"Lannes Selected"]

let imageNamesGreyedOut = [133.0:"AUINF3 Greyed", 132.0:"AUINF2 Greyed", 131.0:"AUINF1 Greyed", 123.0:"AUCAV3 Greyed", 122.0:"AUCAV2 Greyed", 121.0:"AUCAV1 Greyed", 111.0:"AUART1 Greyed", 143.0:"AUINFEL3 Greyed", 151.1:"Bagration Greyed", 151.2:"Dokhturov Greyed", 151.3:"Constantine Greyed", 151.4:"Kollowrath Greyed", 233.0:"FRINF3 Greyed", 232.0:"FRINF2 Greyed", 231.0:"FRINF1 Greyed", 223.0:"FRCAV3 Greyed", 222.0:"FRCAV2 Greyed", 221.0:"FRCAV1 Greyed", 211.0:"FRART1 Greyed", 243.0:"FRINFEL3 Greyed", 251.1:"St Hilaire Greyed", 251.2:"Vandamme Greyed", 251.3:"Bessieres Greyed", 251.4:"Legrand Greyed", 251.5:"Lannes Greyed"]

// Split this into "Off" and "Greyed out"
let imageNamesOff = [133.0:"AUback", 132.0:"AUback", 131.0:"AUback", 123.0:"AUback", 122.0:"AUback", 121.0:"AUback", 111.0:"AUback", 143.0:"AUback", 151.1:"Bagration", 151.2:"Dokhturov", 151.3:"Constantine", 151.4:"Kollowrath", 233.0:"FRback", 232.0:"FRback", 231.0:"FRback", 223.0:"FRback", 222.0:"FRback", 221.0:"FRback", 211.0:"FRback", 243.0:"FRback", 242.0:"FRback", 241.0:"FRback", 251.1:"St Hilaire", 251.2:"Vandamme", 251.3:"Bessieres", 251.4:"Legrand", 251.5:"Lannes"]

let unitHeight:CGFloat = 9.5/1.5
let unitWidth:CGFloat = 56/1.5
let commandOffset:CGFloat = 2.0
let editorPixelWidth:CGFloat = 1267.2

var activeGroupConflict:GroupConflict?
var activeConflict:Conflict? {
    didSet {
        if activeGroupConflict != nil {
            for eachConflict in activeGroupConflict!.conflicts {eachConflict.defenseApproach.approachSelector!.toggleSelection()}
        }

        if activeConflict == nil {
            activeGroupConflict = nil
            battleMenu.hidden = true
        }
        else {
            activeGroupConflict = activeConflict!.parentGroupConflict
            activeConflict!.defenseApproach.approachSelector!.turnColor("Purple")
            
            battleMenu.hidden = false
            updateBattleLabel(activeConflict!, initial: manager!.phaseNew == .SelectCounterGroup)
        }
    }
}

// MARK: Global Enums

enum ReviewState {case Front, Middle, Back}

enum SelState {
    case On, Off, Option, Normal, NotAvail, Possible
}

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
    
    mutating func Switch() {
        
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

// MARK: Global Extensions

extension Int {
    
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / 180.0
    }
}

//Not used currently
extension Array {
    
    // Returns the first element satisfying the predicate, or `nil`
    // if there is no matching element.
    func findFirstMatching<L : BooleanType>(predicate: Element -> L) -> Element? {
        for item in self {
            if predicate(item) {
                return item // found
            }
        }
        return nil // not found
    }
}

extension Array where Element : Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating func removeObject(object : Generator.Element) {
        if let index = self.indexOf(object) {
            self.removeAtIndex(index)
        }
    }
}

// MARK: Global Functions

func Delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

// MARK: Map, labels and buttons

// Map drawing and menu buttons
var NTMap:SKSpriteNode!

var commandLabel = UILabel()
var indLabel = UILabel()
var phasingLabel = UILabel()
var actingLabel = UILabel()
var turnLabel = UILabel()
var alliedMoraleLabel = UILabel()
var frenchMoraleLabel = UILabel()
var playbackStateLabel = UILabel()
var phantomOrderCorps = UILabel()
var phantomOrderInd = UILabel()
var zoomLabel = UILabel()
var battleResult = UILabel()
var battleWinner = UILabel()
var blocks = UIImage()

var undoButton:UIStateButton!
var endTurnButton:UIStateButton!
var terrainButton:UIStateButton!
var fastfwdButton:UIStateButton!
var rewindButton:UIStateButton!
var corpsMoveButton:UIStateButton!
var corpsDetachButton:UIStateButton!
var corpsAttachButton:UIStateButton!
var independentButton:UIStateButton!
var retreatButton:UIStateButton!
var commitButton:UIStateButton!
var guardButton:UIStateButton!
var repeatAttackButton:UIStateButton!

// Set up the labels on the labelMenu
func setupCommandDashboard() {
    
    turnLabel.font = UIFont(name: turnLabel.font.fontName, size: 12)
    turnLabel.textColor = SKColor.blackColor()
    turnLabel.frame = CGRect(x: 5, y: 5, width: 200, height: 15)
    labelMenu.addSubview(turnLabel)
    
    phasingLabel.font = UIFont(name: phasingLabel.font.fontName, size: 12)
    phasingLabel.textColor = SKColor.blackColor()
    phasingLabel.frame = CGRect(x: 5, y: 20, width: 200, height: 15)
    labelMenu.addSubview(phasingLabel)
    
    actingLabel.font = UIFont(name: actingLabel.font.fontName, size: 12)
    actingLabel.textColor = SKColor.blackColor()
    actingLabel.frame = CGRect(x: 5, y: 35, width: 200, height: 15)
    labelMenu.addSubview(actingLabel)
    
    commandLabel.font = UIFont(name: commandLabel.font.fontName, size: 12)
    commandLabel.textColor = SKColor.blackColor()
    commandLabel.frame = CGRect(x: 5, y: 50, width: 200, height: 15)
    labelMenu.addSubview(commandLabel)
    
    indLabel.font = UIFont(name: indLabel.font.fontName, size: 12)
    indLabel.textColor = SKColor.blackColor()
    indLabel.frame = CGRect(x: 5, y: 65, width: 200, height: 15)
    labelMenu.addSubview(indLabel)
    
    alliedMoraleLabel.font = UIFont(name: alliedMoraleLabel.font.fontName, size: 12)
    alliedMoraleLabel.textColor = SKColor.blackColor()
    alliedMoraleLabel.frame = CGRect(x: 5, y: 80, width: 200, height: 15)
    labelMenu.addSubview(alliedMoraleLabel)
    
    frenchMoraleLabel.font = UIFont(name: frenchMoraleLabel.font.fontName, size: 12)
    frenchMoraleLabel.textColor = SKColor.blackColor()
    frenchMoraleLabel.frame = CGRect(x: 5, y: 95, width: 200, height: 15)
    labelMenu.addSubview(frenchMoraleLabel)
    
    playbackStateLabel.font = UIFont(name: playbackStateLabel.font.fontName, size: 12)
    playbackStateLabel.textColor = SKColor.blackColor()
    playbackStateLabel.frame = CGRect(x: 5, y: 110, width: 200, height: 15)
    labelMenu.addSubview(playbackStateLabel)
    
    phantomOrderCorps.font = UIFont(name: phantomOrderCorps.font.fontName, size: 12)
    phantomOrderCorps.textColor = SKColor.blackColor()
    phantomOrderCorps.frame = CGRect(x: 5, y: 125, width: 200, height: 15)
    labelMenu.addSubview(phantomOrderCorps)
    
    phantomOrderInd.font = UIFont(name: phantomOrderInd.font.fontName, size: 12)
    phantomOrderInd.textColor = SKColor.blackColor()
    phantomOrderInd.frame = CGRect(x: 5, y: 140, width: 200, height: 15)
    labelMenu.addSubview(phantomOrderInd)
    
    zoomLabel.font = UIFont(name: zoomLabel.font.fontName, size: 12)
    zoomLabel.textColor = SKColor.blackColor()
    zoomLabel.frame = CGRect(x: 5, y: 155, width: 200, height: 15)
    labelMenu.addSubview(zoomLabel)
    
    battleResult.font = UIFont(name: battleResult.font.fontName, size: 12)
    battleResult.textColor = SKColor.blackColor()
    battleResult.frame = CGRect(x: 5, y: 5, width: 100, height: 15)
    battleMenu.addSubview(battleResult)
    
    battleWinner.font = UIFont(name: battleWinner.font.fontName, size: 12)
    battleWinner.textColor = SKColor.blackColor()
    battleWinner.frame = CGRect(x: 5, y: 20, width: 100, height: 15)
    battleMenu.addSubview(battleWinner)
    
}

// Refreshes the labels on the labelMenu
func updateBattleLabel(theConflict:Conflict, initial:Bool) {
    if !theConflict.realAttack {
        battleResult.text = ""
        battleWinner.text = ""
        return}
    if initial {
        battleResult.text = "Initial Result: \(theConflict.initialResult)"
        battleWinner.text = "Winner: \(theConflict.conflictInitialWinner)"
    } else {
        battleResult.text = "Final Result: \(theConflict.finalResult)"
        battleWinner.text = "Winner: \(theConflict.conflictFinalWinner)"
    }
}

func updateCommandLabel() {
    commandLabel.text = "Corps Commands: \(manager!.corpsCommandsAvail)"
}

func updateIndLabel() {
    indLabel.text = "Ind. Commands: \(manager!.indCommandsAvail)"
}

func updatePhasingLabel() {
    phasingLabel.text = "Phasing Player: \(manager!.phasingPlayer.ID)"
}

func updateActingLabel() {
    actingLabel.text = "Acting Player: \(manager!.actingPlayer.ID)"
}

func updateTurnLabel() {
    turnLabel.text = "Turn: \(manager!.turn) Phase: \(manager!.phaseNew)"
}

func updateMoraleLabel() {
    alliedMoraleLabel.text = "Allied Morale: \(manager!.morale[.Austrian]!)"
    frenchMoraleLabel.text = "French Morale: \(manager!.morale[.French]!)"
}

func updatePlaybackState() {
    playbackStateLabel.text = "Playback: \(manager!.statePointTracker)"
}

func updatePhantomLabelState() {
    phantomOrderCorps.text = "Corp Phantoms: \(manager!.phantomCorpsCommand)"
    phantomOrderInd.text = "Ind Phantoms: \(manager!.phantomIndCommand)"
}

func updateZoomLevel() {
    zoomLabel.text = "Unit Selection: \(zoomedMode)"
}