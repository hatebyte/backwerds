//
//  Box.swift
//  RecordReversedSound
//
//  Created by Scott Jones on 12/30/15.
//  Copyright © 2015 Barf. All rights reserved.
//

import Foundation

class Box<T>  {
    let unbox: T
    init(_ value: T) {
        self.unbox = value
    }
}