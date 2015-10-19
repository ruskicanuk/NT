//
//  Game.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 10/19/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import UIKit

enum GameMode:String {
    case SinglePlayer
    case Multiplayer
}

class Game: NSObject, NSCoding {

   
    
    var gameMode: GameMode = GameMode.SinglePlayer
    var count : Int = 0
    
    init(score:Int, gameMode:GameMode) {
        self.count = 0
        self.gameMode = gameMode
    }
    
    required init(coder: NSCoder) {
        self.count = coder.decodeObjectForKey("count")! as! Int
        self.gameMode = GameMode(rawValue:coder.decodeObjectForKey("gamemode") as! String)!
        super.init()
    }
    
    func encodeWithCoder(coder: NSCoder) {
        
        coder.encodeObject(self.count, forKey: "count")
        coder.encodeObject(self.gameMode.rawValue, forKey:"gamemode" )
    }

}
