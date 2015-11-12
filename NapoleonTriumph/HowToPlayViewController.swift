//
//  HowToPlayViewController.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 9/30/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

//import Foundation
import UIKit

class HowToPlayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let arrayTitles:NSArray = ["Basics", "Tutorial", "Rules", "History"]
    let webView:UIWebView = UIWebView()
    override func viewDidLoad() {
        
        //Left side tableview to show index
        let tableMenu:UITableView = UITableView(frame: CGRectMake(0, 0, 100, self.view.frame.size.height)) as UITableView
        tableMenu.delegate = self
        tableMenu.dataSource = self
        self.view.addSubview(tableMenu)
        
        //Right side content view. Note that i used webview as it seems in DF game they are showing static html file.
        //This is a quick turn around right nowl
        //I am not sure why i need to apply 30 to y position but if i won't apply then it cuts the webview
        webView.frame = CGRectMake(100, 30, self.view.frame.size.width-100, self.view.frame.size.height-30)
        self.view.addSubview(webView)
        
        //To close current screen and go back to menu sceeen
        let backButton: UIBarButtonItem = UIBarButtonItem(title: "Close", style: UIBarButtonItemStyle.Plain, target: self, action: "closeMenu") as UIBarButtonItem
        self.navigationItem.leftBarButtonItem=backButton
        self.navigationItem.title="How to play"
        
    }
    
    func closeMenu()
    {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    // MARK: TableView Delegate
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrayTitles.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCellWithIdentifier("Cell")
        
        if cell == nil
        {
            cell=UITableViewCell.init(style: UITableViewCellStyle.Default, reuseIdentifier: "Cell")
        }
        
        cell!.textLabel?.text = arrayTitles.objectAtIndex(indexPath.row) as? String
        
        return cell!
    }
    
    // MARK: Web links
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        var link:String = "https://google.com"
        if indexPath.row == 0
        {
            link = "https://google.com"
        }
        else if indexPath.row == 1
        {
            link = "https://yahoo.com"
        }
        else if indexPath.row == 2
        {
            link = "https://dropbox.com"
        }
        else
        {
            link =  "https://apple.com"
        }
        webView.loadRequest(NSURLRequest.init(URL: NSURL.init(string: link)!))
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

