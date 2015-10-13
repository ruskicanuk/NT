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
    var attackGroup:GroupSelection?
    var guardAttackGroup:GroupSelection?
    var counterAttackGroup:GroupSelection?
    
    var attackMoveType:MoveType?
    let defenseSide:Allegience!
    
    var defenseLeadingUnits:GroupSelection?
    var attackLeadingUnits:GroupSelection?
    var counterAttackLeadingUnits:GroupSelection?
    
    var mayCounterAttack:Bool = true
    var conflictInitialWinner:Allegience
    var conflictFinalWinner:Allegience
    var initialResult = 0
    var finalResult = 0
    
    var availableCounterAttackers:GroupSelection? {
        // Safety check
        if defenseGroup == nil {return nil}
        if defenseLeadingUnits == nil {return defenseGroup}
        
        var theGroups:[Group] = []
        
        for eachGroup in defenseGroup!.groups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {

                var unitFound = false
                for eachLeadingGroup in defenseLeadingUnits!.groups {
                    if eachLeadingGroup.units.contains(eachUnit) {unitFound = true; break}
                }
                
                if !unitFound && eachUnit.unitStrength > 1 {theUnits += [eachUnit]}

            }
            if !theUnits.isEmpty {
                theGroups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]
            }
        }
        return GroupSelection(theGroups: theGroups, selectedOnly: false)
    }
    
    var potentialRdAttackers:[Command:[Reserve]] = [:] // Stores the reserve pathways possible
    var rdAttackerPath:[Reserve] = []
    var rdAttackerMultiPaths:[[Reserve]] = []
    
    var guardAttack:Bool = false
    
    func SetGuardAttackGroup() {
        var theGroups:[Group] = []
        for eachGroup in attackGroup!.groups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                if eachUnit.unitType == .Grd {theUnits += [eachUnit]}
            }
            if !theUnits.isEmpty {theGroups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]}
        }
        guardAttackGroup = GroupSelection(theGroups: theGroups, selectedOnly: false)
    }
    
    var mustFeint:Bool = false
    
    var approachConflict:Bool = false
    var wideBattle:Bool = false
    //var battleOccured:Bool = false
    
    weak var parentGroupConflict:GroupConflict?
    
    init(aReserve:Reserve, dReserve:Reserve, aApproach:Approach, dApproach:Approach, mFeint:Bool = false) {
        defenseReserve = dReserve
        attackReserve = aReserve
        defenseApproach = dApproach
        attackApproach = aApproach
        mustFeint = mFeint
        defenseSide = manager!.phasingPlayer.Other()
        conflictInitialWinner = .Neutral
        conflictFinalWinner = .Neutral
        if defenseApproach.wideApproach {wideBattle = true}
        
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
    
    func InitialResult() {
        
        let attackLead = attackLeadingUnits!
        let defenseLead = defenseLeadingUnits!
        var cavLead:Bool = false; var infLead:Bool = false; var artLead:Bool = false; //var grdLead:Bool = false
        
        for eachGroup in attackGroup!.groups + defenseGroup!.groups {
            for eachUnit in eachGroup.units {eachUnit.wasInBattle = true}
        }
        
        if !attackLead.groups.isEmpty {
            if attackLead.groups[0].allCav {cavLead = true}
            else if attackLead.groups[0].artOnly {artLead = true}
            else if attackLead.containsInfOrGuard  {infLead = true}
        }
        var attackStrength:Int = 0
        var defenseStrength:Int = 0
        
        attackStrength += attackLead.groupSelectionStrength
        
        if approachConflict {
            if infLead {attackStrength--}
            if infLead {if defenseApproach.infApproach {attackStrength--}}
            else if cavLead {if defenseApproach.cavApproach {attackStrength--}}
            else if artLead {if defenseApproach.artApproach {attackStrength--}}
        }
        
        if !artLead {defenseStrength = defenseLead.groupSelectionStrength} else {defenseStrength = 0}
        if guardAttack {defenseStrength -= defenseLead.blocksSelected}
        
        initialResult = attackStrength - defenseStrength
        
        if artLead {conflictInitialWinner = .Neutral}
        else if initialResult > 0 {conflictInitialWinner = defenseSide.Other()!}
        else if initialResult < 0 {conflictInitialWinner = defenseSide}
        else if approachConflict {conflictInitialWinner = defenseSide}
        else if defenseGroup!.blocksSelected > attackGroup!.blocksSelected {conflictInitialWinner = defenseSide}
        else if defenseGroup!.blocksSelected < attackGroup!.blocksSelected {conflictInitialWinner = defenseSide.Other()!}
        else {conflictInitialWinner = .French}
        
        // Store whether counter-attack is possible and the turn of any artillery shooting
        if artLead {mayCounterAttack = false; attackApproach.turnOfLastArtVolley = manager!.turn}
        if counterAttackGroup!.groups.isEmpty {mayCounterAttack = false}
        else if conflictFinalWinner == defenseSide && !counterAttackGroup!.containsTwoOrThreeStrCav {mayCounterAttack = false}
    }
    
    func ApplyCounterLosses() {
        
        let counterLead = counterAttackLeadingUnits!
        
        for eachGroup in counterLead.groups {
            for eachUnit in eachGroup.units {
                let newOrder = Order(theUnit: eachUnit, passedGroupConflict: self.parentGroupConflict!, orderFromView: .Reduce, battleReduce: true)
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
            }
        }
    }
    
    func FinalResult() {
        
        var attackerLossTarget = 0
        var defenderLossTarget = 0
        
        let counterLead = counterAttackLeadingUnits!
        finalResult = initialResult - counterLead.groupSelectionStrength

        print("Initial Result: \(initialResult)")
        print("Final Result: \(finalResult)")
        
        if conflictInitialWinner == .Neutral {conflictFinalWinner = .Neutral}
        else if finalResult > 0 {conflictFinalWinner = defenseSide.Other()!}
        else if finalResult < 0 {conflictFinalWinner = defenseSide}
        else if approachConflict {conflictFinalWinner = defenseSide}
        else if defenseGroup!.blocksSelected > attackGroup!.blocksSelected {conflictFinalWinner = defenseSide}
        else if defenseGroup!.blocksSelected < attackGroup!.blocksSelected {conflictFinalWinner = defenseSide.Other()!}
        else {conflictFinalWinner = .French}
        
        attackerLossTarget = DetermineLossTargets(true)
        defenderLossTarget = DetermineLossTargets(false)
        ApplyBattleLosses(true, overallLossTarget: attackerLossTarget)
        ApplyBattleLosses(false, overallLossTarget: defenderLossTarget)
    }
    
    func DetermineLossTargets(attacker:Bool) -> Int {
        
        var lossTarget = 0
        
        if attacker {
            
            if conflictFinalWinner == .Neutral {return 0} // Artillery shot
            lossTarget = defenseLeadingUnits!.blocksSelected
            if finalResult < 0 {lossTarget += ((-1)*finalResult)}
            
        } else {
            
            if conflictFinalWinner != .Neutral {
                lossTarget += attackLeadingUnits!.blocksSelected
            }
            if finalResult > 0 {lossTarget += finalResult}
            if conflictFinalWinner != .Neutral {
                lossTarget -= defenseLeadingUnits!.artilleryInGroup
            }
        }
        
        return lossTarget
    }
    
    func ApplyBattleLosses(attacker:Bool, overallLossTarget:Int) {
        
        var lossTarget = overallLossTarget
        
        while lossTarget > 0 {
            
            var lossCategory = 1
            var threatenedUnits:[Unit] = []
            var reductionUnits:[Unit] = []
            
            if attacker {
            
                // 1st, leading units
                for eachGroup in attackLeadingUnits!.groups {
                    for eachUnit in eachGroup.units {
                        if eachUnit.unitStrength > 0 {threatenedUnits += [eachUnit]}
                    }
                }
                
                // 2nd, attacking group
                if threatenedUnits.isEmpty {
                    lossCategory = 2
                    for eachGroup in attackGroup!.groups {
                        for eachUnit in eachGroup.units {
                            if eachUnit.unitStrength > 0 {threatenedUnits += [eachUnit]}
                        }
                    }
                }
                
            } else {
                
                // 1st, leading units
                for eachGroup in defenseLeadingUnits!.groups {
                    for eachUnit in eachGroup.units {
                        if eachUnit.unitStrength > 0 && eachUnit.unitType != .Art {threatenedUnits += [eachUnit]}
                    }
                }
                
                // 2nd, counter-attacking units
                if threatenedUnits.isEmpty {
                    var threatenedUnits:[Unit] = []
                    for eachGroup in counterAttackLeadingUnits!.groups {
                        for eachUnit in eachGroup.units {
                            if eachUnit.unitStrength > 0 {threatenedUnits += [eachUnit]}
                        }
                    }
                }
                
                // 3rd, attacking group
                if threatenedUnits.isEmpty {
                    lossCategory = 2
                    for eachGroup in defenseGroup!.groups {
                        for eachUnit in eachGroup.units {
                            if eachUnit.unitStrength > 0 {threatenedUnits += [eachUnit]}
                        }
                    }
                }
                
            }
            
            // Exit if still empty
            if threatenedUnits.isEmpty {return}
        
            if lossTarget < threatenedUnits.count { // Evenly distribute losses
                
                var unitLossPriority:[Int]!
                
                if attacker {
                    if lossCategory == 1 {unitLossPriority = manager!.priorityLosses[defenseSide!]}
                    else {unitLossPriority = manager!.priorityLosses[defenseSide!.Other()!]!.reverse()}
                }

                else {
                    if lossCategory == 1 {unitLossPriority = manager!.priorityLosses[defenseSide!.Other()!]}
                    else {unitLossPriority = manager!.priorityLosses[defenseSide!]!.reverse()}
                }
                
                var thePrioritizedCasualties:[Unit] = []
                while thePrioritizedCasualties.count < lossTarget {
                    
                    /*
                    var theLowestIndex = 7
                    var indexOfTheLowestIndex = 0
                    for (i, eachUnit) in threatenedUnits.enumerate() {
                        let theCode = eachUnit.backCodeFromStrengthAndType()
                        guard let theIndex = unitLossPriority.indexOf(theCode) else {continue}
                        if theIndex < theLowestIndex {theLowestIndex = theIndex; indexOfTheLowestIndex = i}
                    }
                    */
                    thePrioritizedCasualties += [PriorityLoss(threatenedUnits, unitLossPriority: unitLossPriority)!]
                }
                reductionUnits += thePrioritizedCasualties
                lossTarget -= thePrioritizedCasualties.count
                
            } else {
                reductionUnits += threatenedUnits
                lossTarget -= threatenedUnits.count
            }
            
            BattleReductions(reductionUnits)
        }
    }
    
    func BattleReductions(unitsToReduce:[Unit]) {
        for eachUnit in unitsToReduce {
        let newOrder = Order(theUnit: eachUnit, passedGroupConflict: self.parentGroupConflict!, orderFromView: .Reduce, battleReduce: true)
        newOrder.ExecuteOrder()
        manager!.orders += [newOrder]
        
            // Destroy leader case
            if eachUnit.parentCommand!.activeUnits.count == 1 && eachUnit.parentCommand!.hasLeader {
                let newOrder = Order(theUnit: eachUnit.parentCommand!.theLeader!, passedGroupConflict: self.parentGroupConflict!, orderFromView: .Reduce, battleReduce: true)
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
            }
        
        }
    }
}
class GroupConflict {
    
    var mustRetreat:Bool = false
    var mustDefend:Bool = false
    var retreatMode:Bool = false /*{
        
        didSet {
            if retreatMode {
                for eachConflict in conflicts {eachConflict.defenseApproach.hidden = true}
            } else {
                for eachConflict in conflicts {eachConflict.defenseApproach.hidden = false}
            }
        }

    } */
    // Used to store number of orders for the purposes of releasing the mustRetreat / mustDefend condition when un-doing
    var retreatOrders:Int = 0
    var defenseOrders:Int = 0
    
    var twoPlusCorps:Bool = false
    
    // Returns if any reductions have been made
    var madeReductions:Bool {
        var actualReductions:Int = 0
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
                eachConflict.defenseGroup!.SetGroupSelectionPropertyUnitsHaveDefended(true)
                eachConflict.approachConflict = true
            }
        }
        
        SetupRetreatRequirements()
        
        // If there is an undefended threat with not enough available defenders
        //if unresolvedApproaches.count > defenseReserve.defendersAvailable {mustRetreat = true; retreatMode = true}
    }
    
    func SetupRetreatRequirements() {
        
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
        
        /*
        var maxWidth:Int = 0
        for eachVacantApproach in unresolvedApproaches {
            maxWidth = max(maxWidth, eachVacantApproach.approachLength)
        }
        */
        let maxWidth:Int!
        switch (conflicts[0].defenseApproach.wideApproach) {
        case true: maxWidth = 2
        case false: maxWidth = 1
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
    var allGuard:Bool = true
    var someUnitsHaveMoved:Bool = false
    var guardInGroup:Bool = false
    var cavCount:Int = 0
    var nonLdrUnitCount:Int = 0

    init(theCommand:Command, theUnits:[Unit]) {
        command = theCommand
        units = theUnits
        for eachUnit in theUnits {
            
            if eachUnit.unitType == .Ldr {leaderInGroup = true; leaderUnit = eachUnit}
            else if eachUnit.unitType == .Cav {cavCount++; nonLdrUnitCount++; artOnly = false; allGuard = false}
            else if eachUnit.unitType == .Art {nonLdrUnitCount++; allCav = false; allGuard = false}
            else if eachUnit.unitType == .Grd {nonLdrUnitCount++; artOnly = false; allCav = false}
            else {nonLdrUnitCount++; artOnly = false; allCav = false; allGuard = false}
            if eachUnit.hasMoved {someUnitsHaveMoved = true}
            if eachUnit.unitType == .Grd {guardInGroup = true}
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
    //var groupSelectionSize:Int = 0 // Number of blocks in the group
    
    var sameTypeSameCorps:Bool = false
    var sameType:Bool = false
    var anyOneStrengthUnits = false
    
    var blocksSelected = 0
    
    var containsInfOrGuard = false
    var containsTwoOrThreeStrCav = false
    var containsLeader = false
    var artilleryInGroup = 0
    var groupSelectionStrength:Int {
        var theTotal = 0
        for eachGroup in groups {
            for eachUnit in eachGroup.units {
                if eachUnit.unitType != .Ldr {theTotal += eachUnit.unitStrength}
            }
        }
        return theTotal
    }
    
    init(theGroups:[Group], selectedOnly:Bool = true) {
        
        var unitsTypes:[Type] = []
        var numberCorps:Int = 0
        var numberDetached:Int = 0
        
        for eachGroup in theGroups {
            var theUnits:[Unit] = []
            for eachUnit in eachGroup.units {
                
                if eachUnit.selected == .Selected || !selectedOnly {
                    
                    if eachUnit.unitType == .Inf || eachUnit.unitType == .Grd {containsInfOrGuard = true}
                    if eachUnit.unitType == .Art {artilleryInGroup++}
                    if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 {containsTwoOrThreeStrCav = true}
                    theUnits += [eachUnit] // Add to units
                    blocksSelected++
                    if eachUnit.unitType == .Ldr {containsLeader = true} // Increment group selection size
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
