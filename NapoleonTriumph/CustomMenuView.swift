//
//  CustomMenuView.swift
//  NapoleonTriumph
//
//  Created by Dipen Patel on 10/16/15.
//  Copyright © 2015 Justin Anderson. All rights reserved.
//

import UIKit

class CustomMenuView: UIView {

    override init (frame : CGRect) {
        super.init(frame : frame)
    }
    
    convenience init () {
        self.init(frame:CGRect.zero)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    class PassThroughView: UIView {
        override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
            for subview in subviews as [UIView] {
                if !subview.hidden && subview.alpha > 0 && subview.userInteractionEnabled && subview.pointInside(convertPoint(point, toView: subview), withEvent: event) {
                    return true
                }
            }
            return true
        }
    }
   
}
