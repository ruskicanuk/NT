//
//  GameSetup.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 9/30/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit
import UIKit

var frenchAIChoice:UIStateButton!
var austrianAIChoice:UIStateButton!
var noAIChoice:UIStateButton!
var bothAIChoice:UIStateButton!

class SetupScene: SKScene {

    let singlePlayer = SKSpriteNode(imageNamed: "singleplayer")
    let multiPlayer = SKSpriteNode(imageNamed: "multiplayer")
    
    let singlePlayerNew = SKSpriteNode(imageNamed: "newgame")
    let multiPlayerNew = SKSpriteNode(imageNamed: "newgame")

    let singlePlayerLoad = SKSpriteNode(imageNamed: "loadgame")
    let multiPlayerLoad = SKSpriteNode(imageNamed: "loadgame")
    
    var buttonSpacing:CGFloat = 50
    var viewController:GameViewController!
    
    override func didMoveToView(view: SKView) {
    
        /* Setup your scene here */
        loadButtons()
        //startGame() // #### REMOVE LATER, to speed up testing ####
    }
    
    //this will load  buttons
    func loadButtons()
    {
        singlePlayer.position = CGPointMake(CGRectGetMidX(self.frame) - buttonSpacing, CGRectGetMidY(self.frame) + 40)
        self.addChild(singlePlayer)
        multiPlayer.position = CGPointMake(CGRectGetMidX(self.frame) - buttonSpacing, CGRectGetMidY(self.frame) - 40)
        self.addChild(multiPlayer)

        singlePlayerNew.position = CGPointMake(CGRectGetMidX(self.frame) + 2 * buttonSpacing, CGRectGetMidY(self.frame) + 40)
        self.addChild(singlePlayerNew)
        multiPlayerNew.position = CGPointMake(CGRectGetMidX(self.frame) + 2 * buttonSpacing, CGRectGetMidY(self.frame) - 40)
        self.addChild(multiPlayerNew)
        
        singlePlayerLoad.position = CGPointMake(CGRectGetMidX(self.frame) + 3 * buttonSpacing, CGRectGetMidY(self.frame) + 40)
        self.addChild(singlePlayerLoad)
        multiPlayerLoad.position = CGPointMake(CGRectGetMidX(self.frame) + 3 * buttonSpacing, CGRectGetMidY(self.frame) - 40)
        self.addChild(multiPlayerLoad)
        
        // AI Selections for testing
        
        let mainMenuScaleFactor:CGFloat = 1.0
        var topPosition:CGFloat = 5*mainMenuScaleFactor
        var rightPosition:CGFloat = 5*mainMenuScaleFactor
        
        topPosition += 500
        rightPosition += 300
        
        frenchAIChoice = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, 100*mainMenuScaleFactor, 20*mainMenuScaleFactor))
        frenchAIChoice.backgroundColor = UIColor.blueColor()
        frenchAIChoice.addTarget(self, action:#selector(SetupScene.frenchAIChoiceAction) , forControlEvents: UIControlEvents.TouchUpInside)
        self.view!.addSubview(frenchAIChoice)
        
        rightPosition += 100*mainMenuScaleFactor + 10*mainMenuScaleFactor
        
        austrianAIChoice = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, 100*mainMenuScaleFactor, 20*mainMenuScaleFactor))
        austrianAIChoice.backgroundColor = UIColor.redColor()
        austrianAIChoice.addTarget(self, action:#selector(SetupScene.austrianAIChoiceAction) , forControlEvents: UIControlEvents.TouchUpInside)
        self.view!.addSubview(austrianAIChoice)
        
        rightPosition += 100*mainMenuScaleFactor + 10*mainMenuScaleFactor
        
        bothAIChoice = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, 100*mainMenuScaleFactor, 20*mainMenuScaleFactor))
        bothAIChoice.backgroundColor = UIColor.purpleColor()
        bothAIChoice.addTarget(self, action:#selector(SetupScene.bothAIChoiceAction) , forControlEvents: UIControlEvents.TouchUpInside)
        self.view!.addSubview(bothAIChoice)
        
        rightPosition += 100*mainMenuScaleFactor + 10*mainMenuScaleFactor
        
        noAIChoice = UIStateButton.init(initialState: .Normal, theRect: CGRectMake(rightPosition, topPosition, 100*mainMenuScaleFactor, 20*mainMenuScaleFactor))
        noAIChoice.backgroundColor = UIColor.grayColor()
        noAIChoice.addTarget(self, action:#selector(SetupScene.noAIChoiceAction) , forControlEvents: UIControlEvents.TouchUpInside)
        self.view!.addSubview(noAIChoice)
        
        frenchAIChoice.setTitle("French AI", forState: .Normal)
        austrianAIChoice.setTitle("Austrian AI", forState: .Normal)
        bothAIChoice.setTitle("Both AI", forState: .Normal)
        noAIChoice.setTitle("Hot Seat", forState: .Normal)
        
        frenchAIChoice.buttonState = .On
        austrianAIChoice.buttonState = .Normal
        bothAIChoice.buttonState = .Normal
        noAIChoice.buttonState = .Normal

        /*
        bothAIChoice.font = UIFont(name: bothAIChoice.font.fontName, size: 12)
        bothAIChoice.textColor = SKColor.blackColor()
        bothAIChoice.frame = CGRect(x: 5, y: 200, width: 200, height: 15)
        self.view!.addSubview(bothAIChoice)
        
        frenchAIChoice.text = "French AI"
        austrianAIChoice.text = "Austrian AI"
        noAIChoice.text = "Both AI"
        bothAIChoice.text = "No AI"
        */

    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch: AnyObject in touches {
            let location = touch.locationInNode(self)
            if singlePlayerNew.containsPoint(location) {
                
                //Single Player new button pressed. Start game play
                startGame()
            }
            else if multiPlayerNew.containsPoint(location)
            {
                //Multiplayer new button pressed
                startGame()
            }
        }
    }
    
    private func startGame() {
        gameScene = GameScene(size: view!.bounds.size)
        gameScene.viewController = viewController
        
        let transition = SKTransition.fadeWithDuration(0.15)
        view!.presentScene(gameScene, transition: transition)
        gameScene.scaleMode = .AspectFill

    }
    
    func frenchAIChoiceAction() {
        frenchAIChoice.buttonState = .On
        austrianAIChoice.buttonState = .Normal
        bothAIChoice.buttonState = .Normal
        noAIChoice.buttonState = .Normal
    }
    func austrianAIChoiceAction() {
        frenchAIChoice.buttonState = .Normal
        austrianAIChoice.buttonState = .On
        bothAIChoice.buttonState = .Normal
        noAIChoice.buttonState = .Normal
    }
    func bothAIChoiceAction() {
        frenchAIChoice.buttonState = .Normal
        austrianAIChoice.buttonState = .Normal
        bothAIChoice.buttonState = .On
        noAIChoice.buttonState = .Normal
    }
    func noAIChoiceAction() {
        frenchAIChoice.buttonState = .Normal
        austrianAIChoice.buttonState = .Normal
        bothAIChoice.buttonState = .Normal
        noAIChoice.buttonState = .On
    }

}