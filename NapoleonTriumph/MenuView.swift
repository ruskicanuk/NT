//
//  MenuView.swift
//  NapoleonTriumph
//
//  Created by Mac Pro on 9/25/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//This file shows menu of the game.

import SpriteKit
//import Foundation
import UIKit

class MenuView: SKScene {
    
    //This is a start game button.
    let startButton = SKSpriteNode(imageNamed:"start")
    
    let leftButton = SKSpriteNode(imageNamed: "blue_marker")
    
    let rightButton = SKSpriteNode(imageNamed: "blue_marker")
    
    let facebookButton = SKSpriteNode(imageNamed: "facebook")
    
    let twitterButton = SKSpriteNode(imageNamed: "twitter")
    
    let webButton = SKSpriteNode(imageNamed: "web")
    
    let settingButton = SKSpriteNode(imageNamed: "gear")
    
    var board = SKSpriteNode(color: SKColor.yellowColor(), size: CGSizeMake(200, 200))
    
    var buttonSpacing: CGFloat = 100
    var buttonSocialSpacing: CGFloat = 40
    
    var viewController: GameViewController!
    
    //buttonSpacing must be <150 so that it will show properly in iPhone 4s also
    
    func pinched(sender:UIPinchGestureRecognizer){
        print("pinched \(sender)")
        // the line below scales the entire scene
        //sender.view!.transform = CGAffineTransformScale(sender.view!.transform, sender.scale, sender.scale)
        sender.scale = 1.01
        
        // line below scales just the SKSpriteNode
        // But it has no effect unless I increase the scaling to >1
        let zoomBoard = SKAction.scaleBy(sender.scale, duration: 0)
        board.runAction(zoomBoard)
    }
    
    // line below scales just the SKSpriteNode
    func swipedUp(sender:UISwipeGestureRecognizer){
        print("swiped up")
        let zoomBoard = SKAction.scaleBy(1.1, duration: 0)
        board.runAction(zoomBoard)
    }
    
    // I thought perhaps the line below would scale down the SKSpriteNode
    // But it has no effect at all
    func swipedDown(sender:UISwipeGestureRecognizer){
        print("swiped down")
        let zoomBoard = SKAction.scaleBy(0.9, duration: 0)
        board.runAction(zoomBoard)
    }
    
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        
        //        self.addChild(board)
        
        //        let pinch:UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: Selector("pinched:"))
        //        view.addGestureRecognizer(pinch)
        //
        //
        //        let swipeUp:UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: Selector("swipedUp:"))
        //        swipeUp.direction = .Up
        //        view.addGestureRecognizer(swipeUp)
        //
        //        let swipeDown:UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: Selector("swipedDown:"))
        //        swipeDown.direction = .Down
        //        view.addGestureRecognizer(swipeDown)
        loadMenu()
        startGame()
        //return // #### REMOVE LATER, to speed up testing ####
        //NSNotificationCenter.defaultCenter().postNotificationName(HIDEMENU, object: nil)

    }
    
    //this will load menu buttons
    func loadMenu()
    {
        
        buttonSpacing = (self.view?.frame.size.width)!/6;
        
        //Start Button
        self.backgroundColor = SKColor(CGColor: UIColor.whiteColor().CGColor)
        startButton.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
        self.addChild(startButton)
        
        //Left Side button
        leftButton.position = CGPointMake(CGRectGetMinX(self.frame) + buttonSpacing, CGRectGetMidY(self.frame))
        self.addChild(leftButton)
        
        //Right Side button
        rightButton.position = CGPointMake(CGRectGetMaxX(self.frame) - buttonSpacing, CGRectGetMidY(self.frame))
        self.addChild(rightButton)
        
        //Facebook button
        facebookButton.position = CGPointMake(CGRectGetMinX(self.frame) + buttonSocialSpacing, CGRectGetMinY(self.frame) + 30)
        self.addChild(facebookButton)
        
        //Twitter button
        twitterButton.position = CGPointMake(CGRectGetMinX(self.frame) + (buttonSocialSpacing * 2), CGRectGetMinY(self.frame) + 30)
        self.addChild(twitterButton)
        
        //Web button
        webButton.position = CGPointMake(CGRectGetMinX(self.frame) + (buttonSocialSpacing * 3), CGRectGetMinY(self.frame) + 30)
        self.addChild(webButton)
        
        //Web button
        settingButton.position = CGPointMake(CGRectGetMinX(self.frame) + (buttonSocialSpacing * 4), CGRectGetMinY(self.frame) + 30)
        self.addChild(settingButton)
    }
    
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch: AnyObject in touches {
            let location = touch.locationInNode(self)
            if startButton.containsPoint(location) {
                //Start button pressed. Start game play
                startGame()
            }
            else if leftButton.containsPoint(location)
            {
                //Left button pressed
                openHowToPlay()
            }
            else if facebookButton.containsPoint(location)
            {
                //Facebook button pressed. Open facebook screen
                UIApplication.sharedApplication().openURL(NSURL(string: "https://facebook.com")!)
            }
            else if twitterButton.containsPoint(location)
            {
                //Twitter button pressed. Open twitter now
                UIApplication.sharedApplication().openURL(NSURL(string: "https://twitter.com")!)
            }
            else if webButton.containsPoint(location)
            {
                //Web button pressed. Open twitter now
                UIApplication.sharedApplication().openURL(NSURL(string: "http://www.strategyleague.com")!)
            }
        }
    }
    
    private func openHowToPlay()
    {
        
        let controller:HowToPlayViewController = HowToPlayViewController()
        let navigationController:UINavigationController = UINavigationController.init(rootViewController: controller)
        viewController.presentViewController(navigationController, animated: true, completion: nil)
    }
    
    private func startGame() {
        let gameScene = GameSetup(size: view!.bounds.size)
        let transition = SKTransition.fadeWithDuration(0.15)
        view!.presentScene(gameScene, transition: transition)
        gameScene.scaleMode = .AspectFill
    }
    
}