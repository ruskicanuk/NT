//
//  Display.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-11-07.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

// MARK: Map Label Functions

// Map drawing and menu buttons
var NTMap:SKSpriteNode?

var commandLabel = UILabel()
var indLabel = UILabel()
var phasingLabel = UILabel()
var actingLabel = UILabel()
var turnLabel = UILabel()
var alliedMoraleLabel = UILabel()
var frenchMoraleLabel = UILabel()

//var NTMenu:SKNode?
var undoButton:UIStateButton!
//var undoButton:SKSpriteNode?
var endTurnButton:UIStateButton!
//var terrainButton:SKSpriteNode?
var terrainButton:UIStateButton!
var fastfwdButton:UIStateButton!
var rewindButton:UIStateButton!
//var hideCommandsButton:SKSpriteNode?
var corpsMoveButton:UIStateButton!
var corpsDetachButton:UIStateButton!
var corpsAttachButton:UIStateButton!
var independentButton:UIStateButton!
var retreatButton:UIStateButton!
var commitButton:UIStateButton!
var guardButton:UIStateButton!

// Selectors
//var corpsMoveSelector:SpriteSelector?
//var corpsDetachSelector:SpriteSelector?
//var corpsAttachSelector:SpriteSelector?
//var independentSelector:SpriteSelector?
//var retreatSelector:SpriteSelector?
//var commitSelector:SpriteSelector?
//var endTurnSelector:SpriteSelector?
//var guardSelector:SpriteSelector?

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

    /*
    indLabel.fontSize = 20*mapScaleFactor
    indLabel.fontColor = SKColor.blackColor()
    NTMap!.addChild(indLabel)
    indLabel.position = CGPoint(x: 100, y: 100)
    
    actingLabel.fontSize = 20*mapScaleFactor
    actingLabel.fontColor = SKColor.blackColor()
    NTMap!.addChild(actingLabel)
    actingLabel.position = CGPoint(x: -140.0, y: -280.0)
    
    turnLabel.fontSize = 20*mapScaleFactor
    turnLabel.fontColor = SKColor.blackColor()
    NTMap!.addChild(turnLabel)
    turnLabel.position = CGPoint(x: -140.0, y: -300.0)
    
    alliedMoraleLabel.fontSize = 20*mapScaleFactor
    alliedMoraleLabel.fontColor = SKColor.blackColor()
    NTMap!.addChild(alliedMoraleLabel)
    alliedMoraleLabel.position = CGPoint(x: -140.0, y: -320.0)
    
    frenchMoraleLabel.fontSize = 20*mapScaleFactor
    frenchMoraleLabel.fontColor = SKColor.blackColor()
    NTMap!.addChild(frenchMoraleLabel)
    frenchMoraleLabel.position = CGPoint(x: -140.0, y: -340.0)
    */
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
    turnLabel.text = "Turn: \(manager!.turn) Phase: \(manager!.phaseOld.ID)"
}

func updateMoraleLabel() {
    alliedMoraleLabel.text = "Allied Morale: \(manager!.morale[.Austrian]!)"
    frenchMoraleLabel.text = "French Morale: \(manager!.morale[.French]!)"
}
