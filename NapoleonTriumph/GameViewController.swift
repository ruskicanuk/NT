//
//  GameViewController.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright (c) 2015 Justin Anderson. All rights reserved.
//

import UIKit
import SpriteKit

let HIDEMENU: String = "hidemenu"
let SHOWMENU: String = "showmenu"

var gameScene:GameScene!
let baseMenu = UIView.init()
let largeMenu = UIView.init()

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
    //NSNotificationCenter.defaultCenter().addObserver(self, selector: "hideMenu", name: HIDEMENU, object: nil)
    //NSNotificationCenter.defaultCenter().addObserver(self, selector: "showMenu", name: SHOWMENU, object: nil)

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
    baseMenu.frame = CGRectMake(100, 100, self.view.frame.size.width / 20, self.view.frame.size.height / 20)
    baseMenu.backgroundColor = UIColor.blackColor()
    baseMenu.hidden = false
    self.view.addSubview(baseMenu)
        
    // Large menu button setup
    largeMenu.multipleTouchEnabled = true
    largeMenu.exclusiveTouch = true
    largeMenu.userInteractionEnabled = true
    largeMenu.frame = CGRectMake(150, 100, self.view.frame.size.width / 2, self.view.frame.size.height / 20)
    largeMenu.backgroundColor = UIColor.redColor()
    largeMenu.hidden = true
    self.view.addSubview(largeMenu)

    let popButton:UIButton = UIButton.init(frame: CGRectMake(-30, -30, 100, 100))
    popButton.setImage(UIImage.init(named: "Menu"), forState: UIControlState.Normal)
    popButton.addTarget(self, action:"changeMenu" , forControlEvents: UIControlEvents.TouchUpInside)
    baseMenu.addSubview(popButton)

}

func changeMenu() {
    if largeMenu.hidden {openMenu()}
    else {closeMenu()}
}

func openMenu() {
    largeMenu.hidden = false
}

func closeMenu() {
    largeMenu.hidden = true
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
