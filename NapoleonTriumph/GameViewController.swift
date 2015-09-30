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


class GameViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var scalingView: UIView!
    @IBOutlet weak var draggedView: UIView!
    
    var scale:Float = 1.0
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Set pinch gesture
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: "pinched:")
        self.scalingView.userInteractionEnabled = true
        self.scalingView.addGestureRecognizer(pinchGesture)
        //self.scalingStatusLabel.text = "\(self.scale)x"
        
        // Set drag gesture
        let dragGesture = UIPanGestureRecognizer(target: self, action: "dragged:")
        self.draggedView.userInteractionEnabled = true
        self.draggedView.addGestureRecognizer(dragGesture)
        
        let skView = view as! SKView
//        scene = GameScene(size: skView.bounds.size)
        scene = MenuView(size: skView.bounds.size)
        scene.viewController=self
        skView.ignoresSiblingOrder = true
        skView.presentScene(scene)
        
        /*
        let testFrame:CGRect = CGRectMake(0,200,320,200)
        let menuView = UIView(frame:testFrame)
        menuView.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        self.view.addSubview(menuView)
        */
        //skView.ignoresSiblingOrder = true
        //skView.presentScene(scene)
    }
    
    func pinched(pinchGesture : UIPinchGestureRecognizer) {
        
        switch pinchGesture.state {
            
        case .Changed:
            
            var baseScale = self.scale * Float(pinchGesture.scale)
            if baseScale < 1.0 {baseScale = 1.0} else {baseScale = min(4.0,baseScale)}
            self.scale = baseScale
            
            pinchGesture.scale = 1.0
            
            self.scalingView.transform =
                CGAffineTransformMakeScale(CGFloat(self.scale),
                    CGFloat(self.scale))
            
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
