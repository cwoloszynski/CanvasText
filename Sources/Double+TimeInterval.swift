//
//  Double+TimeInterval.swift
//  CanvasText-iOS
//
//  Created by Charlie Woloszynski on 10/16/17.
//  Copyright © 2017 Canvas Labs, Inc. All rights reserved.
//

import Foundation

extension Double {
    public var seconds: TimeInterval {
        return TimeInterval(self)
    }
    
    public var minutes: TimeInterval {
        return TimeInterval(self*60)
    }
    
    public var milliseconds: TimeInterval {
        return TimeInterval(self/1000.0)
    }
}
