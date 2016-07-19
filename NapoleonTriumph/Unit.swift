//
//  Unit.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-19.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import SpriteKit

//Unit naming convention: 3-digit code: 1st: 1/2 Austrian/French, 2nd: 1/2/3/4/5 Art/Cav/Inf/Guard/Leader, 3rd: 0/1/2/3 Strength
enum Type {case Inf, Cav, Art, Grd, Ldr}

enum SelectType {case Normal, Selected, Off, NotSelectable}

class Unit: SKSpriteNode {
    
    var selected:SelectType = .Normal {
        didSet {
            updateSelectedStatus()
            updateUnitTexture()
        }
    }
    
    var unitCode:Double = 133.0
    var unitStrength:Int = 3
    var unitSide:Allegience = .Austrian
    var unitType:Type = .Inf
    var fixed:Bool = false
    var hasMoved:Bool = false {
        didSet {
            updateSelectedStatus()
        }
    }
    var startedAsGrd:Bool = false
    
    var approachDefended:Approach?
    var wasInBattle:Bool = false
    var parentCommand:Command?
    var threatenedConflict:Conflict?
    
    var assigned:String = "None" // "Corps" "Ind"
    
    // MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init (unitCodePassedFromCommand: Double, pCommand:Command) {
        
        unitCode = unitCodePassedFromCommand
        let baseTexture = SKTexture(imageNamed: imageNamesNormal[unitCode]!)
        let baseColor:UIColor = UIColor()
        let baseSize:CGSize = CGSize(width: unitWidth*mapScaleFactor, height: unitHeight*mapScaleFactor) //Will want to make node dimensions load from xml
        
        super.init(texture: baseTexture, color: baseColor, size: baseSize)
        
        parentCommand = pCommand
        setPropertiesWithUnitCode()
        
    }
    
    deinit {
        print("Unit Deinitialized", terminator: "")
    }
    
    // MARK: Update Unit Properties
    
    func updateSelectedStatus() {
        
        // For french-reinforcements which have yet to arrive
        let hasArrived = manager!.turn >= parentCommand!.turnMayEnterMap
        
        if manager!.phaseNew == .PreRetreatOrFeintMoveOrAttackDeclare {
            if !hasArrived && selected == .Normal {
                selected = .NotSelectable
            }
        }
        
        if manager!.phaseNew == .Setup || manager!.phaseNew == .Move || manager!.phaseNew == .Commit {
            
            if selected == .Off {return}
            
            // For post-attack repeat moves
            let repeatMovePossible = parentCommand!.moveNumber == parentCommand!.repeatMoveNumber && parentCommand!.moveNumber > 0
            
            // For french-reinforcements which may have a second attack
            let frReinforcement  = parentCommand!.turnEnteredMap == manager!.turn && !parentCommand!.secondMoveUsed

            if ((hasMoved && !repeatMovePossible) || threatenedConflict != nil || !hasArrived) && !frReinforcement && selected == .Normal {
                selected = .NotSelectable
            }
            else if (!((hasMoved && !repeatMovePossible) || threatenedConflict != nil || !hasArrived) || frReinforcement) && selected == .NotSelectable {
                selected = .Normal
            }
        }
    }
    
    func updateUnitTexture() {
        
        if unitStrength == 0 {self.texture = nil; return Void()}
        
        if selected == .Selected {
            
            self.texture = SKTexture(imageNamed: imageNamesSelected[unitCode]!)
            
        } else if selected == .Normal {
            
            self.texture = SKTexture(imageNamed: imageNamesNormal[unitCode]!)
            
        } else if selected == .Off {
            
            self.texture = SKTexture(imageNamed: imageNamesOff[unitCode]!)
            
        } else if selected == .NotSelectable {
            
            self.texture = SKTexture(imageNamed: imageNamesGreyedOut[unitCode]!)
            
        }
    }
    
    func unitTypeName() -> String {
        
        var name:String = ""
        
        switch(unitType) {
            
        case .Grd: name = "grd"
            
        case .Inf: name = "inf"
            
        case .Cav: name = "cav"
            
        case .Ldr: name = "ldr"
            
        case .Art: name = "art"
            
        }
        
        return name
    }
    
    func backCodeFromStrengthAndType() -> Int {
        
        var theCode:Int = 0
        
        switch(unitType) {
            
        case .Grd: theCode = 40
            
        case .Inf: theCode = 30
            
        case .Cav: theCode = 20
            
        default: theCode = 10
            
        }
        
        theCode += unitStrength
            
        return theCode
    }
    
    func setPropertiesWithUnitCode () {
        
        let theCode:String = String(unitCode)
        var theCodeArray:[Int?] = []
        
        for char in theCode.characters {
            theCodeArray += [Int(String(char))]
        }
        
        switch theCodeArray[0]! {
            
            case 1: unitSide = .Austrian
            case 2: unitSide = .French
            default: unitSide = .Neutral
        
        }
        
        switch theCodeArray[1]! {
            
        case 1: unitType = .Art
        case 2: unitType = .Cav
        case 3: unitType = .Inf
        case 4: unitType = .Grd; startedAsGrd = true
        case 5: unitType = .Ldr
        default: unitType = .Inf
            
        }
        
        unitStrength = theCodeArray[2]!
    }
    
    func setCodewithProperties () {
        
        let unitCodeLdr:Double = unitCode - Double(Int(unitCode))
        var unitCodeSide:Int = 100
        var unitCodeType:Int = 10
        
        switch unitSide {
            
        case .Austrian: unitCodeSide = 100
        case .French: unitCodeSide = 200
        default: unitCodeSide = 0
            
        }
        
        switch unitType {
            
        case .Art: unitCodeType = 10
        case .Cav: unitCodeType = 20
        case .Inf: unitCodeType = 30
        case .Grd: unitCodeType = 40
        case .Ldr: unitCodeType = 50
            
        }
        
        unitCode = Double(unitCodeSide)+Double(unitCodeType)+Double(unitStrength)+unitCodeLdr
    }
    
    // Increase or decrease unit strength, return true if adding strength and its artillery
    func decrementStrength(reduce:Bool = true) {
        
        if reduce {
            unitCode -= 1
            unitStrength -= 1
            if unitStrength == 0 {self.selected = .NotSelectable; self.removeFromParent()}
            if unitType == .Grd {unitType = .Inf; unitCode -= 10}
        } else {
            if unitStrength == 0 {parentCommand!.addChild(self); self.selected = .Normal; self.zPosition = 100}
            unitCode += 1
            unitStrength += 1
            if startedAsGrd && unitStrength == 3 {unitType = .Grd; unitCode += 10}
        }
        self.updateUnitTexture()
        parentCommand!.unitsUpkeep(false)
    }
}
