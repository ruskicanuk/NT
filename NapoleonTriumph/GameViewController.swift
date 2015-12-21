//
//  GameViewController.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright (c) 2015 Justin Anderson. All rights reserved.
//

import UIKit
import SpriteKit

//let HIDEMENU: String = "hidemenu"
//let SHOWMENU: String = "showmenu"

var gameScene:GameScene!
let baseMenu = UIView.init()
let largeMenu = UIView.init()
let labelMenu = UIView.init()
let battleMenu = UIView.init()

//var scene:GameScene!
var scene:MenuView!
var delegate:AppDelegate!

class GameViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate {

    var scalingView: UIView!
    var scrollview: UIScrollView!
    var skView:SKView!
    var scale:Float = 1.0
    
    var selectedView:UIView?
    var threshold:CGFloat = 0.0
    let shouldDragY = true
    let shouldDragX = true
    let snapY:CGFloat = 1.0
    let snapX:CGFloat = 1.0

    //MARK: View Hiearchy
    override func viewDidLoad() {
    super.viewDidLoad()
        
    //NSNotificationCenter.defaultCenter().addObserver(self, selector: "hideMenu", name: HIDEMENU, object: nil)

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

    // Code for dragging and panning

    scalingView = SKView(frame: self.view.frame)
    scrollview = UIScrollView(frame: self.view.frame)
    scrollview.delegate = self
    scrollview.addSubview(scalingView)
    self.view.addSubview(scrollview)

    skView = scalingView as! SKView
    scene = MenuView(size: skView.bounds.size)
    scene.viewController = self
    skView.ignoresSiblingOrder = true
    skView.presentScene(scene)

    scrollview.maximumZoomScale = 4.0
    scrollview.minimumZoomScale = 1.0
    scrollview.bounces = false
    scrollview.bouncesZoom = false

    delegate = UIApplication.sharedApplication().delegate as! AppDelegate

    // Base menu button setup
    baseMenu.multipleTouchEnabled = true
    baseMenu.exclusiveTouch = true
    baseMenu.userInteractionEnabled = true
    baseMenu.frame = CGRectMake(150, 300, self.view.frame.size.width / 10, self.view.frame.size.height / 4)
    baseMenu.backgroundColor = UIColor.darkGrayColor()
    baseMenu.hidden = false
    self.view.addSubview(baseMenu)
        
    // Large menu button setup
    labelMenu.multipleTouchEnabled = false
    labelMenu.userInteractionEnabled = false
    labelMenu.frame = CGRectMake(650, 500, self.view.frame.size.width / 4, self.view.frame.size.height / 5)
    labelMenu.backgroundColor = UIColor.whiteColor()
    labelMenu.hidden = false
    self.view.addSubview(labelMenu)
        
    // Large menu button setup
    battleMenu.multipleTouchEnabled = false
    battleMenu.userInteractionEnabled = false
    battleMenu.frame = CGRectMake(650, 300, self.view.frame.size.width / 6, self.view.frame.size.height / 6)
    battleMenu.backgroundColor = UIColor.whiteColor()
    battleMenu.hidden = true
    self.view.addSubview(battleMenu)

    // TODO: Put constraints so player can not drag the menu off-map
    setupGestures()

}
    
func setupGestures() {
    let pan = UIPanGestureRecognizer(target:self, action:"pan:")
    pan.maximumNumberOfTouches = 1
    pan.minimumNumberOfTouches = 1
    self.view.addGestureRecognizer(pan)
}

func pan(rec:UIPanGestureRecognizer) {
    
    let p:CGPoint = rec.locationInView(self.view)
    var center:CGPoint = CGPointZero
    
    switch rec.state {
    case .Began:
        print("began")
        selectedView = view.hitTest(p, withEvent: nil)
        if selectedView != nil {
            self.view.bringSubviewToFront(selectedView!)
        }
        
    case .Changed:
        if let subview = selectedView {
            center = subview.center
            let distance = sqrt(pow((center.x - p.x), 2.0) + pow((center.y - p.y), 2.0))
            print("distance \(distance)")
            
            if subview == labelMenu || subview == baseMenu {
                if distance > threshold {
                    if shouldDragX {
                        subview.center.x = p.x - (p.x % snapX)
                    }
                    if shouldDragY {
                        subview.center.y = p.y - (p.y % snapY)
                    }
                }
            }
        }
        
    case .Ended:
        print("ended")
        if let subview = selectedView {
            if subview == labelMenu {
                // do whatever
            }
        }
        selectedView = nil
        
    case .Possible:
        print("possible")
    case .Cancelled:
        print("cancelled")
    case .Failed:
        print("failed")
    }
}

func popOutMenuTrigger() {
    if largeMenu.hidden {openMenu()}
    else {closeMenu()}
}

func openMenu() {
    largeMenu.hidden = false
}

func closeMenu() {
    largeMenu.hidden = true
}
    
/*

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

        if baseScale >= 0 {
        self.scalingView.transform = CGAffineTransformMakeScale(CGFloat(self.scale),CGFloat(self.scale))
        }
        else
        {
        print("Not scaling")
        }

    default: () // do nothing

    }
}

func dragged(dragGesture: UIPanGestureRecognizer) {

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

*/

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
