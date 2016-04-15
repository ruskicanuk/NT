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
    
    // AILocale
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
            
            theApproaches = [theAIGroup!.aiCommand.currentLocation! as! Approach]
        
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

                for var i = 2; i < pathLength; i++ {
                    
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
        
        if theAIGroup != nil {return} // No functionality yet for AIGroup
        for eachApproach in approaches {
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            var theNextTurnAdjThreats:[Command] = []
            var rdLessAdjacents:[Reserve] = oppReserve.adjReserves
            
            for eachReservePath in oppReserve.rdReserves {
                
                let pathLength = eachReservePath.count
                rdLessAdjacents.removeObject(eachReservePath[1])
                for var i = 1; i < pathLength; i++ {
                    
                    if eachReservePath[i] == reserve {break}
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve!.localeControl {
                    
                        theNextTurnAdjThreats += eachReservePath[i].occupants
                    
                    }
                
                }
            
            }
            for eachReserve in rdLessAdjacents {
                
                if eachReserve.occupantCount > 0 && eachReserve.localeControl.Other() == reserve!.localeControl {
                    
                    theNextTurnAdjThreats += eachReserve.occupants
                
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
    
    // How many flank-threats exist (to the reserve)
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
class AIGroups {
    
    var aiGroups:[AIGroup] = []
    
    init(passedGroups:[AIGroup]) {
        aiGroups = passedGroups
    }
    
    // Returns the units and strength of a group
    // typeCode: ResDefense, AppDefense, Attack, CtrAttack
    func aiGroupsDefenseAndCounter(typeCode:String, wide:Bool, approach:Bool) -> (Int, [AIGroup], [Unit]) {
    
        // 1st: Calculate counter potential for each group (inf, grd, cav)
        // 2nd: Calculate defense potential for each counter group
        
        for eachGroup in aiGroups {
            
            //var counterStrengths:(Int, Int, Int) = (0, 0, 0)
            //var counterTypes:(String, String, String) = ("Inf", "Grd", "Cav")
            
            let (groupInfStrength, groupInfBlocks, groupInfUnits) = eachGroup.aiGroupSelectUnits("Int")
            let aiGroupInfSelection = eachGroup.aiGroupSelectUnitsTopX(groupInfUnits, topX: 2)
            
            let (groupCavStrength, groupCavBlocks, groupCavUnits) = eachGroup.aiGroupSelectUnits("Cav")
            let aiGroupCavSelection = eachGroup.aiGroupSelectUnitsTopX(groupCavUnits, topX: 2)
            
            let (groupGrdStrength, groupGrdBlocks, groupGrdUnits) = eachGroup.aiGroupSelectUnits("Grd")
            let aiGroupGrdSelection = eachGroup.aiGroupSelectUnitsTopX(groupGrdUnits, topX: 2)
            
            let counterStrengths = (groupInfStrength, groupGrdStrength, groupCavStrength)
            
            // Defense Selection
            var defenseUnits:[Unit] = []
            var defenseUnitsStrength:Int = 0
            
            for eachDefenseGroup in aiGroups {
                
                let aiDefenseGroupCount = eachDefenseGroup.group.units.count
                
                // Inf Counter Case
                switch (wide, approach) {
                    
                case (true, true): break
                    
                    // Go through first and second unit of each group, preference for strength and smaller groups
                    
                    
                default: break
                }
                
                
                
                // Cav Counter Case
                
                
                // Grd Counter Case
                
                
            }
            
        }
        
        // Counter: Determine candidate ctr attacks
        
        
        // ResDefense: inf, grd, cav, art
        // appDefense: 3-str inf, grd, art, 2-str inf, cav
        // attack:
        // Algo: assume groups are organized by command
        //
        
    return (0, [], [])
    }
    
}

// Inherits from command - these are AI commands identifiying threats / opportunities around them
class AIGroup:AIEntity {
    
    var group:Group
    var aiCommand:Command // Might be unnecessary (consider dropping this)
    
    // Used for aiCommands and aiGroups
    var orderedUnits:[String:Unit?] = [:]
    
    init(passedUnits:[Unit]) {
        
        group = Group(theCommand: passedUnits[0].parentCommand!, theUnits: passedUnits)
        aiCommand = group.command
        
        var theReserve:Reserve
        var approachCommand:Bool = false
        
        if group.command.currentLocationType == .Reserve {
            theReserve = group.command.currentLocation! as! Reserve
            super.init(passedReserve: theReserve)
        } else if group.command.currentLocationType == .Approach {
            theReserve = (group.command.currentLocation! as! Approach).ownReserve!
            approachCommand = true
            super.init(passedReserve: theReserve)
        } else {
            super.init(passedAllegience: aiCommand.commandSide)
        }
        
        self.aiGroupOnApproach = approachCommand
        self.aiGroupOrganizeUnits(group.units)
    }
    
    // Sets up the orderedUnits dictionary for aiGroup
    func aiGroupOrganizeUnits(theUnits:[Unit], maxTypeSize:Int = 8) {
        
        for eachUnit in theUnits {
            
            let orderedCode = eachUnit.name!
            
            // Other codes: ctr, def, att [probably deal with in other logic]
            
            var insertPosition:Int = maxTypeSize
            var totalLength:Int = 0
            
            for var i = 1; i <= maxTypeSize; i++ {
                
                if orderedUnits[orderedCode + String(i)] == nil {totalLength = i; break}
                else if eachUnit.unitStrength > orderedUnits[orderedCode + String(i)]!!.unitStrength && insertPosition == 0 {insertPosition = i}
            }
            
            for var i = insertPosition; i < totalLength; i++ {
                
                orderedUnits[orderedCode + String(i+1)] = orderedUnits[orderedCode + String(i)]
            }
            orderedUnits[orderedCode + String(insertPosition)] = eachUnit
        }
    }
    
    // Returns the strength, # of blocks and units matching a unit type in a group
    func aiGroupSelectUnits(typeCode:String) -> (Int, Int, [Unit]) {
        
        // Type Codes: Inf, Cav, Art, Grd, Ldr, All
        var strength:Int = 0
        var blocks:Int = 0
        var theUnits:[Unit] = []
        
        for var i = 1; i <= 8; i++ {
            if orderedUnits[typeCode + String(i)] != nil {strength = strength + orderedUnits[typeCode + String(i)]!!.unitStrength; theUnits += [orderedUnits[typeCode + String(i)]!!]; blocks++}
            else {break}
        }
        
        return (strength, blocks, theUnits)
    }
    
    // Return attributes associated with X units
    // theUnits: units generally already ordered from strongest to weakest, topX: number of units to consider
    // 1st Int: total strength of the X units, 2nd Int: number of blocks of the X units, [Unit]: array of the X units
    func aiGroupSelectUnitsTopX(theUnits:[Unit], topX:Int = 0) -> (Int, Int, [Unit]) {
    
        var newUnits:[Unit] = []
        var newStrength:Int = 0
        var newBlocks:Int = 0
        
        if topX <= 0 {
        
            return (0,0,[])
        
        } else {
            
            for var i = 0; i < theUnits.count; i++ {
                
                if i < topX {
                    newUnits += [theUnits[i]]
                    newBlocks++
                    newStrength += theUnits[i].unitStrength
                }
            }
        }
        
        return (newStrength, newBlocks, newUnits)
    }
    
    // Refresh the command associated with the first unit of the aiGroup
    func refreshCommand() {
        
        aiCommand = group.units[0].parentCommand!
    }
}

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

/*
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