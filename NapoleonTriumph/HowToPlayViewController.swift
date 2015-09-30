//
//  HowToPlayViewController.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 9/30/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import Foundation
import UIKit


class HowToPlayViewController: UITableViewController {

    let arrayTitles:NSArray = ["Basics", "Tutorial", "Rules", "History"]
    
    override func viewDidLoad() {

        let backButton: UIBarButtonItem = UIBarButtonItem(title: "close", style: UIBarButtonItemStyle.Plain, target: self, action: "closeMenu") as UIBarButtonItem
        self.navigationItem.leftBarButtonItem=backButton
        self.navigationItem.title="How to play"
    
    }
    
    func closeMenu()
    {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrayTitles.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) 
        
        cell.textLabel?.text = arrayTitles.objectAtIndex(indexPath.row) as? String
        
        return cell
    }
    
}
