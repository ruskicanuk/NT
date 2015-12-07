//
//  Support.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-08-08.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

// MARK: Support Classes

class UIStateButton:UIButton {
    
    var buttonState:SelState {
        didSet {
            toggleSelection()
        }
    }
    
    init(initialState:SelState, theRect:CGRect) {
        
        buttonState = initialState
        super.init(frame: theRect)
        toggleSelection()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toggleSelection() {
        
        switch buttonState {
            
        case .Off: self.enabled = false; self.layer.borderWidth = 0
            
        case .On: self.enabled = true; self.layer.borderWidth = 3; self.layer.borderColor = UIColor(red: 0, green: 1, blue: 0, alpha: 1).CGColor
            
        case .Option: self.enabled = true; self.layer.borderWidth = 3; self.layer.borderColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1).CGColor
            
        case .Normal: self.enabled = true; self.layer.borderWidth = 0
            
        case .NotAvail: self.enabled = false; self.layer.borderWidth = 3; self.layer.borderColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1).CGColor
            
        case .Possible: self.enabled = true; self.layer.borderWidth = 3; self.layer.borderColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1).CGColor
            
        }
    }
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
        toggleSelection()
    }
    
    func toggleSelection() {
        
        if selectionBox != nil {selectionBox!.removeFromParent()}
        if selected == .Off {return Void()}
        
        if drawType == "Normal" {
            selectionBox = SKShapeNode(rect: parent!.calculateAccumulatedFrame())
        } else if drawType == "Command" {
            selectionBox = SKShapeNode(ellipseOfSize: CGSize(width: parent!.calculateAccumulatedFrame().width, height: parent!.calculateAccumulatedFrame().width*0.5))
        } else if drawType == "EndTurn" {
            selectionBox = SKShapeNode(circleOfRadius: parent!.calculateAccumulatedFrame().width/2)
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
            
        } else if selected == .Normal {
            
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
    
    func turnColor(color:String) {
        
        if selected != .Option {return}
        
        switch color {
            
        case "Purple": selectionBox!.strokeColor = SKColor.purpleColor()
            
        default: break
            
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
