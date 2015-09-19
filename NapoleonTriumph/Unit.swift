//
//  Unit.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-19.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

//Unit naming convention: 3-digit code: 1st: 1/2 Austrian/French, 2nd: 1/2/3/4/5 Art/Cav/Inf/Guard/Leader, 3rd: 0/1/2/3 Strength

enum Type {case Inf, Cav, Art, Grd, Ldr}

enum SelectType {case Normal, Selected, Off, NotSelectable}

class Unit: SKSpriteNode {
    
    var selected:SelectType = .Normal {
        didSet {updateUnitTexture()}
    }
    
    var unitCode:Double = 133.0
    var unitStrength:Int = 3
    var unitSide:Allegience = .Austrian
    var unitType:Type = .Inf
    var fixed:Bool = false
    var hasMoved:Bool = false
    
    var alreadyDefended:Bool = false
    var wasInBattle:Bool = false
    var parentCommand:Command?
    
    //Add a converter from the current properties to unitCode and from unitCode to set the properties
    
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
        if unitType == .Ldr {alreadyDefended = true}
        //self.userInteractionEnabled = false
        
    }
    
    deinit {
        print("Unit Deinitialized", terminator: "")
    }
    
    // MARK: Update Unit Properties
    
    func updateUnitTexture() {
        
        if unitStrength == 0 {self.texture = nil; return Void()}
        
        if selected == .Selected {
            
            self.texture = SKTexture(imageNamed: imageNamesSelected[unitCode]!)
            
        } else if selected == .Normal {
            
            self.texture = SKTexture(imageNamed: imageNamesNormal[unitCode]!)
            
        } else if selected == .Off {
            
            self.texture = SKTexture(imageNamed: imageNamesBlank[unitSide]!)
            
        } else if selected == .NotSelectable {
            
            self.texture = SKTexture(imageNamed: imageNamesNotSelectable[unitCode]!)
            
        }
    }
    
    func setPropertiesWithUnitCode () {
        
        let theCode:String = String(unitCode)
        //let unitsAsArray:Array = split(theUnits.characters){$0 == " "}.map(String.init)
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
        case 4: unitType = .Grd
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
        //let theParent = self.parent as? Command
        if reduce {
            unitCode--
            unitStrength--
            if unitStrength == 0 {self.selected = .NotSelectable; self.removeFromParent()}
        } else {
            if unitStrength == 0 {parentCommand!.addChild(self); self.selected = .Normal; self.zPosition = 100}
            unitCode++
            unitStrength++
        }
        
        self.updateUnitTexture()
        parentCommand!.unitsUpkeep(false)
        //if unitType == .Art {return true} else {return false}
    }
}
