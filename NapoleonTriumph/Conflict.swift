//
//  Conflict.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-08-28.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//
import Foundation

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
    
    var realAttack:Bool = false
    var phantomCorpsOrder:Bool?
    
    var mayCounterAttack:Bool = true
    var conflictInitialWinner:Allegience
    var conflictFinalWinner:Allegience
    var initialResult = 0
    var finalResult = 0
    var threateningUnits:[Unit] = []
    var storedThreateningUnits:[Unit] = []
    
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
    
    var approachConflict:Bool = false {
        didSet {
            if approachConflict {approachDefended = true}
        }
    }
    var approachDefended:Bool = false
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
        defenseApproach.threatened = true
        if defenseApproach.wideApproach {wideBattle = true}
        
        for eachCommand in manager!.gameCommands[defenseSide.Other()!]! {
            
            let theRdPaths = RdCommandPathToConflict(eachCommand)
            if !theRdPaths.isEmpty {potentialRdAttackers[eachCommand] = theRdPaths}
        }
    }
    
    deinit {
        print("DEINIT Conflict")
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
        
        if !attackLead.groups.isEmpty {
            if attackLead.groups[0].allCav {cavLead = true}
            else if attackLead.groups[0].artOnly {artLead = true}
            else if attackLead.containsInfOrGuard  {infLead = true}
        }
        var attackStrength:Int = 0
        var defenseStrength:Int = 0
        
        // sets all participants to "was in battle" if it isn't an artillery shot
        if artLead {
            defenseApproach.mayArtAttack = false
        } else {
            defenseApproach.mayArtAttack = false
            defenseApproach.mayNormalAttack = false
            for eachGroup in attackGroup!.groups + defenseGroup!.groups {
                for eachUnit in eachGroup.units {eachUnit.wasInBattle = true}
            }
        }
        
        attackStrength += attackLead.groupSelectionStrength
        
        if approachConflict {
            if infLead {attackStrength -= 1}
            if infLead {if defenseApproach.infApproach {attackStrength -= 1}}
            else if cavLead {if defenseApproach.cavApproach {attackStrength -= 1}}
            else if artLead {if defenseApproach.artApproach {attackStrength -= 1}}
        }
        
        if !artLead {defenseStrength = defenseLead.groupSelectionStrength} else {defenseStrength = 0}
        if guardAttack {defenseStrength -= defenseLead.notThreeStrUnits}
        
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
        else if conflictInitialWinner == defenseSide && !counterAttackGroup!.containsTwoOrThreeStrCav {mayCounterAttack = false}
    }
    
    func ApplyCounterLosses() {
        
        let counterLead = counterAttackLeadingUnits!
        
        for eachGroup in counterLead.groups {
            for eachUnit in eachGroup.units {
                let newOrder = Order(passedConflict: self, theUnit: eachUnit, orderFromView: .Reduce, battleReduce: true)
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
        
        if conflictInitialWinner == .Neutral {conflictFinalWinner = .Neutral}
        else if finalResult > 0 {conflictFinalWinner = defenseSide.Other()!}
        else if finalResult < 0 {conflictFinalWinner = defenseSide}
        else if approachConflict {conflictFinalWinner = defenseSide}
        else if defenseGroup!.blocksSelected > attackGroup!.blocksSelected {conflictFinalWinner = defenseSide}
        else if defenseGroup!.blocksSelected < attackGroup!.blocksSelected {conflictFinalWinner = defenseSide.Other()!}
        else {conflictFinalWinner = .French}
        
        attackerLossTarget = DetermineLossTargets(true)
        defenderLossTarget = DetermineLossTargets(false)
        
        // Check for guard first-time commitments
        if attackLeadingUnits!.containsGuard && !manager!.guardCommitted[defenseSide.Other()!]! {manager!.ReduceMorale(manager!.guardCommittedCost, side: defenseSide.Other()!, mayDemoralize: false); manager!.guardCommitted[defenseSide.Other()!]! = true}
        if defenseLeadingUnits!.containsGuard && !manager!.guardCommitted[defenseSide]! {manager!.ReduceMorale(manager!.guardCommittedCost, side: defenseSide, mayDemoralize: false); manager!.guardCommitted[defenseSide]! = true}
        if counterAttackLeadingUnits!.containsGuard && !manager!.guardCommitted[defenseSide]! {manager!.ReduceMorale(manager!.guardCommittedCost, side: defenseSide, mayDemoralize: false); manager!.guardCommitted[defenseSide]! = true}
        
        // Check for heavy cav first-time commitments
        if attackLeadingUnits!.containsHeavyCav && !manager!.heavyCavCommited[defenseSide.Other()!]! {manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: defenseSide.Other()!, mayDemoralize: false); manager!.heavyCavCommited[defenseSide.Other()!]! = true}
        if defenseLeadingUnits!.containsHeavyCav && !manager!.heavyCavCommited[defenseSide]! {manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: defenseSide, mayDemoralize: false); manager!.heavyCavCommited[defenseSide]! = true}
        if counterAttackLeadingUnits!.containsHeavyCav && !manager!.heavyCavCommited[defenseSide]! {manager!.ReduceMorale(manager!.heavyCavCommittedCost, side: defenseSide, mayDemoralize: false); manager!.heavyCavCommited[defenseSide]! = true}
        
        let actualAttackerLosses = ApplyBattleLosses(true, overallLossTarget: attackerLossTarget)
        let actualDefenderLosses = ApplyBattleLosses(false, overallLossTarget: defenderLossTarget) + counterAttackLeadingUnits!.blocksSelected
        
        // Check for leader deaths (can only die in battle, retreat reductions and surrender)
        for eachGroup in attackGroup!.groups {
            
            for eachUnit in eachGroup.units {eachUnit.hasMoved = true}
            
            if !eachGroup.leaderInGroup {continue}
            
            var totalUnitStrength = 0
            for eachUnit in eachGroup.units {
                totalUnitStrength += eachUnit.unitStrength
            }
            
            // Destroy the leader
            if totalUnitStrength == 1 { // Leader only
                eachGroup.leaderUnit!.decrementStrength(true)
                if eachGroup.leaderUnit!.unitSide == .French {manager!.player2CorpsCommands -= 1}
            }
        }
        for eachGroup in defenseGroup!.groups {
            if !eachGroup.command.hasLeader {continue}
            let totalUnitStrength = eachGroup.command.unitsTotalStrength
            
            // Destroy the leader
            if totalUnitStrength == 0 { // Leader only
                eachGroup.command.theLeader!.decrementStrength(true)
                if eachGroup.command.theLeader!.unitSide == .French {manager!.player2CorpsCommands -= 1}
            }
        }
        
        // Morale reductions
        if conflictFinalWinner == defenseSide {
            manager!.ReduceMorale(actualAttackerLosses, side: defenseSide.Other()!, mayDemoralize: true)
        } else if conflictFinalWinner == defenseSide.Other() {
            manager!.ReduceMorale(actualDefenderLosses, side: defenseSide, mayDemoralize: true)
        } else {
            manager!.ReduceMorale(actualDefenderLosses, side: defenseSide, mayDemoralize: false)
        }
    }
    
    func DetermineLossTargets(attacker:Bool) -> Int {
        
        var lossTarget = 0
        
        if attacker {
            
            if conflictFinalWinner == .Neutral {return 0} // Artillery shot
            lossTarget = defenseLeadingUnits!.blocksSelected
            if finalResult < 0 {lossTarget += ((-1)*finalResult)}
            
        } else {
            
            if conflictFinalWinner != .Neutral {lossTarget += attackLeadingUnits!.blocksSelected}
            if finalResult > 0 {lossTarget += finalResult}
            if conflictFinalWinner != .Neutral {lossTarget -= defenseLeadingUnits!.artilleryInGroup}
        }
        
        return lossTarget
    }
    
    // Returns actual losses
    func ApplyBattleLosses(attacker:Bool, overallLossTarget:Int) -> Int {
        
        var lossTarget = overallLossTarget
        var actualLosses = 0
        
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
                            if eachUnit.unitStrength > 0 && eachUnit.unitType != .Ldr {threatenedUnits += [eachUnit]}
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
            if threatenedUnits.isEmpty {return actualLosses}
        
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
                    
                    thePrioritizedCasualties += [PriorityLoss(threatenedUnits, unitLossPriority: unitLossPriority)!]
                }
                reductionUnits += thePrioritizedCasualties
                lossTarget -= thePrioritizedCasualties.count
                
            } else {
                reductionUnits += threatenedUnits
                lossTarget -= threatenedUnits.count
            }
            actualLosses += reductionUnits.count
            BattleReductions(reductionUnits)
        }
        
        return actualLosses
    }
    
    func BattleReductions(unitsToReduce:[Unit]) {
        
        for eachUnit in unitsToReduce {
            
            let newOrder = Order(passedConflict: self, theUnit: eachUnit, orderFromView: .Reduce, battleReduce: true)
            newOrder.ExecuteOrder()
            manager!.orders += [newOrder]
            
            // Destroy leader case
            if eachUnit.parentCommand!.activeUnits.count == 1 && eachUnit.parentCommand!.hasLeader {
                let newOrder = Order(passedConflict: self, theUnit: eachUnit.parentCommand!.theLeader!, orderFromView: .Reduce, battleReduce: true)
                newOrder.ExecuteOrder()
                manager!.orders += [newOrder]
            }
        
        }
    }
    
    func ResetUnitsAndLocationsInConflict() {
        
        // Unit upkeep and reserve updates (May not be necessary)
        for eachOccupant in defenseReserve.occupants + defenseApproach.occupants + attackReserve.occupants + attackApproach.occupants {
            eachOccupant.unitsUpkeep()
        }
        defenseReserve.UpdateReserveState()
        attackReserve.UpdateReserveState()
    }
}

class GroupConflict {
    
    var mustRetreat:Bool = false
    var mustDefend:Bool = false
    var retreatMode:Bool = false
    var someEmbattledAttackersWon:Bool = false
    
    // Used to store number of orders for the purposes of releasing the mustRetreat / mustDefend condition when un-doing
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
    var conflicts:[Conflict] = []
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
    var moraleLossFromRetreat = 0
    
    init(passReserve:Reserve, passConflicts:[Conflict]) {

        defenseReserve = passReserve
        conflicts = passConflicts
        if defenseReserve.has2PlusCorps == .Neutral {twoPlusCorps = false} else {twoPlusCorps = true} // Saves whether the reserve has a two-plus Corps

        // Links the threatened approaches and conflicts to their parent-conflict
        for eachConflict in conflicts {
            threatenedApproaches += [eachConflict.defenseApproach]
            eachConflict.parentGroupConflict = self
            
            // Case that the defense approach is occupied (must defend)
            if eachConflict.defenseApproach.occupantCount > 0 {
                defendedApproaches += [eachConflict.defenseApproach]
                eachConflict.defenseGroup = GroupSelection(theGroups: GroupsFromCommands(eachConflict.defenseApproach.occupants, includeLeader: false), selectedOnly: false)
                eachConflict.defenseGroup!.SetGroupSelectionPropertyUnitsHaveDefended(true, approachDefended: eachConflict.defenseApproach)
                eachConflict.approachConflict = true
            }
        }

        SetupRetreatRequirements()
    }
    
    func SetupRetreatRequirements() {
        
        moraleLossFromRetreat = 0
        
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
            moraleLossFromRetreat += damageRequired[eachApproach]! + destroyRequired[eachApproach]!
            
            damageDelivered[eachApproach] = 0
            destroyDelivered[eachApproach] = 0
        }
        
        // Set the max-width from the unoccupied approaches
        var maxWidth:Int = 1
        for eachApproach in unresolvedApproaches {
            if eachApproach.wideApproach {
                maxWidth = 2
                break
            }
        }
        
        var potentialLosses:Int = 0
        var potentialDestroyed:Int = 0
        for eachCommand in defenseReserve.occupants {
            for eachUnit in eachCommand.infUnits {
                if !eachUnit.wasInBattle {potentialLosses += eachUnit.unitStrength}
            }
            potentialDestroyed += eachCommand.artUnits.count
        }
        
        damageRequired[defenseReserve] = min(potentialLosses, maxWidth)
        destroyRequired[defenseReserve] = potentialDestroyed
        moraleLossFromRetreat += damageRequired[defenseReserve]! + destroyRequired[defenseReserve]!

        damageDelivered[defenseReserve] = 0
        destroyDelivered[defenseReserve] = 0
    }
    
}

class Group: NSObject, NSCoding {
    
    let command:Command!
    let units:[Unit]!
    var nonLdrUnits:[Unit] {
        var theUnits:[Unit] = []
        for each in units {if each.unitType != .Ldr {theUnits += [each]}}
        return theUnits
    }
    var unitsStrength:Int {
        var strength = 0
        for each in units {if each.unitType != .Ldr {strength += each.unitStrength}}
        return strength
    }
    var artOnly:Bool = true
    var artExists:Bool = true
    var leaderUnit:Unit?
    var fullCommand:Bool = false
    var leaderInGroup:Bool = false
    var allCav:Bool = true
    var allGuard:Bool = true
    var someUnitsHaveMoved:Bool = false
    var someUnitsFixed:Bool = false
    var guardInGroup:Bool = false
    var cavCount:Int = 0
    var nonLdrUnitCount:Int = 0
    var groupIsTwoPlusCorps:Bool = false
    //var cavUnits:[Unit] = []
    
    func encodeWithCoder(aCoder: NSCoder) {
        
        aCoder.encodeObject(command, forKey: "command")
        aCoder.encodeObject(units, forKey: "units")
        aCoder.encodeBool(artOnly, forKey: "artOnly")
        aCoder.encodeBool(artExists, forKey: "artExists")
        aCoder.encodeBool(fullCommand, forKey: "fullCommand")
        aCoder.encodeBool(leaderInGroup, forKey: "leaderInGroup")
        aCoder.encodeBool(allCav, forKey: "allCav")
        aCoder.encodeBool(allGuard, forKey: "allGuard")
        aCoder.encodeBool(guardInGroup, forKey: "guardInGroup")
        aCoder.encodeObject(leaderUnit, forKey: "leaderUnit")
        aCoder.encodeInteger(cavCount, forKey: "cavCount")
        aCoder.encodeInteger(nonLdrUnitCount, forKey: "nonLdrUnitCount")
        
    }
    
    required init(coder aDecoder: NSCoder) {

        command = aDecoder.decodeObjectForKey("command") as! Command
        units = aDecoder.decodeObjectForKey("units") as! [Unit]!
        //cavUnits = aDecoder.decodeObjectForKey("units") as! [Unit]! // JA added
        artOnly = aDecoder.decodeBoolForKey("artOnly")
        artExists = aDecoder.decodeBoolForKey("artExists")
        leaderUnit = aDecoder.decodeObjectForKey("leaderUnit") as? Unit
        fullCommand = aDecoder.decodeBoolForKey("fullCommand")
        leaderInGroup = aDecoder.decodeBoolForKey("leaderInGroup")
        allCav = aDecoder.decodeBoolForKey("allCav")
        allGuard = aDecoder.decodeBoolForKey("allGuard")
        someUnitsHaveMoved = aDecoder.decodeBoolForKey("someUnitsHaveMoved")
        guardInGroup = aDecoder.decodeBoolForKey("guardInGroup")
        cavCount = aDecoder.decodeIntegerForKey("cavCount")
        nonLdrUnitCount = aDecoder.decodeIntegerForKey("nonLdrUnitCount")
    }

    init(theCommand:Command, theUnits:[Unit]) {
        command = theCommand
        units = theUnits
        
        for eachUnit in theUnits {
            
            if eachUnit.unitType == .Ldr {
                leaderInGroup = true
                leaderUnit = eachUnit
            }
            else if eachUnit.unitType == .Cav {cavCount += 1; nonLdrUnitCount += 1; artOnly = false; allGuard = false}
            else if eachUnit.unitType == .Art {nonLdrUnitCount += 1; allCav = false; allGuard = false; artExists = true}
            else if eachUnit.unitType == .Grd {nonLdrUnitCount += 1; artOnly = false; allCav = false}
            else {nonLdrUnitCount += 1; artOnly = false; allCav = false; allGuard = false}
            
            if eachUnit.hasMoved {someUnitsHaveMoved = true}
            if eachUnit.fixed {someUnitsFixed = true}
            if eachUnit.unitType == .Grd {guardInGroup = true}
        }
        
        super.init()
        
        if nonLdrUnitCount == command.unitCount {fullCommand = true}
        if nonLdrUnitCount >= 2 {groupIsTwoPlusCorps = true}
    }
    
    func SetGroupProperty(category:String, onOff:Bool) {
        for eachUnit in self.units {
            
            switch category {
                
            case "hasMoved":
                
                if onOff {eachUnit.hasMoved = true}
                else {eachUnit.hasMoved = false}
                
            case "assignedCorps":
                
                if onOff {
                    eachUnit.assigned = "Corps"
                }
                else {
                    eachUnit.assigned = "None"
                }
                
            case "assignedInd":
                
                if onOff {eachUnit.assigned = "Ind"}
                else {eachUnit.assigned = "None"}
                
            default: break
            }
        }
    }
}

class GroupSelection {
    
    var groups:[Group] = []
    
    var sameTypeSameCorps:Bool = false
    var sameType:Bool = false
    var anyOneStrengthUnits = false
    
    var blocksSelected = 0
    var nonLeaderBlocksSelected = 0
    var notThreeStrUnits = 0
    
    var containsInfOrGuard = false
    var containsTwoOrThreeStrCav = false
    var containsLeader = false
    var containsGuard = false
    var containsHeavyCav = false
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
                    if eachUnit.unitType == .Art {artilleryInGroup += 1}
                    if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 {containsTwoOrThreeStrCav = true}
                    if containsTwoOrThreeStrCav && eachUnit.unitStrength == 3 {containsHeavyCav = true}
                    if eachUnit.unitType == .Grd {containsGuard = true}
                    theUnits += [eachUnit] // Add to units
                    blocksSelected += 1
                    if eachUnit.unitType == .Ldr {containsLeader = true} else {nonLeaderBlocksSelected += 1}
                    unitsTypes += [eachUnit.unitType] // Increment the unit type array
                    if eachUnit.unitStrength == 1 && eachUnit.unitType != .Ldr {anyOneStrengthUnits = true}
                    if eachUnit.unitStrength < 3 {notThreeStrUnits += 1}
                    
                }  
            }
            
            if theUnits.count > 0 {
                groups += [Group(theCommand: eachGroup.command, theUnits: theUnits)]
                if eachGroup.command.hasLeader {numberCorps += 1} else {numberDetached += 1}
            }
        }
        
        unitsTypes = Array(Set(unitsTypes))
        if unitsTypes.count == 1 && numberCorps == 1 && numberDetached == 0 {sameTypeSameCorps = true}
        if unitsTypes.count == 1 && numberCorps <= 2 && numberDetached == 0 {sameType = true}
    }
    
    func SetGroupSelectionPropertyUnitsHaveDefended(onOff:Bool, approachDefended: Approach) {
        for eachGroup in self.groups {
            for eachUnit in eachGroup.units {
                if onOff {eachUnit.approachDefended = approachDefended}
                else {eachUnit.approachDefended = nil}
            }
        }
    }
    
    func SetGroupSelectionProperty(category:String, onOff:Bool) {
        for eachGroup in self.groups {
            for eachUnit in eachGroup.units {
                
                switch category {
                
                case "hasMoved":
                    if onOff {eachUnit.hasMoved = true}
                    else {eachUnit.hasMoved = false}
                
                default: break
                }
            }
        }
    }
}
