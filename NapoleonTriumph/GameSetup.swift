//
//  GameSetup.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 9/30/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit
import UIKit

class GameSetup: SKScene {

    let singlePlayer = SKSpriteNode(imageNamed: "singleplayer")
    let multiPlayer = SKSpriteNode(imageNamed: "multiplayer")
    
    let singlePlayerNew = SKSpriteNode(imageNamed: "newgame")
    let multiPlayerNew = SKSpriteNode(imageNamed: "newgame")

    let singlePlayerLoad = SKSpriteNode(imageNamed: "loadgame")
    let multiPlayerLoad = SKSpriteNode(imageNamed: "loadgame")

    var buttonSpacing:CGFloat = 50
    
    override func didMoveToView(view: SKView) {
    
        /* Setup your scene here */
        
        loadButtons()
        startGame() // #### REMOVE LATER, to speed up testing ####
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
        let transition = SKTransition.fadeWithDuration(0.15)
        view!.presentScene(gameScene, transition: transition)
        gameScene.scaleMode = .AspectFill
    }  
}