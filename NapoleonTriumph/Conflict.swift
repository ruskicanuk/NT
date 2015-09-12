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
    
    var defenseGroup:[Group]?
    var attackGroups:[Group]?
    
    var defenseLeadingUnits:Group?
    var attackLeadingUnits:Group?
    
    var defenseOrRetreatDeclared:Bool = false
    var defenseLeadingDeclared:Bool = false
    var attackOrFeintDeclared:Bool = false
    var attackLeadingDeclared:Bool = false
    
    var mustFeint:Bool = false  // Remove?
    
    var approachConflict:Bool = false
    var battleOccured:Bool = false
    
    init(aReserve:Reserve, dReserve:Reserve, aApproach:Approach, dApproach:Approach, mFeint:Bool = false, mRetreat:Bool = false) {
        defenseReserve = dReserve
        attackReserve = aReserve
        defenseApproach = dApproach
        attackApproach = aApproach
        mustFeint = mFeint
    }
}

class GroupConflict {
    
    var mustRetreat:Bool = false
    var retreatMode:Bool = false
    
    let defenseReserve:Reserve!
    let conflicts:[Conflict]!
    var threatenedApproaches:[Approach] = []
    var defendedApproaches:[Approach] = []
    var unresolvedApproaches:[Approach] {
        return Array(Set(threatenedApproaches).subtract(Set(defendedApproaches)))
    }
    var damageRequired:[Location:Int] = [:]
    var destroyRequired:[Location:Int] = [:]
    var damageDelivered:[Location:Int] = [:]
    var destroyDelivered:[Location:Int] = [:]
    //var battledLocations:[Location] = []
    
    init(passReserve:Reserve, passConflicts:[Conflict]) {
        defenseReserve = passReserve
        conflicts = passConflicts
        
        for eachConflict in conflicts {
            threatenedApproaches += [eachConflict.defenseApproach]
            
            // These are occupied approaches being threatened (all defenders on the approach are added automatically to the defense group)
            if eachConflict.defenseApproach.occupantCount > 0 {
                defendedApproaches += [eachConflict.defenseApproach]
                eachConflict.defenseGroup = GroupsFromCommands(eachConflict.defenseApproach.occupants, includeLeader: false)
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
        
        // If there is an undefended threat with no available defenders
        if unresolvedApproaches.count > 0 && !defenseReserve.defendersAvailable {mustRetreat = true; retreatMode = true}
    }
    
}

class Group {
    
    let command:Command!
    let units:[Unit]!
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
            if eachUnit.unitType == .Ldr {leaderInGroup = true; cavCount++} else if eachUnit.unitType == .Cav {cavCount++; nonLdrUnitCount++} else {nonLdrUnitCount++}
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
    var groupSelectionSize:Int = 0
    
    var sameTypeSameCorps:Bool = false
    var sameType:Bool = false
    var anyOneStrengthUnits = false
        
    init(theGroups:[Group]) {
        
        var unitsTypes:[Type] = []
        var numberCorps:Int = 0
        var numberDetached:Int = 0
        
        for eachGroup in theGroups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                
                if eachUnit.selected == .Selected {
                    theUnits += [eachUnit] // Add to units
                    if eachUnit.unitType != .Ldr {groupSelectionSize++} // Increment group selection size
                    unitsTypes += [eachUnit.unitType] // Increment the unit type array
                    if eachUnit.unitStrength == 1 {anyOneStrengthUnits = true}

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
    
}
