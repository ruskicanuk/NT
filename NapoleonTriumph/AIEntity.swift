//
//  LinePath.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-05.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

import Foundation
import SpriteKit

// Tracks locale states and other locale attributes
class AIEntity {
    
    var control:Allegience
    var reserve:Reserve
    var command:Command?
    var approaches:[Approach] = []
    var commandOnApproach:Bool = false
    
    // Threats
    var adjThreats:[Approach:[Command]] = [:]
    var rdThreats:[Approach:[Command]] = [:]
    var nextTurnAdjThreats:[Approach:[Command]] = [:]
    
    init(passedReserve:Reserve) {
        reserve = passedReserve
        if reserve.ownApproaches.count > 0 {
            approaches = reserve.ownApproaches
        }
        control = reserve.localeControl
    }
    
    func updateCurrentThreats() {
        
        var theApproaches:[Approach] = []

        // Checks if entity is a command on the approach (more limited options)
        if command != nil && commandOnApproach {
            theApproaches = [command!.currentLocation! as! Approach]
        } else {
            theApproaches = approaches
        }
        
        // Threat routine
        for eachApproach in theApproaches {
            
            let oppReserve = eachApproach.oppApproach!.ownReserve!
            
            let mayPassThruEnemy:Bool = command == nil
            
            let mayPassThruFriendly:Bool = command != nil

            let adjEnemyOccupied = oppReserve.localeControl.Other() == reserve.localeControl
            let adjFriendlyOccupied = oppReserve.localeControl == reserve.localeControl
            
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
            for eachReservePath in reserve.rdReserves {
                if eachReservePath[1] == oppReserve && !blocked {
                    reservePaths += [eachReservePath]
                }
            }
            
            // From the viable rd-paths, determine if there are occupants
            var theRdThreats:[Command] = []
            for eachReservePath in reservePaths {
                
                let pathLength = eachReservePath.count

                for var i = 2; i < pathLength; i++ {
                    
                    if eachReservePath[i].localeControl == reserve.localeControl && !mayPassThruFriendly {break}
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve.localeControl {
                        theRdThreats += eachReservePath[i].occupants
                        if !mayPassThruEnemy {break}
                    }
                }
            }
            rdThreats[eachApproach] = theRdThreats
        }
    }
    
    func updateNextTurnThreats () {
        
        if command == nil {return} // No functionality yet for commands
        
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
                    else if eachReservePath[i].occupantCount > 0 && eachReservePath[i].localeControl.Other() == reserve.localeControl {
                        theNextTurnAdjThreats += eachReservePath[i].occupants
                    }
                }
            }
            for eachReserve in rdLessAdjacents {
                if eachReserve.occupantCount > 0 && eachReserve.localeControl.Other() == reserve.localeControl {
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
                
                case "Inf": blockCount += eachCommand.infUnits.count // Inf + Grd
                
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
    
    // Defense-level per approach, = strength potential (1 + 2 or 2 + 2 depending on approach being wide or narrow)
    var approachDefenseRating:[Approach:Int] = [:]
    var reserveDefenseRating:Int = 0
    
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
class AICommand:AIEntity {
    
    init(passedCommand:Command) {
        
        var theReserve:Reserve
        var approachCommand:Bool = false
        
        if passedCommand.currentLocationType == .Reserve {
            theReserve = passedCommand.currentLocation! as! Reserve
        } else {
            theReserve = (passedCommand.currentLocation! as! Approach).ownReserve!
            approachCommand = true
        }
        
        super.init(passedReserve: theReserve)
        self.command = passedCommand
        self.commandOnApproach = approachCommand
        
    }
}

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