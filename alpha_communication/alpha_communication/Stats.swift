//
//  Stats.swift
//  alpha_communication
//
//  Created by Pascal Sturmfels on 5/26/20.
//  Copyright © 2020 LooseFuzz. All rights reserved.
//

import Foundation

extension Array where Element == Float {
    var mean: Float { get {
        return self.reduce(0.0, +) / Float(self.count)
        }
    }
    
    var sd : Float { get {
        let computedMean: Float = self.mean
        let computedDenom: Float = self.reduce(0.0) { (result, element) -> Float in
            let partialDiff: Float = element - computedMean
            return result + partialDiff * partialDiff
        }
        return sqrtf(computedDenom / Float(self.count))
    }}
}

func hammingDistance(x: String, y: String) -> Int {
    if x.count != y.count {
        return max(x.count, y.count)
    }
    
    var distance: Int = 0
    for offset in 0..<x.count {
        let xChar: String = String(x[x.index(x.startIndex, offsetBy: offset)])
        let yChar: String = String(y[y.index(y.startIndex, offsetBy: offset)])
        if xChar != yChar {
            distance += 1
        }
    }
    return distance
}
