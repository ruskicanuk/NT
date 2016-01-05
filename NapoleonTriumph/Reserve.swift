//
//  Reserve.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

class Reserve:Location {
    
    // Attributes of the reserve area
    let capacity:Int!
    let blueStar:Bool!
    let redStar:Bool!
    let greenStar:Bool!
    let blackStar:Bool!
    
    var offMap:Bool = false
    
    var ownApproaches:[Approach] = []
    var adjReserves:[Reserve] = []
    var rdReserves:[[Reserve]] = []
    
    let ownApproachesName:[String]
    let adjReservesName:[String]
    var rdReservesName:[[String]] = []

    var commandsEntered:[Command] = []
    
    // Reserve state variables
    var currentFill:Int = 0 // Current number of units in the locale
    var availableSpace:Int {return (capacity - currentFill)}
    var localeControl:Allegience = .Neutral // Which side controls the locale
    var has2PlusCorps:Allegience = .Neutral // Whether the locale has a 2-Plus Corps (neutral means no)
    
    // Road Rules
    var containsAdjacent2PlusCorps:Allegience = .Neutral // Whether an adjacent locale has a 2-Plus Corps (neutral means no) RD RULE #3
    var has2PlusCorpsPassed:Bool = false // Whether a 2-Plus Corps has passed through RD RULE #2
    var haveCommandsEntered:Bool = false // Whether any units in the reserve entered during the turn RD RULE #1
    var unitsEnteredPostBattle:Bool = false
    var numberCommandsEntered:Int = 0
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init (theDict:Dictionary<NSObject, AnyObject>, scaleFactor:CGFloat, reserveLocation:Bool) {
        
        let theCapacity:String = theDict["size"] as AnyObject? as! String
        capacity = Int(theCapacity)!
        
        let blueStarStr:NSString = theDict["blueStar"] as AnyObject? as! NSString
        blueStar = blueStarStr.boolValue
        
        let greenStarStr:NSString = theDict["greenStar"] as AnyObject? as! NSString
        greenStar = greenStarStr.boolValue
        
        let blackStarStr:NSString = theDict["blackStar"] as AnyObject? as! NSString
        blackStar = blackStarStr.boolValue
        
        let redStarStr:NSString = theDict["redStar"] as AnyObject? as! NSString
        redStar = redStarStr.boolValue
        
        let theApproaches:String = theDict["approaches"] as AnyObject? as! String
        ownApproachesName = (theApproaches.characters).split{$0 == " "}.map(String.init)
        
        let theAdjReserves:String = theDict["adjReserves"] as AnyObject? as! String
        adjReservesName = (theAdjReserves.characters).split{$0 == " "}.map(String.init)
        
        let theRdReserves:String = theDict["rdReserves"] as AnyObject? as! String
        let rdReservesName1 = (theRdReserves.characters).split{$0 == "|"}.map(String.init)

        for each in rdReservesName1 {
            rdReservesName += [(each.characters).split{$0 == " "}.map(String.init)]
        }
        
        if theApproaches.isEmpty {offMap = true} else {offMap = false} // Initializes off-map reserves
        
        super.init(theDict: theDict, scaleFactor: scaleFactor, reserveLocation: reserveLocation)
        
        let theID:String = theDict["id"] as AnyObject? as! String
        self.name = theID
        
    }
    
    func UpdateReserveState() {
        
        var countApproachUnits = 0
        
        // Reserve State
        currentFill = 0
        localeControl = .Neutral
        has2PlusCorps = .Neutral
        
        // Rd Rules
        containsAdjacent2PlusCorps = .Neutral
        if unitsEnteredPostBattle {has2PlusCorpsPassed = true} else {has2PlusCorpsPassed = false}
        haveCommandsEntered = false
        numberCommandsEntered = 0

        // Step through the reserve's approaches
        for each in ownApproaches {
            
            countApproachUnits += each.occupantCount
            
            // Deals with the adjacent reserves
            for eachCommandInAdjReserve in each.oppApproach!.ownReserve!.occupants {
                if eachCommandInAdjReserve.isTwoPlusCorps {
                    if containsAdjacent2PlusCorps == .Neutral {containsAdjacent2PlusCorps = eachCommandInAdjReserve.commandSide}
                    if containsAdjacent2PlusCorps == .French && eachCommandInAdjReserve.commandSide == .Austrian {containsAdjacent2PlusCorps = .Both}
                    if containsAdjacent2PlusCorps == .Austrian && eachCommandInAdjReserve.commandSide == .French {containsAdjacent2PlusCorps = .Both}
                }
            }
            
            // Deals with the approaches in adjacent reserves
            for eachApproachInAdjReserve in each.oppApproach!.ownReserve!.ownApproaches {
                for eachCommandInApproach in eachApproachInAdjReserve.occupants {
                    if eachCommandInApproach.isTwoPlusCorps {
                        if containsAdjacent2PlusCorps == .Neutral {containsAdjacent2PlusCorps = eachCommandInApproach.commandSide}
                        if containsAdjacent2PlusCorps == .French && eachCommandInApproach.commandSide == .Austrian {containsAdjacent2PlusCorps = .Both}
                        if containsAdjacent2PlusCorps == .Austrian && eachCommandInApproach.commandSide == .French {containsAdjacent2PlusCorps = .Both}
                    }
                }
            }
            
            // Cycle through the approach occupants to set size and two plus corps status
            for eachApproachCommand in each.occupants {
                
                // Sets locale control
                if eachApproachCommand.commandSide == .Austrian {localeControl = .Austrian} else {localeControl = .French}
                if eachApproachCommand.isTwoPlusCorps {has2PlusCorps = eachApproachCommand.commandSide}
            }
            
        }

        for eachReserveCommand in self.occupants {
            
            if eachReserveCommand.commandSide == .Austrian {localeControl = .Austrian} else {localeControl = .French}
            if eachReserveCommand.isTwoPlusCorps {has2PlusCorps = eachReserveCommand.commandSide}
            if eachReserveCommand.moveNumber > 0 || eachReserveCommand.secondMoveUsed {haveCommandsEntered = true; commandsEntered += [eachReserveCommand]; numberCommandsEntered++}
        }
        
        // Eliminate duplicates
        commandsEntered = Array(Set(commandsEntered))
        
        // "Memory" of which commands have entered (two plus corps entry trips the rd blockage rules)
        for eachCommandEntered in commandsEntered {
            if eachCommandEntered.moveNumber == 0 && !eachCommandEntered.secondMoveUsed {commandsEntered.removeObject(eachCommandEntered)}
            if eachCommandEntered.moveNumber >= 2 {if eachCommandEntered.isTwoPlusCorps {has2PlusCorpsPassed = true}}
        }

        currentFill = (self.occupantCount + countApproachUnits)
    }
    
    func defendersAvailable(theLocaleThreat:GroupConflict?) -> Int {
        var defenderBlockCount:Int = 0
        for eachCommand in occupants {
            var theUnits:[Unit] = []
            if theLocaleThreat == nil {
                theUnits = eachCommand.availableToDefend(nil)
            } else {
                theUnits = eachCommand.availableToDefend(theLocaleThreat)
            }
            
            defenderBlockCount += theUnits.count
        }
        return defenderBlockCount
    }
    
    func ResetReserveState () {
        has2PlusCorpsPassed = false
        unitsEnteredPostBattle = false
        commandsEntered = []
        haveCommandsEntered = false
        numberCommandsEntered = 0
    }
}