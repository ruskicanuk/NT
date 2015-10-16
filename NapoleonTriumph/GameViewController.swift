//
//  GameViewController.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright (c) 2015 Justin Anderson. All rights reserved.
//

import UIKit
import SpriteKit

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / 180.0
    }
}

//var scene:GameScene!
var scene:MenuView!
var delegate:AppDelegate!

class GameViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var scalingView: UIView!
    var scrollview: UIScrollView!
    var skView:SKView!
    
    var scale:Float = 1.0
    
    //MARK: View Hiearchy
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
        /*
        
        OLD map zoom feature
        
        // Set pinch gesture
        //        let pinchGesture = UIPinchGestureRecognizer(target: self, action: "pinched:")
        //        self.scalingView.userInteractionEnabled = true
        //        self.scalingView.addGestureRecognizer(pinchGesture)
        //self.scalingStatusLabel.text = "\(self.scale)x"
        
        // Set drag gesture
        //        let dragGesture = UIPanGestureRecognizer(target: self, action: "dragged:")
        //        self.draggedView.userInteractionEnabled = true
        //        self.draggedView.addGestureRecognizer(dragGesture)
        */
        
        scalingView = SKView(frame: self.view.frame)
        
        scrollview = UIScrollView(frame: self.view.frame)
        scrollview.delegate = self
        scrollview.addSubview(scalingView)
        self.view.addSubview(scrollview)
        
        skView = scalingView as! SKView
        scene = MenuView(size: skView.bounds.size)
        scene.viewController=self
        skView.ignoresSiblingOrder = true
        skView.presentScene(scene)
        
        
        scrollview.maximumZoomScale=4.0
        scrollview.minimumZoomScale=1.0
        scrollview.bounces=false
        scrollview.bouncesZoom=false
        
        delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        //Might be our menu button
        let viewMenu=UIView.init(frame:CGRectMake(00, 0, 400, 400))
        //        viewMenu.backgroundColor=UIColor.darkGrayColor()
        self.view.addSubview(viewMenu)
        viewMenu.multipleTouchEnabled=true
        viewMenu.exclusiveTouch=true
        let button:UIButton = UIButton.init(frame: CGRectMake(0, 0, 220 , 200))
        button.setTitle("Menu button", forState: UIControlState.Normal)
        button.addTarget(self, action:"openMenu" , forControlEvents: UIControlEvents.TouchUpInside)
        viewMenu.addSubview(button)
        button.backgroundColor=UIColor.redColor()
        
        
    }
    
    func openMenu()
    {
        
         //This is required. When user zoom the map and go back to menu screen at that time we need to reset the scrollview zoomscale to 1
        scrollview.zoomScale=1.0
        
        scene = MenuView(size: skView.bounds.size)
        scene.viewController=self
        skView.ignoresSiblingOrder = true
        skView.presentScene(scene)
    }
    
    //MARK: ScrollView Delegate
    internal func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.scalingView
    }
    
    func pinched(pinchGesture : UIPinchGestureRecognizer) {
        
        switch pinchGesture.state {
            
        case .Changed:
            
            var baseScale = self.scale * Float(pinchGesture.scale)
            print("basescale ",baseScale);
            
            if baseScale < 1.0 {baseScale = 1.0} else {baseScale = min(4.0,baseScale)}
            self.scale = baseScale
            
            pinchGesture.scale = 1.0
            
            if baseScale >= 0
            {
                self.scalingView.transform =
                    CGAffineTransformMakeScale(CGFloat(self.scale),
                        CGFloat(self.scale))
            }
            else
            {
                print("Not scalling")
            }
            
        default: () // do nothing
            
        }
        
        // Display the current scale factor
        //self.scalingStatusLabel?.text = "\(self.scale)x"
        
    }
    
    func dragged(dragGesture : UIPanGestureRecognizer) {
        
        if dragGesture.state == .Began || dragGesture.state == .Changed {
            
            let maxLeft = min((view!.frame.minX - view!.superview!.frame.minX),0)
            let maxRight = min((view!.superview!.frame.maxX - view!.frame.maxX),0)
            let maxDown = min((view!.frame.minY - view!.superview!.frame.minY),0)
            let maxUp = min((view!.superview!.frame.maxY - view!.frame.maxY),0)
            
            var newPosition = dragGesture.translationInView(dragGesture.view!)
            
            if newPosition.x >= 0 {newPosition.x = min(-maxLeft,newPosition.x)} else {newPosition.x = max(maxRight,newPosition.x)}
            if newPosition.y >= 0 {newPosition.y = min(-maxDown,newPosition.y)} else {newPosition.y = max(maxUp,newPosition.y)}
            
            newPosition.x += dragGesture.view!.center.x
            newPosition.y += dragGesture.view!.center.y
            
            dragGesture.view!.center = newPosition
            dragGesture.setTranslation(CGPointZero, inView: dragGesture.view)
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return .AllButUpsideDown
        } else {
            return .All
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}
