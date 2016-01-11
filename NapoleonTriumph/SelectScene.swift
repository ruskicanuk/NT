//
//  AttachMenuScene.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-08.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

//import SpriteKit
//import UIKit

// This isn't used presently
/*
class SelectScene: SKScene {
    
    var selGroupsSelected:[Group] = []
    var selGroupsAtLocation:[Group] = []
    var selOccupants:[Command] = []
    
    var selCurrentLocation:Location?
    
    var windowOccupants:[Command] = []
    
    var viewController: GameViewController!
    
    override func didMoveToView(view: SKView) {

        if !manager!.groupsSelected.isEmpty {
            
            // GameScene scope location
            selGroupsSelected = manager!.groupsSelected
            selCurrentLocation = selGroupsSelected[0].command.currentLocation
            selOccupants = selCurrentLocation!.occupants
            
            // New commands
            //for eachCommand in selCurrentLocation!.occupants {
            //    let newCommand = Command(creatingUnits: eachCommand.units)
            //    windowOccupants += [newCommand]
            //    self.addChild(newCommand)
            //}
        }
        selReShuffleLocation()
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch: AnyObject in touches {
            //let location = touch.locationInNode(self)
            //if startButton.containsPoint(location) {
                //Start button pressed. Start game play
            //}
        }
    }
    
    func selReShuffleLocation() {
        
        var extraRotation:CGFloat = 0
        var unitCount:Int = 0
        var commandCount:Int = 0
        
        var twoColumns:Bool = false // Whether to use two columns (defaults to one)
        var leftSideUnits:Int = 0
        var rightSideUnits:Int = 0
        var leftSideCommands:Int = 0
        var rightSideCommands:Int = 0
        var sideLeft:Bool = true // Which side to draw on
        
        let yOffset:CGFloat = -(unitHeight*cos(self.zRotation + extraRotation)*mapScaleFactor)
        let xOffset:CGFloat = (unitHeight*sin(self.zRotation + extraRotation)*mapScaleFactor)
        
        let yWidthOffset:CGFloat = (unitWidth*0.52*sin(self.zRotation + extraRotation)*mapScaleFactor)
        let xWidthOffset:CGFloat = (unitWidth*0.52*cos(self.zRotation + extraRotation)*mapScaleFactor)
        
        let yCommandOffset:CGFloat = -(commandOffset*cos(self.zRotation + extraRotation)*mapScaleFactor)
        let xCommandOffset:CGFloat = (commandOffset*sin(self.zRotation + extraRotation)*mapScaleFactor)
        
        for each in windowOccupants {
            
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
*/