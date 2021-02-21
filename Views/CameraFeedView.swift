//
//  CameraFeedView.swift
//  Human-Detection
//
//  Created by Brenda Lau on 04/09/2020.
//

import UIKit
import AVFoundation

class CameraFeedView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        self.layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.configureVideoOrientation()
    }

    private func configureVideoOrientation() {
        guard
            let connection = self.previewLayer.connection,
            connection.isVideoOrientationSupported
        else {
            return
        }

        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            connection.videoOrientation = .portrait
        }
    }

    func setup(session: AVCaptureSession) {
        self.configureVideoOrientation()
        self.previewLayer.session = session
        self.previewLayer.name = "CameraFeedPreviewLayer"
        self.previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer.masksToBounds = true
    }
}
