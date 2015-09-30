//
//  Conflict.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-08-28.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//


class Conflict {
    
    let defenseReserve:Reserve!
    let attackReserve:Reserve!
    let defenseApproach:Approach!
    let attackApproach:Approach!
    
    var defenseGroup:GroupSelection?
    var attackGroups:GroupSelection?
    var defenseSide:Allegience!
    
    var defenseLeadingUnits:GroupSelection?
    var availableCounterAttackers:GroupSelection? {
        // Safety check
        if defenseGroup == nil {return nil}
        if defenseLeadingUnits == nil {return defenseGroup}
        
        var theGroups:[Group] = []
        
        for eachGroup in defenseGroup!.groups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                let groupInLeadingUnits = defenseLeadingUnits!.groups.filter{$0.command == eachUnit.parentCommand}
                
                if groupInLeadingUnits.count == 1 && groupInLeadingUnits[0].units.contains(eachUnit) {
                    
                } else {
                    theUnits += [eachUnit]
                }
            }
            if !theUnits.isEmpty {
                theGroups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]
            }
        }
        return GroupSelection(theGroups: theGroups)
    }
    
    var attackLeadingUnits:GroupSelection?
    
    var potentialRdAttackers:[Command:[Reserve]] = [:] // Stores the reserve pathways possible
    var rdAttackerPath:[Reserve] = []
    var rdAttackerMultiPaths:[[Reserve]] = []
    //var postRetreatMode:Bool = false
    //var potentialAdjAttackers:[Command:[Location]] = [:]
    
    var defenseOrRetreatDeclared:Bool = false
    var defenseLeadingDeclared:Bool = false
    var attackOrFeintDeclared:Bool = false
    var attackLeadingDeclared:Bool = false
    
    var mustFeint:Bool = false
    
    var approachConflict:Bool = false
    var battleOccured:Bool = false
    
    weak var parentGroupConflict:GroupConflict?
    
    init(aReserve:Reserve, dReserve:Reserve, aApproach:Approach, dApproach:Approach, mFeint:Bool = false) {
        defenseReserve = dReserve
        attackReserve = aReserve
        defenseApproach = dApproach
        attackApproach = aApproach
        mustFeint = mFeint
        defenseSide = manager!.phasingPlayer.Other()
        
        for eachCommand in manager!.gameCommands[defenseSide.Other()!]! {
            
            let theRdPaths = RdCommandPathToConflict(eachCommand)
            if !theRdPaths.isEmpty {potentialRdAttackers[eachCommand] = theRdPaths}
        }
    }
    
    // Returns the road paths for a command to the conflict area (nil if no such road)
    func RdCommandPathToConflict (pCommand:Command) -> [Reserve] {
        guard let commandReserve = pCommand.currentLocation as? Reserve else {return []}
        var thePath:[Reserve] = []

        for eachPath in commandReserve.rdReserves {
            let pathLength = eachPath.count
            if pathLength == 3 {
                if eachPath[2] == defenseReserve && eachPath[1] == attackReserve {thePath += eachPath}
            } else if pathLength == 4 {
                if eachPath[2] == defenseReserve && eachPath[1] == attackReserve {
                    var adjustedPath = eachPath
                    adjustedPath.removeLast()
                    thePath += adjustedPath
                }
                else if eachPath[3] == defenseReserve && eachPath[2] == attackReserve {
                    thePath += eachPath
                }
            }
        }
        
        if thePath == [] {return []} else {return thePath}
    }

    /*
    // Nil if command is not adjacent, the location if it is
    func AdjCommandPathToConflict (pCommand:Command) -> [Location]? {
        
        if pCommand.currentLocation is Approach {
            let commandApproachLocation = pCommand.currentLocation as! Approach
            if commandApproachLocation == attackApproach {return [attackApproach]} else {return nil}
        }
        else if pCommand.currentLocation is Reserve {
            let commandReserveLocation = pCommand.currentLocation as! Reserve
            if commandReserveLocation == attackReserve {return [attackReserve, attackApproach]} else {return nil}
        }
        else {return nil}
    }

    */
}
class GroupConflict {
    
    var mustRetreat:Bool = false
    var mustDefend:Bool = false
    var retreatMode:Bool = false {
        didSet {
            if retreatMode {
                for eachConflict in conflicts {eachConflict.defenseApproach.hidden = true}
            } else {
                for eachConflict in conflicts {eachConflict.defenseApproach.hidden = false}
            }
        }
    }
    // Used to store number of orders for the purposes of releasing the mustRetreat / mustDefend condition when un-doing
    var retreatOrders:Int = 0
    var defenseOrders:Int = 0
    
    var twoPlusCorps:Bool = false
    
    // Returns if any reductions have been made
    var madeReductions:Bool {
        //var requiredReductions:Int = 0
        var actualReductions:Int = 0
        //for (_, required) in damageRequired {requiredReductions += required}
        //for (_, required) in destroyRequired {requiredReductions += required}
        for (_, required) in damageDelivered {actualReductions += required}
        for (_, required) in destroyDelivered {actualReductions += required}
        
        return actualReductions > 0
    }
    
    let defenseReserve:Reserve!
    let conflicts:[Conflict]!
    var threatenedApproaches:[Approach] = []
    var defendedApproaches:[Approach] = []
    var unresolvedApproaches:[Approach] {
        return Array(Set(threatenedApproaches).subtract(Set(defendedApproaches)))
    }
    var initialReductionsRequired:Int {
        var totalRequired:Int = 0
        for (_, reduction) in destroyRequired {totalRequired += reduction}
        for (_, reduction) in damageRequired {totalRequired += reduction}
        return totalRequired
    }
    var damageRequired:[Location:Int] = [:]
    var destroyRequired:[Location:Int] = [:]
    var damageDelivered:[Location:Int] = [:]
    var destroyDelivered:[Location:Int] = [:]
    //var battledLocations:[Location] = []
    
    init(passReserve:Reserve, passConflicts:[Conflict]) {

        defenseReserve = passReserve
        conflicts = passConflicts
        if defenseReserve.has2PlusCorps == .Neutral {twoPlusCorps = false} else {twoPlusCorps = true} // Saves whether the reserve has a two-plus Corps
        
        for eachConflict in conflicts {
            threatenedApproaches += [eachConflict.defenseApproach]
            eachConflict.parentGroupConflict = self
            // These are occupied approaches being threatened (all defenders on the approach are added automatically to the defense group)

            if eachConflict.defenseApproach.occupantCount > 0 {
                defendedApproaches += [eachConflict.defenseApproach]
                eachConflict.defenseGroup = GroupSelection(theGroups: GroupsFromCommands(eachConflict.defenseApproach.occupants, includeLeader: false), selectedOnly: false)
                eachConflict.approachConflict = true
            }
        }
        
        // Populate the requirements for retreating
        for eachApproach in defenseReserve.ownApproaches {
            var potentialLosses:Int = 0
            var potentialDestroyed:Int = 0
            for eachCommand in eachApproach.occupants {
                for eachUnit in eachCommand.nonLeaderNonArtUnits {
                    if !eachUnit.wasInBattle {potentialLosses += eachUnit.unitStrength}
                }
            potentialDestroyed += eachCommand.artUnits.count
            }
            
            damageRequired[eachApproach] = min(potentialLosses,eachApproach.approachLength)
            destroyRequired[eachApproach] = potentialDestroyed
            damageDelivered[eachApproach] = 0
            destroyDelivered[eachApproach] = 0
        }
        
        var maxWidth:Int = 0
        for eachVacantApproach in unresolvedApproaches {
            maxWidth = max(maxWidth, eachVacantApproach.approachLength)
        }
        
        var potentialLosses:Int = 0
        var potentialDestroyed:Int = 0
        for eachCommand in defenseReserve.occupants {
            for eachUnit in eachCommand.infUnits {
                if !eachUnit.wasInBattle {potentialLosses += eachUnit.unitStrength}
            }
            potentialDestroyed += eachCommand.artUnits.count
        }
        
        damageRequired[defenseReserve] = min(potentialLosses,maxWidth)
        destroyRequired[defenseReserve] = potentialDestroyed
        damageDelivered[defenseReserve] = 0
        destroyDelivered[defenseReserve] = 0
        
        // If there is an undefended threat with not enough available defenders
        //if unresolvedApproaches.count > defenseReserve.defendersAvailable {mustRetreat = true; retreatMode = true}
    }
    
}

class Group {
    
    let command:Command!
    let units:[Unit]!
    var nonLdrUnits:[Unit] {
        var theUnits:[Unit] = []
        for each in units {if each.unitType != .Ldr {theUnits += [each]}}
        return theUnits
    }
    var artOnly:Bool = true
    var leaderUnit:Unit?
    var fullCommand:Bool = false
    var leaderInGroup:Bool = false
    var allCav:Bool = true
    var someUnitsHaveMoved:Bool = false
    var cavCount:Int = 0
    var nonLdrUnitCount:Int = 0

    init(theCommand:Command, theUnits:[Unit]) {
        command = theCommand
        units = theUnits
        for eachUnit in theUnits {
            if eachUnit.unitType == .Ldr {leaderInGroup = true; cavCount++; leaderUnit = eachUnit} else if eachUnit.unitType == .Cav {cavCount++; nonLdrUnitCount++; artOnly = false} else if eachUnit.unitType == .Art {nonLdrUnitCount++} else {nonLdrUnitCount++; artOnly = false}
            if eachUnit.hasMoved {someUnitsHaveMoved = true}
        }
        
        if leaderInGroup && (nonLdrUnitCount+1) == command.unitCount {
            fullCommand = true
        } else if !leaderInGroup && nonLdrUnitCount == command.unitCount {
            fullCommand = true
        }
    }
    
}

class GroupSelection {
    
    var groups:[Group] = []
    var groupSelectionSize:Int = 0 // Number of blocks in the group
    
    var sameTypeSameCorps:Bool = false
    var sameType:Bool = false
    var anyOneStrengthUnits = false
    var blocksSelected = 0
        
    init(theGroups:[Group], selectedOnly:Bool = true) {
        
        var unitsTypes:[Type] = []
        var numberCorps:Int = 0
        var numberDetached:Int = 0
        
        for eachGroup in theGroups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                
                if eachUnit.selected == .Selected || !selectedOnly {
                    theUnits += [eachUnit] // Add to units
                    blocksSelected++
                    if eachUnit.unitType != .Ldr {groupSelectionSize++} // Increment group selection size
                    unitsTypes += [eachUnit.unitType] // Increment the unit type array
                    if eachUnit.unitStrength == 1 && eachUnit.unitType != .Ldr {anyOneStrengthUnits = true}

                }
                
            }
            
            if theUnits.count > 0 {
                groups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]
                if eachGroup.command.hasLeader {numberCorps++} else {numberDetached++}
            }
        }
        
        unitsTypes = Array(Set(unitsTypes))
        if unitsTypes.count == 1 && numberCorps == 1 && numberDetached == 0 {sameTypeSameCorps = true}
        if unitsTypes.count == 1 && numberCorps <= 2 && numberDetached == 0 {sameType = true}
        
    }
    
    func SetGroupSelectionPropertyUnitsHaveDefended(onOff:Bool) {
        for eachGroup in self.groups {
            for eachUnit in eachGroup.units {
                eachUnit.alreadyDefended = onOff
            }
        }
    }
}
