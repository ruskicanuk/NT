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
var menuScene:MainMenuScene!
//var attachScene:SelectScene!

let baseMenu = UIView.init()
let largeMenu = UIView.init()
let labelMenu = UIView.init()
let battleMenu = UIView.init()
//let selectView = SKView.init()

//var scene:GameScene!

var delegate:AppDelegate!

class GameViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate {

    var scalingView: UIView!
    var scrollView: UIScrollView!
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
    scrollView = UIScrollView(frame: self.view.frame)
    scrollView.delegate = self
    scrollView.addSubview(scalingView)
    self.view.addSubview(scrollView)

    skView = scalingView as! SKView
    
    // Initialize MainMenuScene
    menuScene = MainMenuScene(size: skView.bounds.size)
    menuScene.viewController = self // Allows access to the view controller
        
    skView.ignoresSiblingOrder = true
    skView.presentScene(menuScene)

    scrollView.maximumZoomScale = 6.0
    scrollView.minimumZoomScale = 1.0
    scrollView.bounces = false
    scrollView.bouncesZoom = false

    delegate = UIApplication.sharedApplication().delegate as! AppDelegate

    // Base menu button setup
    baseMenu.multipleTouchEnabled = true
    baseMenu.exclusiveTouch = true
    baseMenu.userInteractionEnabled = true
    baseMenu.frame = CGRectMake(150, 300, self.view.frame.size.width / 8, self.view.frame.size.height / 3)
    baseMenu.backgroundColor = UIColor.darkGrayColor()
    baseMenu.hidden = false
    self.view.addSubview(baseMenu)
        
    // Large menu button setup
    labelMenu.multipleTouchEnabled = false
    labelMenu.userInteractionEnabled = false
    labelMenu.frame = CGRectMake(650, 500, self.view.frame.size.width / 4, self.view.frame.size.height / 4)
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
        
    labelMenu.hidden = true
    baseMenu.hidden = true

        
    // Large menu button setup
    //selectView.multipleTouchEnabled = false
    //selectView.userInteractionEnabled = false
    //selectView.frame = CGRectMake(650, 300, self.view.frame.size.width / 6, self.view.frame.size.height / 6)
    //selectView.backgroundColor = UIColor.whiteColor()
    //selectView.hidden = true
    //self.view.addSubview(selectView)

    // TODO: Put constraints so player can not drag the menu off-map
    setupGestures()

    }
    
    ////// MADE a CHANGE HERE from let pan = UIPanGestureRecognizer(target:self, action:"pan:")
    func setupGestures() {
        let pan = UIPanGestureRecognizer(target:self, action: #selector(GameViewController.pan(_:)))
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
        
    //MARK: scrollView Delegate
        
    internal func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.scalingView
    }
        
    internal func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        if scale >= 3.0 {
            zoomedMode = true
        } else {
            zoomedMode = false
        }
    }
    
    /*
    func setZoomScale(scale: CGFloat, animated: Bool) {
        
        //scrollView.minimumZoomScale = min(widthScale, heightScale)
        scrollView.zoomScale = scale
    }
    */
    
    func zoomToPoint(thePoint:CGPoint, zoomLevel:CGFloat) {
        //if (self.scrollView!.zoomScale == self.scrollView!.minimumZoomScale) {
        
        let center = thePoint
        let scrollViewSize = scrollView!.bounds.size
        let w = scrollViewSize.width / zoomLevel
        let h = scrollViewSize.height / zoomLevel
        let x = center.x - (w / 2.0)
        let y = center.y - (h / 2.0)
        let zoomRect = CGRectMake(x, y, w, h)
        self.scrollView!.zoomToRect(zoomRect, animated: true)
        //} else {
        //    self.scrollView!.setZoomScale(self.scrollView!.minimumZoomScale, animated: true)
        //}
    }
    
    func centerScrollViewContents(theFrame:CGRect) {
        let boundsSize = scrollView.bounds.size
        var contentsFrame = theFrame
        
        if contentsFrame.size.width < boundsSize.width {
            contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0
        } else {
            contentsFrame.origin.x = 0.0
        }
        
        if contentsFrame.size.height < boundsSize.height {
            contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0
        } else {
            contentsFrame.origin.y = 0.0
        }
        
        //imageView.frame = contentsFrame
    }
    
    

    /*

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
