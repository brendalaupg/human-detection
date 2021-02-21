//
//  CameraViewController.swift
//  Human-Detection
//
//  Created by Brenda Lau on 04/09/2020.
//

import UIKit
import AVKit
import Vision

protocol CameraViewControllerOutputDelegate: class {
    func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

class CameraViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet private weak var countLabel: UILabel?
    @IBOutlet private weak var cameraFeedView: CameraFeedView!
    @IBOutlet private weak var previewImageView: UIImageView?

    private var rootLayer: AVCaptureVideoPreviewLayer {
        self.cameraFeedView.previewLayer
    }

    // MARK: - Variables
    // AV
    private var session: AVCaptureSession = AVCaptureSession()
    private let cameraDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    private var currentDevice: AVCaptureDevice?
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var mainDataOutput: AVCaptureOutput?
    private var deviceResolution: CGSize = .zero

    // Vision
    private var detectedRequests: [VNImageBasedRequest] = []
    private var trackingRequest: [VNTrackingRequest] = []
    private let confidenceThreshold: Float = 0.5
    private var frameCount: Int = 0
    private var boundingBoxRect: CGRect?

    // drawing
    var detectionOverlayLayer = DetectionLayer()
    var detectedRectangleLayers: [CAShapeLayer] = []

    weak var delegate: CameraViewControllerOutputDelegate?

    // MARK: - View Controller Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupAVSession()
        self.session.startRunning()
        self.beginCoreMLRequest()
        self.previewImageView?.layer.borderColor = UIColor.white.cgColor
        self.previewImageView?.layer.borderWidth = 5

        let overlayLayer = DetectionLayer()
        overlayLayer.name = "DetectionLayer"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        rootLayer.addSublayer(overlayLayer)
        overlayLayer.setup(within: self.cameraFeedView.bounds, position: CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY))
        self.detectionOverlayLayer = overlayLayer
        self.boundingBoxRect = self.cameraFeedView.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.detectionOverlayLayer.frame = self.cameraFeedView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.session.stopRunning()
    }

    // MARK: - Setup
    private func setupAVSession(position: AVCaptureDevice.Position = .front) {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)

        guard
            let device = discoverySession.devices.first,
            let deviceInput = try? AVCaptureDeviceInput(device: device)
        else {
            return
        }

        self.session.beginConfiguration()
        if device.supportsSessionPreset(.hd1920x1080) {
            self.session.sessionPreset = .hd1920x1080
        } else {
            self.session.sessionPreset = .high
        }

        if let currentDeviceInput = self.currentDeviceInput {
            self.session.removeInput(currentDeviceInput)
        }
        if self.session.canAddInput(deviceInput) {
            self.session.addInput(deviceInput)
            self.currentDeviceInput = deviceInput
            self.currentDevice = device
            self.updateResolution()
        }

        let dataOutput = AVCaptureVideoDataOutput()
        if self.session.canAddOutput(dataOutput) {
            self.session.addOutput(dataOutput)
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            dataOutput.setSampleBufferDelegate(self, queue: self.cameraDataOutputQueue)
            self.mainDataOutput = dataOutput
        }

        if let captureConnection = dataOutput.connection(with: .video),
           captureConnection.isCameraIntrinsicMatrixDeliverySupported {
            captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            captureConnection.preferredVideoStabilizationMode = .standard
            captureConnection.isEnabled = true
        }

        self.session.commitConfiguration()
        self.cameraFeedView.setup(session: self.session)
    }

    private func updateResolution() {
        guard let device = self.currentDevice else {
            return
        }
        let formatDescription = device.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        if UIDevice.current.orientation == .portrait {
            self.deviceResolution = CGSize(width: CGFloat(dimensions.height), height: CGFloat(dimensions.width))
        } else {
            self.deviceResolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }
    }

    // MARK: - IBActions (Camera)
    @IBAction private func flipCamera(_ sender: Any) {
        guard let currentDevice = self.currentDevice else {
            return
        }

        let newPosition: AVCaptureDevice.Position = currentDevice.position == .front ? .back : .front
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: newPosition)

        guard
            let newDevice = deviceDiscoverySession.devices.first,
            let newDeviceInput = try? AVCaptureDeviceInput(device: newDevice)
        else {
            return
        }

        self.session.stopRunning()
        self.session.beginConfiguration()
        if let currentInput = self.currentDeviceInput {
            self.session.removeInput(currentInput)
        }

        if self.session.canAddInput(newDeviceInput) {
            self.session.addInput(newDeviceInput)
        }

        self.currentDevice = newDevice
        self.currentDeviceInput = newDeviceInput
        self.session.commitConfiguration()
        self.session.startRunning()

        self.updateResolution()
    }

    @IBAction private func toggleCamera(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if self.session.isRunning {
            UIView.animate(withDuration: 0.25) {
                self.cameraFeedView.alpha = 0
            } completion: { _ in
                self.session.stopRunning()
                self.countLabel?.isHidden = true
            }
        } else {
            self.session.startRunning()
            UIView.animate(withDuration: 0.25) {
                self.cameraFeedView.alpha = 1
            } completion: { _ in
                self.countLabel?.isHidden = false
            }
        }
    }

    @IBAction private func togglePreview(_ sender: Any) {
        self.previewImageView?.isHidden = !(self.previewImageView?.isHidden ?? true)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    private func beginCoreMLRequest() {
        guard
            let modelURL = Bundle.main.url(forResource: "YOLOv3Int8LUT", withExtension: "mlmodelc"),
            let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL))
        else {
            debugPrint("error")
            return
        }

        let objectRecognition = VNCoreMLRequest(model: visionModel) { request, error in
            if let error = error {
                debugPrint("error: \(error.localizedDescription)")
                return
            }

            guard
                let request = request as? VNCoreMLRequest,
                let observations = request.results as? [VNRecognizedObjectObservation]
            else {
                DispatchQueue.main.async {
                    self.detectionOverlayLayer.removeAllDetectionBox()
                    self.countLabel?.text = "Object count: 0"
                    self.boundingBoxRect = nil
                }
                return
            }

            let filteredObservations = observations.filter({ $0.labels[0].identifier == "person" } )

            if filteredObservations.isEmpty {
                self.boundingBoxRect = nil
            }
            DispatchQueue.main.async {
                self.detectionOverlayLayer.removeAllDetectionBox()
                self.countLabel?.text = "Object count: \(filteredObservations.count)"

                for observation in filteredObservations where observation.confidence > self.confidenceThreshold {
                    DispatchQueue.main.async {

                        var boundingBox = observation.boundingBox
                        if self.currentDevice?.position == .front {
                            boundingBox = boundingBox.applying(.verticalFlip)
                        }

//                        var boundingBox = observation.boundingBox.applying(CGAffineTransform.verticalFlip)
                        let convertRect = VNImageRectForNormalizedRect(boundingBox, Int(self.cameraFeedView.bounds.width), Int(self.cameraFeedView.bounds.height))
                        self.detectionOverlayLayer.displayDetectionBox(frame: self.cameraFeedView.bounds, identifier: observation.uuid.uuidString, boundingBox: convertRect)
                    }
                }

                if let firstObservation = filteredObservations.first {
                    DispatchQueue.main.async {
                        let boundingBox = firstObservation.boundingBox.applying(CGAffineTransform.verticalFlip)
                        if UIDevice.current.orientation == .portrait {
                            self.boundingBoxRect = VNImageRectForNormalizedRect(boundingBox, Int(self.deviceResolution.height), Int(self.deviceResolution.width))
                        } else {
                            self.boundingBoxRect = VNImageRectForNormalizedRect(boundingBox, Int(self.deviceResolution.width), Int(self.deviceResolution.height))
                        }
                    }
                }
            }
        }
        self.detectedRequests = [objectRecognition]
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }

        self.displayCroppedImage(from: pixelBuffer, cropRect: self.boundingBoxRect)
        self.frameCount += 1
        guard self.frameCount > 60 else {
            return
        }

        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[.cameraIntrinsics] = cameraIntrinsicData
        }
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()

        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: exifOrientation,
            options: requestHandlerOptions
        )

        try? imageRequestHandler.perform(self.detectedRequests)
        self.frameCount = 0
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.frameCount += 1
    }

    func displayCroppedImage(from pixelBuffer: CVPixelBuffer, cropRect: CGRect?) {
        var image = CIImage(cvImageBuffer: pixelBuffer)

        if UIDevice.current.orientation == .portrait {
            image = image.transformed(by: CGAffineTransform(rotationAngle: CGFloat.pi * 3 / 2))
            if self.currentDevice?.position == .front {
                image = image.transformed(by: CGAffineTransform.horizontalFlip)
            }

        } else {
            if self.currentDevice?.position == .front {
                image = image.transformed(by: CGAffineTransform.verticalFlip)
            }
        }
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))

        if var rect = cropRect {
            if rect.width > rect.height {
                let diff = rect.width - rect.height
                rect = CGRect(x: rect.minX, y: rect.minY - diff / 2, width: rect.width, height: rect.width)
            } else {
                let diff = rect.height - rect.width
                rect = CGRect(x: rect.minX - diff / 2, y: rect.minY, width: rect.height, height: rect.height)
            }

            image = image.cropped(to: rect)
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
        }

        DispatchQueue.main.async {
            self.previewImageView?.image = UIImage(ciImage: image)
        }
    }
}

// MARK: Handle Device Orientation & EXIF
extension CameraViewController {
    private func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        CGFloat(Double(degrees) * Double.pi / 180.0)
    }

    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        default:
            return .leftMirrored
        }
    }

    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        self.exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

