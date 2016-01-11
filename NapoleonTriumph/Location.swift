//
//  Location.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-23.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

// Used by reserve, approach and start locations AND for commands' location
enum LocationType {
    case Reserve, Approach, Start, Heaven, Window
}

class Location:SKSpriteNode {
    
    let locationType:LocationType
    let locationImage:String
    
    var locationControl:Allegience = .Neutral
    
    var occupants:[Command] = [] {
        didSet {
            reShuffleLocation()
            if occupantCount > 0 {
                if occupants[0].commandSide == .Austrian {locationControl = .Austrian}
                else {locationControl = .French}
            } else {locationControl = .Neutral}
        }
    }
    
    var occupantCount:Int {
        
        var count:Int = 0
        
        for each in occupants {count += each.unitCount}
        return count
    }
    
    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(nodePosition:CGPoint, nodeRotation:CGFloat) {
        
        // Use this function to create false locations
        locationType = .Start
        locationImage = ""
        
        super.init(texture: SKTexture(), color: UIColor(), size: CGSize())
        self.position = nodePosition
        self.zRotation = nodeRotation
    }
    
    init (theDict:Dictionary<NSObject, AnyObject>, scaleFactor:CGFloat, reserveLocation:Bool) {
        
        var extraRotation:CGFloat = 0
        
        if reserveLocation {
            locationImage = "green_target"
            locationType = .Reserve
        } else {
            locationImage = "green_arrow"
            locationType = .Approach
            extraRotation = CGFloat(M_PI/2)
        }
        
        let texture:SKTexture = SKTexture(imageNamed: locationImage)
        let color:UIColor = UIColor()
        let size:CGSize = CGSize(width: 20*scaleFactor, height: 20*scaleFactor)
        
        super.init(texture: texture, color: color, size: size)
        
        let theX:String = theDict["x"] as AnyObject? as! String
        let x:CGFloat = CGFloat(Float(theX)!)*scaleFactor
        
        let theY:String = theDict["y"] as AnyObject? as! String
        let y:CGFloat = CGFloat(Float(theY)!)*scaleFactor
        
        let theZ:String = theDict["z"] as AnyObject? as! String
        let z:CGFloat = CGFloat(Double(theZ)!)
        
        let theZrot:String = theDict["zRot"] as AnyObject? as! String
        let zRot:Int = Int(theZrot)!
        
        self.zPosition = z
        self.zRotation = zRot.degreesToRadians - extraRotation
        
        if self.locationType == .Approach { self.zRotation += CGFloat(M_PI/2) }
        
        self.position = CGPoint(x: x, y: y)
    }
    
    func reShuffleLocation() {
        
        var extraRotation:CGFloat = 0
        var unitCount:Int = 0
        var commandCount:Int = 0
        
        var twoColumns:Bool = false // Whether to use two columns (defaults to one)
        var leftSideUnits:Int = 0
        var rightSideUnits:Int = 0
        var leftSideCommands:Int = 0
        var rightSideCommands:Int = 0
        var sideLeft:Bool = true // Which side to draw on
        
        if self.locationType == .Approach {
            
            let approachSelf = self as! Approach
            if (approachSelf.wideApproach && self.occupants.count > 1) {twoColumns = true}
            extraRotation = CGFloat(M_PI/2)
        }
        
        if self.locationType == .Reserve {
            
            let reserveSelf = self as! Reserve
            if (self.occupants.count > 1 && reserveSelf.capacity > 6) {twoColumns = true}
        }
        
        let yOffset:CGFloat = -(unitHeight*cos(self.zRotation + extraRotation)*mapScaleFactor)
        let xOffset:CGFloat = (unitHeight*sin(self.zRotation + extraRotation)*mapScaleFactor)
        
        let yWidthOffset:CGFloat = (unitWidth*0.52*sin(self.zRotation + extraRotation)*mapScaleFactor)
        let xWidthOffset:CGFloat = (unitWidth*0.52*cos(self.zRotation + extraRotation)*mapScaleFactor)
        
        let yCommandOffset:CGFloat = -(commandOffset*cos(self.zRotation + extraRotation)*mapScaleFactor)
        let xCommandOffset:CGFloat = (commandOffset*sin(self.zRotation + extraRotation)*mapScaleFactor)
        
        for each in occupants {

            var yColumnOffset:CGFloat = 0.0
            var xColumnOffset:CGFloat = 0.0
                
            if (leftSideUnits <= rightSideUnits && twoColumns) {
                
                yColumnOffset = -yWidthOffset
                xColumnOffset = -xWidthOffset
                commandCount = leftSideCommands
                unitCount = leftSideUnits
                sideLeft = true
            
            } else if twoColumns {
                
                yColumnOffset = yWidthOffset
                xColumnOffset = xWidthOffset
                commandCount = rightSideCommands
                unitCount = rightSideUnits
                sideLeft = false
                
            } else {
                
                commandCount = leftSideCommands
                unitCount = leftSideUnits
            }
            
            let pointX:CGFloat = self.position.x+xOffset*CGFloat(unitCount)+xCommandOffset*CGFloat(commandCount)+xColumnOffset
            let pointY:CGFloat = self.position.y+yOffset*CGFloat(unitCount)+yCommandOffset*CGFloat(commandCount)+yColumnOffset
            
            let finalPosition:CGPoint = CGPoint(x:pointX, y:pointY)
            
            let moveNode = SKAction.moveTo(finalPosition, duration:0.5)
            let rotateNode = SKAction.rotateToAngle(self.zRotation + extraRotation, duration: 0.5, shortestUnitArc: true)
            let moverotateNode = SKAction.group([moveNode,rotateNode])
            
            // Run re-shuffle animation
            each.runAction(moverotateNode)
            
            // Update relevant side's count
            if sideLeft {
                
                leftSideCommands++
                leftSideUnits += each.activeUnits.count
                
            } else {
            
                rightSideCommands++
                rightSideUnits += each.activeUnits.count
            }
        }
    }
}