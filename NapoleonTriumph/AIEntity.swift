//
//  LinePath.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-05.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

import Foundation
import SpriteKit

// AI Entities can be locales (for testing threat conditions), groups and commands
class AIEntity {
    
    var control:Allegience
    var reserve:Reserve?

    var approaches:[Approach] = []
    var commandOnApproach:Bool = false
    
    // Threats
    var adjThreats:[Approach:[Command]] = [:]
    var rdThreats:[Approach:[Command]] = [:]
    var nextTurnAdjThreats:[Approach:[Command]] = [:]
    
    // Applies to AICommand, AIGroup
    init(passedAllegience:Allegience) {
        control = passedAllegience
    }
    
    // Applies to AILocale
    init(passedReserve:Reserve) {
        reserve = passedReserve
        if reserve!.ownApproaches.count > 0 {
            approaches = reserve!.ownApproaches
        }
        control = reserve!.localeControl
    }
    
    // Applies to all child classes
    func updateCurrentThreats(theCommand:Command? = nil) {
        
        if reserve == nil {return} // Catch accidental units coming here
        
        var theApproaches:[Approach] = []

        // Checks if entity is a command on the approach (more limited options)
        if theCommand != nil && commandOnApproach {
            theApproaches = [theCommand!.currentLocation! as! Approach]
        } else {
            theApproaches = approaches
        }
        
        // Threat routine
        for eachApproach in theApproaches {
            
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            let mayPassThruEnemy:Bool = theCommand == nil // Threats on AILocale ignore enemies
            let mayPassThruFriendly:Bool = theCommand != nil // Threats on AIGroup ignore friendlies
            let adjEnemyOccupied = oppReserve.localeControl.Other() == reserve!.localeControl
            let adjFriendlyOccupied = oppReserve.localeControl == reserve!.localeControl
            var blocked = false
              
            // Captures adjacent enemies (or blank array if neutral)
            var theThreats:[Command] = []
            if eachApproach.oppApproach!.occupantCount > 0 && adjEnemyOccupied {
                theThreats += eachApproach.oppApproach!.occupants
            }
            if (oppReserve.occupantCount > 0 && (theThreats.count == 0 || mayPassThruEnemy) && adjEnemyOccupied) {
                theThreats += oppReserve.occupants
            }
            adjThreats[eachApproach] = theThreats
            
            if theThreats.count > 0 && !mayPassThruEnemy {blocked = true}
            else if adjFriendlyOccupied && !mayPassThruFriendly {blocked = true}
            else if commandOnApproach {blocked = true}
            
            // Determine which rd paths can attack the node
            var reservePaths:[[Reserve]] = []
            for eachReservePath in reserve!.rdReserves {
                if eachReservePath[1] == oppReserve && !blocked {
                    reservePaths += [eachReservePath]
                }
            }
            
            // From the viable rd-paths, determine if there are occupants
            var theRdThreats:[Command] = []
            for eachReservePath in reservePaths {
                
                let pathLength = eachReservePath.count

                for var i = 2; i < pathLength; i++ {
                    
                    if eachReservePath[i].localeControl == reserve!.localeControl && !mayPassThruFriendly {break}
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve!.localeControl {
                        theRdThreats += eachReservePath[i].occupants
                        if !mayPassThruEnemy {break}
                    }
                }
            }
            rdThreats[eachApproach] = theRdThreats
        }
    }
    
    func updateNextTurnThreats (theCommand:Command? = nil) {
        
        if theCommand == nil {return} // No functionality yet for commands
        
        for eachApproach in approaches {
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            
            // Determine which commands can move to the adjacent locale
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
    
    // Specify "type" of threat (adjacent, rd or next turn adjacent) and unit-type (Cav, Inf, etc)
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
                
                case "Inf": blockCount += eachCommand.infPlusGrdUnits.count // Inf + Grd
                
                case "Art": blockCount += eachCommand.artUnits.count
                
                case "Ldr": blockCount += eachCommand.activeUnits.count - eachCommand.unitCount
                    
                default: blockCount += eachCommand.unitCount
                
            }
        }
        
        return blockCount
    }
}

// Inhereits from command - these are AI commands identifiying threats / opportunities around them
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

// Inherits from command - these are AI commands identifiying threats / opportunities around them
class AIGroup:AIEntity {
    
    var group:Group
    var aiCommand:Command // Might be unnecessary (consider dropping this)
    
    // Used for aiCommands and aiGroups
    var gotoUnits:[String:Unit?] = [:]
    
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
        
        self.commandOnApproach = approachCommand
        self.updateAIGotoUnits(group.units)
    }
    
    // Sets up the gotoCode dictionary for aiGroup
    func updateAIGotoUnits(theUnits:[Unit]) {
        
        for eachUnit in theUnits {
            
            let gotoCode1 = eachUnit.name! + "1"
            let gotoCode2 = eachUnit.name! + "2"
            
            // Other codes: ctr, def, att [probably deal with in other logic]
            
            if gotoUnits[gotoCode1] == nil {
                
                gotoUnits[gotoCode1] = eachUnit
                
            } else if gotoUnits[gotoCode2] == nil {
                
                if eachUnit.unitStrength > gotoUnits[gotoCode1]!!.unitStrength {
                    gotoUnits[gotoCode2] = gotoUnits[gotoCode1]
                    gotoUnits[gotoCode1] = eachUnit
                } else {
                    gotoUnits[gotoCode2] = eachUnit
                }
                
            } else {
                
                if eachUnit.unitStrength > gotoUnits[gotoCode1]!!.unitStrength {
                    gotoUnits[gotoCode2] = gotoUnits[gotoCode1]
                    gotoUnits[gotoCode1] = eachUnit
                } else if eachUnit.unitStrength > gotoUnits[gotoCode2]!!.unitStrength {
                    gotoUnits[gotoCode2] = eachUnit
                }
                
            }
        }
    }

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
    
    self.commandOnApproach = approachCommand
        
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