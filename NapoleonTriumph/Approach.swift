//
//  Approach.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2015-07-18.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import SpriteKit

class Approach:Location {
    
    let wideApproach:Bool
    let obstructedApproach:Bool
    let infApproach:Bool
    let cavApproach:Bool
    let artApproach:Bool
    let hillApproach:Bool
    
    var oppApproach:Approach?
    var adjReserve:Reserve?
    var ownReserve:Reserve?
    var defenseRequired:Bool = false // Used to store whether the approach's defense has been resolved (either via retreat with emptied locale or defend order and defense sent
    var turnOfLastArtVolley:Int = 0
    
    let oppApproachName:String
    let adjReserveName:String
    let ownReserveName:String
    
    let approachLength:Int!
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init (theDict:Dictionary<NSObject, AnyObject>, scaleFactor:CGFloat, reserveLocation:Bool) {
    
        let theInf:NSString = theDict["inf"] as AnyObject? as! NSString
        infApproach = theInf.boolValue
        
        let theCav:NSString = theDict["cav"] as AnyObject? as! NSString
        cavApproach = theCav.boolValue
        
        let theArt:NSString = theDict["art"] as AnyObject? as! NSString
        artApproach = theArt.boolValue
        
        let theObs:NSString = theDict["obs"] as AnyObject? as! NSString
        obstructedApproach = theObs.boolValue
        
        let theHill:NSString = theDict["hill"] as AnyObject? as! NSString
        hillApproach = theHill.boolValue
        
        let theWide:NSString = theDict["wide"] as AnyObject? as! NSString
        wideApproach = theWide.boolValue
        if wideApproach {approachLength = 2} else {approachLength = 1}
        
        let theOppApproachName:String = theDict["oppositeApproach"] as AnyObject? as! String
        oppApproachName = theOppApproachName
        
        let theAdjacentReserveName:String = theDict["adjacentReserve"] as AnyObject? as! String
        adjReserveName = theAdjacentReserveName
        
        let theOwnReserveName:String = theDict["ownReserve"] as AnyObject? as! String
        ownReserveName = theOwnReserveName
        
        super.init(theDict: theDict, scaleFactor: scaleFactor, reserveLocation: reserveLocation)
        
        let theID:String = theDict["id"] as AnyObject? as! String
        self.name = theID
        
    }
    
}