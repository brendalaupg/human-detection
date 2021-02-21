//
//  CGAffineTransform+.swift
//  Human-Detection
//
//  Created by Brenda Lau on 07/09/2020.
//

import UIKit

extension CGAffineTransform {
    static var verticalFlip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    static var horizontalFlip = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -1, y: 0)
}
