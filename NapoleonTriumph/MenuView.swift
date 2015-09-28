//
//  MenuView.swift
//  NapoleonTriumph
//
//  Created by Mac Pro on 9/25/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//This file shows menu of the game.

import SpriteKit
import Foundation

class MenuView: SKScene {
    
    //This is a start game button.
    let startButton = SKSpriteNode(imageNamed:"start")

    let leftButton = SKSpriteNode(imageNamed: "blue_marker")

    let rightButton = SKSpriteNode(imageNamed: "blue_marker")
    
    let facebookButton = SKSpriteNode(imageNamed: "facebook")
    
    let twitterButton = SKSpriteNode(imageNamed: "twitter")

    var buttonSpacing: CGFloat = 100
    //buttonSpacing must be <150 so that it will show properly in iPhone 4s also
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        loadMenu()
    }
    
    //this will load menu buttons
    func loadMenu()
    {
        
        //Start Button
        self.backgroundColor = SKColor(red: 0.15, green:0.15, blue:0.3, alpha: 1.0)
        startButton.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
        self.addChild(startButton)
        
        //Left Side button
        leftButton.position = CGPointMake(CGRectGetMinX(self.frame) + buttonSpacing, CGRectGetMidY(self.frame))
        self.addChild(leftButton)

        //Right Side button
        rightButton.position = CGPointMake(CGRectGetMaxX(self.frame) - buttonSpacing, CGRectGetMidY(self.frame))
        self.addChild(rightButton)
        
        //Facebook button
        facebookButton.position = CGPointMake(CGRectGetMinX(self.frame) + 40, CGRectGetMinY(self.frame) + 30)
        self.addChild(facebookButton)

        //Facebook button
        twitterButton.position = CGPointMake(CGRectGetMinX(self.frame) + 80, CGRectGetMinY(self.frame) + 30)
        self.addChild(twitterButton)

    }
    
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch: AnyObject in touches {
            let location = touch.locationInNode(self)
            if startButton.containsPoint(location) {
                //Start button pressed. Start game play
                startGame()
            }
            else if facebookButton.containsPoint(location)
            {
                //Facebook button pressed. Open facebook screen
            }
            else if twitterButton.containsPoint(location)
            {
                //Twitter button pressed. Open twitter now
            }
        }
    }
    
    private func startGame() {
        let gameScene = GameScene(size: view!.bounds.size)
        let transition = SKTransition.fadeWithDuration(0.15)
        view!.presentScene(gameScene, transition: transition)
        gameScene.scaleMode = .AspectFill
    }

}