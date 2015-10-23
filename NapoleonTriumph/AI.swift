//
//  AI.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-10-22.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

func SelectLeadingUnits(theConflict:Conflict) {
    
    var selectionsAvailable = true
    
    repeat {
        
        let unitsRemaining = SelectableLeadingGroups(theConflict, thePhase: manager!.phaseOld)
    
        if unitsRemaining.isEmpty {selectionsAvailable = false}
    
        else {
            
            let unitPriority = manager!.priorityLeaderAndBattle[manager!.actingPlayer]!
            
            switch (theConflict.wideBattle, theConflict.approachConflict, manager!.phaseOld) {
    
            case (true, false, .RealAttack): // Defenders in reserve, wide (same type, same corps, guard = inf)
            
                var theFinalInf:[Command:[Unit]] = [:]
                var theFinalCav:[Command:[Unit]] = [:]
                
                for eachUnit in unitsRemaining {
                    
                    if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) || eachUnit.unitType == .Grd {
    
                        if theFinalInf[eachUnit.parentCommand!] == nil {
                            theFinalInf[eachUnit.parentCommand!] = [eachUnit]
                        } else {
                            theFinalInf[eachUnit.parentCommand!] = theFinalInf[eachUnit.parentCommand!]! + [eachUnit]
                        }
                    
                    } else if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 {
                        
                        if theFinalCav[eachUnit.parentCommand!] == nil {
                            theFinalCav[eachUnit.parentCommand!] = [eachUnit]
                        } else {
                            theFinalCav[eachUnit.parentCommand!] = theFinalCav[eachUnit.parentCommand!]! + [eachUnit]
                        }
                    }
                    
                }
    
                var theLargestPair = 0
                var overideUnitPriority:[Unit] = []
                for (_, eachUnitArray) in theFinalInf {
                    if eachUnitArray.count > 1 {
                        let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}.sort{$0.unitType == .Inf && $1.unitType == .Grd}
                        let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                        if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                    }
                }
                for (_, eachUnitArray) in theFinalCav {
                    if eachUnitArray.count > 1 {
                        let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                        let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                        if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                    }
                }
                
                if overideUnitPriority == [] {
                    let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                    unitToSelect?.selected = .Selected
                } else {
                    overideUnitPriority[0].selected = .Selected
                    overideUnitPriority[1].selected = .Selected
                }
    
            case (true, _, .DeclaredAttackers): // Attackers, wide (same type, guard != inf)
                
            var theFinalInf:[Unit] = []
            var theFinalGrd:[Unit] = []
            var theFinalCav:[Unit] = []
            
            for eachUnit in unitsRemaining {
                
                if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) {theFinalInf += [eachUnit]}
                else if eachUnit.unitType == .Grd {theFinalGrd += [eachUnit]}
                else if (eachUnit.unitType == .Cav && eachUnit.unitStrength > 1) {theFinalCav += [eachUnit]}
                else if eachUnit.unitType == .Art && theConflict.defenseApproach.mayArtAttack && !(theConflict.approachConflict && theConflict.defenseApproach.artApproach) && theConflict.attackGroup!.groups[0].command.currentLocation == theConflict.attackApproach {eachUnit.selected = .Selected; break}
            }
            
            var theLargestPair = 0
            var overideUnitPriority:[Unit] = []

            if theFinalInf.count > 1 {
                let theComparisonArray = theFinalInf.sort{$0.unitStrength > $1.unitStrength}
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            if theFinalGrd.count > 1 {
                let theComparisonArray = theFinalGrd
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            if theFinalCav.count > 1 {
                let theComparisonArray = theFinalCav.sort{$0.unitStrength > $1.unitStrength}
                let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
            }
            
            if overideUnitPriority == [] {
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                unitToSelect?.selected = .Selected
            } else {
                overideUnitPriority[0].selected = .Selected
                overideUnitPriority[1].selected = .Selected
            }
            
            case (_, _, .DeclaredLeadingA): // Counter-attackers, all situations (same type, same corps, guard != inf)
                
            var theFinalInf:[Command:[Unit]] = [:]
            var theFinalGrd:[Command:[Unit]] = [:]
            var theFinalCav:[Command:[Unit]] = [:]
            
            for eachUnit in unitsRemaining {
                
                if (eachUnit.unitType == .Inf && eachUnit.unitStrength > 1) {
                    
                    if theFinalInf[eachUnit.parentCommand!] == nil {
                        theFinalInf[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalInf[eachUnit.parentCommand!] = theFinalInf[eachUnit.parentCommand!]! + [eachUnit]
                    }
                    
                } else if eachUnit.unitType == .Grd {
                    
                    if theFinalGrd[eachUnit.parentCommand!] == nil {
                        theFinalGrd[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalGrd[eachUnit.parentCommand!] = theFinalGrd[eachUnit.parentCommand!]! + [eachUnit]
                    }
                    
                } else if eachUnit.unitType == .Cav && eachUnit.unitStrength > 1 {
                    
                    if theFinalCav[eachUnit.parentCommand!] == nil {
                        theFinalCav[eachUnit.parentCommand!] = [eachUnit]
                    } else {
                        theFinalCav[eachUnit.parentCommand!] = theFinalCav[eachUnit.parentCommand!]! + [eachUnit]
                    }
                }
                
            }
            
            var theLargestPair = 0
            var overideUnitPriority:[Unit] = []
            for (_, eachUnitArray) in theFinalInf {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            for (_, eachUnitArray) in theFinalGrd {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            for (_, eachUnitArray) in theFinalCav {
                if eachUnitArray.count > 1 {
                    let theComparisonArray = eachUnitArray.sort{$0.unitStrength > $1.unitStrength}
                    let thePair = theComparisonArray[0].unitStrength + theComparisonArray[1].unitStrength
                    if thePair > theLargestPair {theLargestPair = thePair; overideUnitPriority = [theComparisonArray[0]] + [theComparisonArray[1]]}
                }
            }
            
            if overideUnitPriority == [] {
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                unitToSelect?.selected = .Selected
            } else {
                overideUnitPriority[0].selected = .Selected
                overideUnitPriority[1].selected = .Selected
            }
                
            case (false, false, .RealAttack), (_, true, .RealAttack), (false, _, .DeclaredAttackers): // Defenders in reserve, narrow (simple priority), Defenders in approach, any (simple priority), Attackers, narrow (simple priority)
                
                // Selects artillery if its in the group
                if manager!.phaseOld == .DeclaredAttackers && theConflict.defenseApproach.mayArtAttack && !(theConflict.approachConflict && theConflict.defenseApproach.artApproach) && theConflict.attackGroup!.groups[0].command.currentLocation == theConflict.attackApproach {
                    for eachUnit in unitsRemaining {
                        if eachUnit.unitType == .Art {eachUnit.selected = .Selected; break}
                    }
                }
                
                let unitToSelect = PriorityLoss(unitsRemaining, unitLossPriority: unitPriority)
                unitToSelect?.selected = .Selected
             
            default: break
                
            }
    
        }
    
    } while selectionsAvailable
    
}