//
//  DetectionLayer.swift
//  Human-Detection
//
//  Created by Brenda Lau on 07/09/2020.
//

import UIKit

class DetectionLayer: CALayer {
    func setup(within frame: CGRect, position: CGPoint) {
        self.name = "DetectionLayer"
        self.masksToBounds = true
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.bounds = frame
        self.position = position
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        self.frame = UIScreen.main.bounds
    }

    func addDetectionBox(frame: CGRect, identifier: String, boundingBox: CGRect, verticalPadding: CGFloat = 50, horizontalPadding: CGFloat = 100) {
        let boxLayer = CAShapeLayer()
        boxLayer.name = identifier
        boxLayer.frame = frame
        boxLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        boxLayer.fillColor = nil
        boxLayer.strokeColor = UIColor.red.cgColor
        boxLayer.lineWidth = 1
        boxLayer.shadowOpacity = 0.7
        boxLayer.shadowRadius = 5
        self.addSublayer(boxLayer)
        self.updateDetectionBox(rectangleLayer: boxLayer, boundingBox: boundingBox, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding)
    }

    func updateDetectionBox(rectangleLayer: CAShapeLayer, boundingBox: CGRect, verticalPadding: CGFloat = 50, horizontalPadding: CGFloat = 100) {
        CATransaction.begin()
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        let rectanglePath = CGMutablePath()
        let newBodyBounds = CGRect(
            x: max(0, boundingBox.minX - horizontalPadding),
            y: max(0,boundingBox.minY - verticalPadding),
            width: min(self.bounds.width, boundingBox.width + (horizontalPadding * 2)),
            height: min(self.bounds.height, boundingBox.height + (verticalPadding * 2))
        )

        rectanglePath.addRect(newBodyBounds)
        rectangleLayer.path = rectanglePath
        CATransaction.commit()
    }

    func displayDetectionBox(frame: CGRect, identifier: String, boundingBox: CGRect, verticalPadding: CGFloat = 0, horizontalPadding: CGFloat = 0) {
        if let layer = self.sublayers?.first(where: { $0.name == identifier }) as? CAShapeLayer {
            self.updateDetectionBox(rectangleLayer: layer, boundingBox: boundingBox, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding)
        } else {
            self.addDetectionBox(frame: frame, identifier: identifier, boundingBox: boundingBox, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding)
        }
    }

    func removeAllDetectionBox() {
        self.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}
