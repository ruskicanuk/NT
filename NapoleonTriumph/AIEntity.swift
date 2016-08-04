//
//  AIEntity.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-05.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

import Foundation
import SpriteKit

// Parent for AIGroup and AILocale both of which share common characteristics such as detecting nearby threats
class AIEntity {
    
    var control:Allegience
    var reserve:Reserve?

    var approaches:[Approach] = []
    var aiGroupOnApproach:Bool = false
    
    var adjThreats:[Approach:[Command]] = [:]
    var rdThreats:[Approach:[Command]] = [:]
    var nextTurnAdjThreats:[Approach:[Command]] = [:]
    
    // AIGroup
    init(passedAllegience:Allegience) {
        
        control = passedAllegience
        
    }
    
    // AILocale or AIGroup
    init(passedReserve:Reserve) {
        
        reserve = passedReserve
        if reserve!.ownApproaches.count > 0 {
        
            approaches = reserve!.ownApproaches
        
        }
        control = reserve!.localeControl
    
    }
    
    // Refresh the relevant nearby threats - for AILocale this is which commands can attack it, for AIGroup this is which commands it can attack
    // theAIGroup: This is the AIGroup (for the case where the AIEntity is an AIGroup)
    func updateCurrentThreats(theAIGroup:AIGroup? = nil) {
        
        if reserve == nil {return} // EH
        
        var theApproaches:[Approach] = []

        if theAIGroup != nil && aiGroupOnApproach {
            
            theApproaches = [theAIGroup!.group.command.currentLocation! as! Approach]
        
        } else {
        
            theApproaches = approaches
            
        }
        
        for eachApproach in theApproaches {
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            let isAILocale:Bool = theAIGroup == nil
            let adjEnemyOccupied = oppReserve.localeControl.Other() == reserve!.localeControl
            let adjFriendlyOccupied = oppReserve.localeControl == reserve!.localeControl
            var blocked = false
            var theThreats:[Command] = []
            
            if eachApproach.oppApproach!.occupantCount > 0 && adjEnemyOccupied {
                
                theThreats += eachApproach.oppApproach!.occupants
            }
            if (oppReserve.occupantCount > 0 && (theThreats.count == 0 || isAILocale) && adjEnemyOccupied) {
            
                theThreats += oppReserve.occupants
            
            }
            adjThreats[eachApproach] = theThreats
            if theThreats.count > 0 && !isAILocale {blocked = true}
            else if adjFriendlyOccupied && isAILocale {blocked = true}
            else if aiGroupOnApproach {blocked = true}
            
            var reservePaths:[[Reserve]] = []
            
            for eachReservePath in reserve!.rdReserves {
                
                if eachReservePath[1] == oppReserve && !blocked {
                
                    reservePaths += [eachReservePath]
                
                }
                
            }
            
            var theRdThreats:[Command] = []
            
            for eachReservePath in reservePaths {
                
                let pathLength = eachReservePath.count

                for i in 2 ..< pathLength {
                    
                    if eachReservePath[i].localeControl == reserve!.localeControl && isAILocale {break}
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve!.localeControl {
                        
                        theRdThreats += eachReservePath[i].occupants
                        if !isAILocale {break}
                    
                    }
                
                }
            
            }
            rdThreats[eachApproach] = theRdThreats
        }
    }
    
    func updateNextTurnThreats (theAIGroup:AIGroup? = nil) {
        
        if theAIGroup != nil {return} // No functionality yet for AIGroup, leave off as its quite speculative for the AI since opponent can change positioning (maybe use something like this to find guys who are on the approach)
        
        for eachApproach in approaches {
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            var theNextTurnAdjThreats:[Command] = []
            var rdLessAdjacents:[Reserve] = oppReserve.adjReserves
            
            // Captures the guys who can rd-move in (and sets up the adjacent reserves with no roads)
            for eachReservePath in oppReserve.rdReserves {
                
                let pathLength = eachReservePath.count
                rdLessAdjacents.removeObject(eachReservePath[1])
                for i in 1 ..< pathLength {
                    
                    if eachReservePath[i] == reserve {break}
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve!.localeControl {
                        theNextTurnAdjThreats += eachReservePath[i].occupants
                    }
                
                }
            
            }
            
            // Captures the guys who are in an adjacent rd-less
            for eachReserve in rdLessAdjacents {
                
                if eachReserve.occupantCount > 0 && eachReserve.localeControl.Other() == reserve!.localeControl {
                    
                    theNextTurnAdjThreats += eachReserve.occupants
                
                }
            
            }
            
            // Captures the guys who are on the approach adjacent to the adjacent to the reserve under review
            for eachApproach in oppReserve.ownApproaches {
                
                if eachApproach.oppApproach!.occupantCount > 0 && eachApproach.oppApproach!.ownReserve!.localeControl.Other() == reserve!.localeControl {
                    
                    theNextTurnAdjThreats += eachApproach.oppApproach!.occupants
                
                }
                
            }
            nextTurnAdjThreats[eachApproach] = theNextTurnAdjThreats
        
        }
    
    }
    
    // Specify "type" of threat (adjacent, rd or next turn adjacent) and unit-type (All, Cav, Inf, Art, Ldr)
    // type: the kind of threat, subType: the kind of unit(s), passedApproach: approach that the theat is coming by
    // Int: Number of blocks in the specified threat
    func countThreatBlocks(type:String = "adj", subType:String = "All", passedApproach:Approach) -> Int {
        
        var threatCommands:[Command] = []
    
        switch type {
            
            case "adj": if adjThreats[passedApproach] != nil {threatCommands = adjThreats[passedApproach]!}
            case "rd": if rdThreats[passedApproach] != nil {threatCommands = rdThreats[passedApproach]!}
            case "NextTurnAdj": if nextTurnAdjThreats[passedApproach] != nil {threatCommands = nextTurnAdjThreats[passedApproach]!}
            default: break
            
        }
        
        var blockCount = 0
        for eachCommand in threatCommands {
        
            switch subType {
                
                case "All": blockCount += eachCommand.unitCount
                case "Cav": blockCount += eachCommand.cavUnits.count
                case "Inf": blockCount += eachCommand.infPlusGrdUnits.count
                case "Art": blockCount += eachCommand.artUnits.count
                case "Ldr": blockCount += eachCommand.activeUnits.count - eachCommand.unitCount
                default: blockCount += eachCommand.unitCount
                
            }
        }
        return blockCount
    }
}

// AI associated with a locale
class AILocale:AIEntity {
    
    // Measures of locale vulnerability
    var potentialFlanks:Int = 0
    var nextTurnPotentialFlanks:Int = 0
    
    // Defense-level per approach, = strength potential (1 + 2 or 2 + 2 depending on approach being wide or narrow) - array deals with depth
    var approachDefenseRating:[Approach:[Int]] = [:]
    var approachCounterRating:[Approach:Int] = [:]
    var reserveDefenseRating:([Int], [Int]) = ([0], [0]) // Narrow / wide
    var reserveCounterRating:Int = 0
    
    // Number of blocks available to defend
    var reserveBlocks:Int = 0
    var reserveCavBlocks:Int = 0
    var reserveInfBlocks:Int = 0
    var reserveGrdBlocks:Int = 0
    var reserveArtBlocks:Int = 0
    
    override init(passedReserve:Reserve) {
        
        super.init(passedReserve: passedReserve)
    
    }

}

// Attributes associated with an array of AIGroups
class AIMultipleGroups {
    
    var selectedAIGroups:[AIGroup] = []
    
    init(passedGroups:[AIGroup]) {
        
        selectedAIGroups = passedGroups
    
    }
    
    // Returns the units and strength of the counter-attacking group
    // Int: Total strength of the groups, aiGroup: the counter attack group, [Unit]: the counter attacking units
    func aiGroupsCounter() -> (Int, AIGroup, [Unit]) {
    
        var counterSize:Int = 0
        var counterAIGroup:AIGroup = self.selectedAIGroups[0]
        var counterUnits:[Unit] = []
        
        for eachType in ["Int", "Cav", "Grd"] {
            
            for eachGroup in selectedAIGroups {
            
                let (_, _, groupUnits) = eachGroup.aiGroupSelectUnits(eachType)
                let aiGroupCounter = eachGroup.aiGroupSelectUnitsTopX(groupUnits, topX: 2, startX: 1)
                if aiGroupCounter.0 > counterSize {
                    
                    counterSize = aiGroupCounter.0
                    counterAIGroup = eachGroup
                    counterUnits = aiGroupCounter.2
                    
                }
            }
        }
        return (counterSize, counterAIGroup, counterUnits)
    }
}

// AI associated with a group
class AIGroup:AIEntity {
    
    // Role for each individual group
    enum GroupRole {case Harasser, Screener, StrategicGoal, Support, Organize}
    
    var group:Group
    var role:GroupRole?
    var intendedLeader:Unit? // Set to nil if the group is "independent" (or plans to be independent), otherwise it points to the leader unit (could be a different command's leader unit if in organizing mode)
    
    // Used by aiGroups when determining strengths
    var orderedUnits:[String:Unit?] = [:]
    
    init(passedUnits:[Unit]) {
        
        group = Group(theCommand: passedUnits[0].parentCommand!, theUnits: passedUnits)
        //aiCommand = group.command
        
        var theReserve:Reserve
        
        if group.command.currentLocationType == .Reserve {
            
            theReserve = group.command.currentLocation! as! Reserve
            super.init(passedReserve: theReserve)
            self.aiGroupOnApproach = false
            
        } else if group.command.currentLocationType == .Approach {
            
            theReserve = (group.command.currentLocation! as! Approach).ownReserve!
            super.init(passedReserve: theReserve)
            self.aiGroupOnApproach = true
        
        } else {
        
            super.init(passedAllegience: group.command.commandSide)
            self.aiGroupOnApproach = false
        
        }
        
        self.aiGroupOrganizeUnits()
    
    }
    
    // Sets up the orderedUnits dictionary for an aiGroup
    // maxTypeSize: Max number of units to loop through in sorting
    func aiGroupOrganizeUnits(maxTypeSize:Int = 8) {
        
        for eachUnit in self.group.units {
            
            let orderedCode = eachUnit.unitTypeName()
            var insertPosition:Int = 0
            var totalLength:Int = 0
            
            for i in 1 ... maxTypeSize {
                
                if orderedUnits[orderedCode + String(i)] == nil {totalLength = i; break}
                else if eachUnit.unitStrength > orderedUnits[orderedCode + String(i)]!!.unitStrength && insertPosition == 0 {insertPosition = i}
            
            }
            
            for i in insertPosition ..< totalLength {
                
                orderedUnits[orderedCode + String(i+1)] = orderedUnits[orderedCode + String(i)]
            
            }
            orderedUnits[orderedCode + String(insertPosition)] = eachUnit
        
        }
    
    }
    
    // Defense select function, Attacker select function
    
    // Returns the strength, # of blocks and units matching a unit type in a group
    // unitCode: Unit type (Inf, Cav, Art, Grd, Ldr, All)
    // Int: aggregate strength of that unit type, Int: number of blocks of that unit type, [Unit]: the units that match the unit type
    func aiGroupSelectUnits(unitCode:String) -> (Int, Int, [Unit]) {
        
        // Unit Codes:
        var strength:Int = 0
        var blocks:Int = 0
        var theUnits:[Unit] = []
        
        for i in 1 ... 8 {
            
            if orderedUnits[unitCode + String(i)] != nil {strength = strength + orderedUnits[unitCode + String(i)]!!.unitStrength; theUnits += [orderedUnits[unitCode + String(i)]!!]; blocks += 1}
            
            else {break}
        
        }
        return (strength, blocks, theUnits)
    
    }
    
    // Return attributes associated with X units
    // theUnits: units generally already ordered from strongest to weakest, topX: number of units to consider, startX: Number from strongest to start from
    // Int: total strength of the X units, Int: number of blocks of the X units, [Unit]: array of the X units
    func aiGroupSelectUnitsTopX(theUnits:[Unit], topX:Int = 1, startX:Int = 1, excludeUnits:[Unit] = []) -> (Int, Int, [Unit]) {
    
        var newUnits:[Unit] = []
        var newStrength:Int = 0
        var newBlocks:Int = 0
        var count:Int = 0
        
        if topX <= 0 {
        
            return (0,0,[])
        
        } else {
            
            for i in startX - 1 ..< theUnits.count {
                
                if count < topX && !excludeUnits.contains(theUnits[i]) {
                
                    newUnits += [theUnits[i]]
                    newBlocks += 1
                    newStrength += theUnits[i].unitStrength
                    count += 1
            
                }
                
            }
        
        }
        return (newStrength, newBlocks, newUnits)
        
    }
    
    // Refresh the command associated with the first unit of the aiGroup
    /*
    func refreshCommand() {
        
        aiCommand = group.units[0].parentCommand!
        
    }
    */

}

/*
class AICommand:AIEntity {
    
    // Purpose is to set attributes for the aiGroup initializer to use
    var aiCommand:Command
    
    // Query: Code:Value
    // Codes: infWA, cavWA, artWA, grdWA, trpWA, infNA, cavNA, artNA, grdNA, trpNA, cmdWA, cmdNA, defWA, defNA

    
    init(passedCommand:Command) {
        aiCommand = passedCommand
    
    var theReserve:Reserve
    var approachCommand:Bool = false
    
    if aiCommand.currentLocationType == .Reserve {
        
        theReserve = aiCommand.currentLocation! as! Reserve
        super.init(passedReserve: theReserve)
    
    } else if aiCommand.currentLocationType == .Approach {
    
        theReserve = (aiCommand.currentLocation! as! Approach).ownReserve!
    
        approachCommand = true
        super.init(passedReserve: theReserve)
    
    } else {
    
        super.init(passedAllegience: aiCommand.commandSide)
    }
    
    self.aiGroupOnApproach = approachCommand
        
    }
    
    
}

class AIUnit:AIEntity {

    var unit:Unit

    init(passedUnit:Unit) {
        
        unit = passedUnit
        super.init(passedControl: passedUnit.unitSide)
    }
    
}
*/

// Tracks attributes about a group of Nodes
class NodeChain {

    //var startReserve:Reserve
    //var endReserve:Reserve
    
    // Shortest road path
    var nodes:[AILocale] = []
    
    // Shortest adjacent path
    var shortestAdjPath:[Reserve] = []
    
    // Stores a 2D array of all potential road paths (for objective markers)
    var possibleRdRoutes:[[Reserve]] = []
    
    init() {
        
    }

}