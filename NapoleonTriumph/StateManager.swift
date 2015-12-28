//
//  StateManager.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 10/19/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//
import UIKit

class StateManager {

    var games:[GameManager] = []

    init()
    {
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0] as! String
        let path = (documentsDirectory as NSString).stringByAppendingPathComponent("games.plist")
        let fileManager = NSFileManager.defaultManager()
        
        // check if file exists
        if !fileManager.fileExistsAtPath(path) {
            
            // create an empty file if it doesn't exist
            if let bundle = NSBundle.mainBundle().pathForResource("default", ofType: "plist") {

                do {
                    try fileManager.copyItemAtPath(bundle, toPath: path)
                } catch _ as NSError
                {
                    
                }
            }
        }
        
        if let rawData = NSData(contentsOfFile: path) {
            // do we get serialized data back from the attempted path?
            // if so, unarchive it into an AnyObject, and then convert to an array of HighScores, if possible
            let scoreArray: AnyObject? = NSKeyedUnarchiver.unarchiveObjectWithData(rawData);
            self.games = scoreArray as? [GameManager] ?? [];
        }
    }
    
    func save() {
        
        // find the save directory our app has permission to use, and save the serialized version of self.scores - the HighScores array.
        let saveData = NSKeyedArchiver.archivedDataWithRootObject(self.games);
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray;
        let documentsDirectory = paths.objectAtIndex(0) as! NSString;
        let path = documentsDirectory.stringByAppendingPathComponent("games.plist");
        
        saveData.writeToFile(path, atomically: true);
    }
    
    func addGame(game: GameManager)
    {
        self.games = []
        self.games.append(game)
        save()
    }
}
