//
//  Support.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-08-08.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

// MARK: Support Functions and Classes

extension Array where Element : Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating func removeObject(object : Generator.Element) {
        if let index = self.indexOf(object) {
            self.removeAtIndex(index)
        }
    }
}

//Not used currently
extension Array {
    
    // Returns the first element satisfying the predicate, or `nil`
    // if there is no matching element.
    func findFirstMatching<L : BooleanType>(predicate: Element -> L) -> Element? {
        for item in self {
            if predicate(item) {
                return item // found
            }
        }
        return nil // not found
    }
}

func Delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

enum SelState {
    case On, Off, Option, NotAvail
}

class SpriteSelector {
    
    var selected:SelState = .Off {
        didSet {
            toggleSelection()
        }
    }
    var selectionBox:SKShapeNode?
    weak var parent:SKNode?
    weak var drawOnNode:SKNode?
    var drawType:String = "Normal"
    
    init (parentNode:SKNode, initialSelection:SelState) {
        parent = parentNode
        selected = initialSelection
    }
    
    init (parentNode:SKNode, initialSelection:SelState, theCoordinateSystem:SKNode, passDrawType:String = "Normal") {
        parent = parentNode
        selected = initialSelection
        drawOnNode = theCoordinateSystem
        drawType = passDrawType
    }
    
    func toggleSelection() {
        
        if selectionBox != nil {selectionBox!.removeFromParent()}
        if selected == .Off {return Void()}
        
        if drawType == "Normal" {
            selectionBox = SKShapeNode(rect: parent!.calculateAccumulatedFrame())
        } else if drawType == "Command" {
            //selectionBox = SKShapeNode()
            //print(parent!.calculateAccumulatedFrame().size)
            //selectionBox = SKShapeNode(rectOfSize: parent!.calculateAccumulatedFrame().size)
            selectionBox = SKShapeNode(ellipseOfSize: CGSize(width: parent!.calculateAccumulatedFrame().width, height: parent!.calculateAccumulatedFrame().width*0.5))
        }
        
        if selected == .On {
            //selectionBox = SKShapeNode(rect: parent!.calculateAccumulatedFrame())
            //selectionBox = SKShapeNode(circleOfRadius: 100.0)
            //selectionBox!.position = parent!.position
            selectionBox!.strokeColor = SKColor.greenColor()
            selectionBox!.lineWidth = 3.0
            selectionBox!.glowWidth = 1.0
            selectionBox!.userInteractionEnabled = false
            //selectionBox!.lineCap = .Square
            selectionBox!.zPosition = 3000
            
            if drawOnNode != nil {drawOnNode?.addChild(selectionBox!)}
            
        } else if selected == .Option {
            
            //selectionBox = SKShapeNode(rect: parent!.calculateAccumulatedFrame())
            //selectionBox!.position = parent!.position
            selectionBox!.strokeColor = SKColor.blueColor()
            selectionBox!.lineWidth = 3.0
            selectionBox!.glowWidth = 1.0
            selectionBox!.userInteractionEnabled = false
            //selectionBox!.lineCap = .Square
            selectionBox!.zPosition = 3000
            
            if drawOnNode != nil {drawOnNode?.addChild(selectionBox!)}
            
        } else if selected == .NotAvail {
            
            //selectionBox = SKShapeNode(rect: parent!.calculateAccumulatedFrame())
            //selectionBox!.position = parent!.position
            selectionBox!.strokeColor = SKColor.redColor()
            selectionBox!.lineWidth = 3.0
            selectionBox!.glowWidth = 1.0
            selectionBox!.userInteractionEnabled = false
            //selectionBox!.lineCap = .Square
            selectionBox!.zPosition = 3000
            
            if drawOnNode != nil {drawOnNode?.addChild(selectionBox!)}
            
        }
    }
}

/*
func convertPoint(point: CGPoint) -> (success: Bool, column: Int, row: Int) {
/*
if point.x >= 0 && point.x < CGFloat(NumColumns)*mapScaleFactor &&
point.y >= 0 && point.y < CGFloat(NumRows)*mapScaleFactor {
return (true, Int(point.x / TileWidth), Int(point.y / TileHeight))
} else {
return (false, 0, 0)  // invalid location
}
*/
return (true, 1, 1)
}
*/
