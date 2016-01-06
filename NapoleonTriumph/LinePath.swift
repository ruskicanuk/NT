//
//  LinePath.swift
//  NapoleonTriumph
//
//  Created by Justin Anderson on 2016-01-05.
//  Copyright © 2016 Justin Anderson. All rights reserved.
//

import Foundation
import SpriteKit

// Tracks a battle line used by commands / groups for organization purposes
class BattleLine {
    
    var leftRightPath:[Int:Reserve] = [:]
    
    init() {
        
    }
}

// Tracks a path between two points and the attributes of that path
class Pathway {

    var startReserve:Reserve
    var endReserve:Reserve
    
    // Shortest road path
    var shortestRdPath:[Reserve] = []
    
    // Shortest adjacent path
    var shortestAdjPath:[Reserve] = []
    
    // Stores a 2D array of all potential road paths (for objective markers)
    var possibleRdRoutes:[[Reserve]] = []
    
    init() {
        
    }
}