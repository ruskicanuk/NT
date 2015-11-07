//
//  Command.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

enum MoveType {
    case CorpsMove, CorpsDetach, CorpsAttach, IndMove, CorpsActed, None
}

class Command:SKNode {
    
    
    // MARK: Properties
    
    //Stores the name and type of initial location
    let loc:String
    let locID:String
    var selectable:Bool = true
    
    //var secondMoveAvailable = false
    var secondMoveUsed = false
    var turnMayEnterMap = -1
    var turnEnteredMap = -1
    var freeMove = false

    // Used to store units available to defend
    var availableToDefend:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.alreadyDefended == false && eachUnit.unitType != .Ldr {theUnits += [eachUnit]}
        }
        return theUnits
    }
    
    //var attackingUnits:[Unit] = []
    // Set to true when command can make no more moves during the round
    var finishedMove:Bool = false {
        didSet {
            if finishedMove && hasLeader {
                theLeader!.hasMoved = true
            } else if !finishedMove && !hasMoved && hasLeader {
                theLeader!.hasMoved = false
            }
        }
    }
    
    // Any move or attach order sets this to true
    var hasMoved:Bool = false
    
    var movedVia:MoveType = .None {
        didSet {
            // Units moved
            if movedVia == .None {hasMoved = false; finishedMove = false; for each in activeUnits {each.hasMoved = false}}
            if movedVia == .CorpsMove {hasMoved = true; for each in activeUnits {each.hasMoved = true}}
            if movedVia == .IndMove {hasMoved = true; activeUnits[0].hasMoved = true}
            if movedVia == .CorpsDetach {hasMoved = true; finishedMove = true; activeUnits[0].hasMoved = true}
            
            // Units did not move
            //if movedVia == .CorpsAttach {}
            if movedVia == .CorpsActed {hasMoved = true; finishedMove = true} // Used for the command doing the attaching or detaching
        }
    }
    
    var selector:SpriteSelector?
    
    //Unit naming convention: 3-digit code: 1st: 1/2 Austrian/French, 2nd: 1/2/3/4/5 Art/Cav/Inf/Guard/Leader, 3rd: 1/2/3 Strength
    var unitCount:Int = 0
    var activeUnits:[Unit] = []
    var units:[Unit] = [] {
        didSet {
            unitsUpkeep()
            if unitCount <= 0 {self.zPosition = -1} else {self.zPosition = 0}
        }
    }
    var unitsTotalStrength:Int {
        var totalStrength:Int = 0
        for eachUnit in nonLeaderUnits {
            totalStrength += eachUnit.unitStrength
        }
        return totalStrength
    }
    var nonLeaderUnits:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.unitType != .Ldr {theUnits += [eachUnit]}
        }
        return theUnits
    }
    var nonLeaderNonArtUnits:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.unitType != .Ldr && eachUnit.unitType != .Art {theUnits += [eachUnit]}
        }
        return theUnits
    }
    var infUnits:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.unitType == .Inf || eachUnit.unitType == .Grd {theUnits += [eachUnit]}
        }
        return theUnits
    }
    var artUnits:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.unitType == .Art {theUnits += [eachUnit]}
        }
        return theUnits
    }
    var cavUnits:[Unit] {
        var theUnits:[Unit] = []
        for eachUnit in activeUnits {
            if eachUnit.unitType == .Cav {theUnits += [eachUnit]}
        }
        return theUnits
    }
    
    // Where the command is currently
    var currentLocation:Location? {
        
        didSet {
            
            if currentLocation is Approach {
                currentLocationType = .Approach
            } else if currentLocation is Reserve {
                currentLocationType = .Reserve
            } else {
                currentLocationType = .Start
            }
        }
    }
    
    // Whether the current location is a reserve or approach
    var currentLocationType:LocationType = .Start
    
    // Stores the locations moved through (for rd movement)
    var rdMoves:[Location]

    var moveNumber:Int = 0 {
        
        didSet {
            
            switch moveNumber {
                
            case 0:
                rdMoves = [currentLocation!]
                //hasMoved = false
            case 1:
                if rdMoves.count == 1 {rdMoves += [currentLocation!]} else {rdMoves.removeAtIndex(2)}
                //hasMoved = true
            case 2:
                if rdMoves.count == 2 {rdMoves += [currentLocation!]} else {rdMoves.removeAtIndex(3)}
                //hasMoved = true
            case 3:
                if rdMoves.count == 3 {rdMoves += [currentLocation!]}
            default:
                break
            }
        }
    }
    
    //Command attributes
    var isAllCav:Bool = false
    var isTwoPlusCorps:Bool = false
    var hasLeader:Bool = false
    var theLeader:Unit?
    
    var commandSide:Allegience = .Neutral
    
    //Check whether current location is at a reserve or approach (true)
    var isNonViableLocation:Bool {
        
        if self.currentLocationType == .Start {return false} else {return true}
        //return (!self.currentLocation!.isStartLocation)
    }

    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //Initializer for game start and saved games
    init (theDict:Dictionary<NSObject, AnyObject>) {
        
        //Store the starting location type and name
        loc = theDict["loc"] as AnyObject? as! String
        locID = theDict["locID"] as AnyObject? as! String
        self.rdMoves = []
        
        super.init()

        //Converts the unit string into array of doubles
        let theUnits:String = theDict["units"] as AnyObject? as! String
        let unitsAsArray:Array = (theUnits.characters).split{$0 == " "}.map(String.init)
        var unitsAsArrayDouble:[Double] = []
        
        for unitAsString in unitsAsArray {
            unitsAsArrayDouble += [Double(unitAsString)!]
        }
        
        let theX:String = theDict["x"] as AnyObject? as! String
        let x:CGFloat = CGFloat(Float(theX)!)*mapScaleFactor
        
        let theY:String = theDict["y"] as AnyObject? as! String
        let y:CGFloat = CGFloat(Float(theY)!)*mapScaleFactor
        
        let theZ:String = theDict["z"] as AnyObject? as! String
        let z:CGFloat = CGFloat(Double(theZ)!)
        
        let theZrot:String = theDict["zRot"] as AnyObject? as! String
        let zRot:Int = Int(theZrot)!
        
        self.zPosition = z
        self.zRotation = zRot.degreesToRadians
        self.position = CGPoint(x: x, y: y)
        
        //Sets to French if condition applies
        if unitsAsArrayDouble[0] > 100 {commandSide = .Austrian}
        if unitsAsArrayDouble[0] > 200 {commandSide = .French}
        
        for each in unitsAsArrayDouble {createUnit(each)}
        
        //Make new location for the command (no reserve or approach)
        
        currentLocation = Location(nodePosition: self.position, nodeRotation: self.zRotation)
        currentLocationType = .Start
        
        self.parent?.addChild(currentLocation!)
        //currentLocation?.occupants += [self]
        
        //selector = SpriteSelector(parentNode: self as SKNode, initialSelection: .Off, theCoordinateSystem: self as SKNode, passDrawType: "Command")
        
    }
    
    //For creating detached units
    init (creatingCommand:Command, creatingUnits:[Unit]) {
        
        loc = ""
        locID = ""
        currentLocation = creatingCommand.currentLocation
        currentLocationType = creatingCommand.currentLocationType
        if currentLocationType != .Start {self.rdMoves = [currentLocation!]} else {self.rdMoves = []}
        
        super.init()
        
        self.zPosition = creatingCommand.zPosition
        self.zRotation = creatingCommand.zRotation
        self.position = creatingCommand.position
        self.commandSide = creatingCommand.commandSide

        //for each in creatingUnits {createUnit(each.unitCode)}
        for each in creatingUnits {
            
            let oldCommand:Command = each.parent as! Command

            each.removeFromParent()
            self.addChild(each)
            each.parentCommand = self
            each.zPosition = 100
            self.units += [each]
            self.unitsUpkeep() // Doesn't seem to call it in an init...
            oldCommand.units.removeObject(each)
        }
       
        //currentLocation?.occupants += [self]
        //selector = SpriteSelector(parentNode: self as SKNode, initialSelection: .Off, theCoordinateSystem: self as SKNode, passDrawType: "Command")

    }
    
    deinit {
        print("DEINIT Command")
    }
    
    // MARK: Unit related functions
    func createUnit(unitCode:Double) {
        
        let unitToCreate = Unit(unitCodePassedFromCommand: unitCode, pCommand: self)
        var indexToPlace:Int = 0
        
        for each in units {
            if each.unitCode > unitToCreate.unitCode {indexToPlace++}
        }
        
        units.insert(unitToCreate, atIndex: indexToPlace)
        
        //Add unit to Command
        self.addChild(unitToCreate)
        unitToCreate.zPosition = 100
    }
    
    func unitsUpkeep(reshuffle:Bool = true) {
        
        var nonLeaderCount = 0
        var cavCount = 0
        hasLeader = false
        isTwoPlusCorps = false
        isAllCav = false
        unitCount = 0
        activeUnits = []

        var activeUnitOrder:[Int] = []
        for each in units {
            if each.unitStrength == 0 {continue} // Skip "dead" units
            
            var position = 0
            for eachIndex in activeUnitOrder {
                if units[eachIndex].unitCode >= each.unitCode {position++}
            }
            activeUnitOrder.insert(units.indexOf(each)!, atIndex: position)
            
            activeUnits += [each]
            
            if each.unitType == .Ldr {
                hasLeader = true
                theLeader = each
            } else if each.unitType == .Cav {
                cavCount++; nonLeaderCount++
            } else if each.unitType == .Inf {
                nonLeaderCount++
            } else if each.unitType == .Art {
                nonLeaderCount++
            } else if each.unitType == .Grd {
                nonLeaderCount++
            }
        }
        
        var count = 0
        for eachIndex in activeUnitOrder {
            units[eachIndex].position.y = -CGFloat(count)*unitHeight*mapScaleFactor
            count++
        }
        
        //Set command properties
        if nonLeaderCount == cavCount {isAllCav = true}
        
        if hasLeader && nonLeaderCount > 1 {isTwoPlusCorps = true}
        unitCount = nonLeaderCount
        
        // Case of a dead command (place in heaven or resurrect)
        if nonLeaderCount <= 0 && self.currentLocationType != .Heaven {
            self.currentLocationType = .Heaven
            self.currentLocation!.occupants.removeObject(self)
        } else if self.currentLocationType == .Heaven {
            self.currentLocationType = self.currentLocation!.locationType
            self.currentLocation?.occupants += [self]
        }
        
        // Reshuffle current location (if units were added/subtracted)
        if reshuffle {self.currentLocation?.reShuffleLocation()}
    }
    
    // MARK: Highlight (indicate that the command is highlighted)
    
    func passUnitTo(unitToPass: Unit, recievingCommand:Command) {
        
        // Verify that unit is part of the group:
        if units.contains(unitToPass) {
            
            let selectionStatus = unitToPass.selected
            unitToPass.removeFromParent() // Remove from calling command
            recievingCommand.addChild(unitToPass) // Add to new parent
            unitToPass.parentCommand = recievingCommand
            unitToPass.zPosition = 100
            recievingCommand.units += [unitToPass]
            units.removeObject(unitToPass) // Remove from calling command's unit list
            
            unitsUpkeep()
            recievingCommand.unitsUpkeep()
            unitToPass.selected = selectionStatus
            
        }
    }
    
    func SetUnitsZ(zValue:CGFloat) {
        self.zPosition = 0
        for eachUnit in activeUnits {eachUnit.zPosition = zValue}
    }
    
}