//
//  CameraPreviewView.swift
//  Microscope Viewer Camera
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import AVFoundation

/// UIKit wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint) -> Void
    let onPinchZoom: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        view.onTap = onTap
        view.onPinchZoom = onPinchZoom
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard session !== oldValue, let session = session else { return }
            previewLayer.session = session
        }
    }
    
    var onTap: ((CGPoint) -> Void)?
    var onPinchZoom: ((CGFloat) -> Void)?
    
    /// Tracks the zoom factor at the start of a pinch gesture
    private var initialPinchZoom: CGFloat = 1.0
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add tap gesture recognizer for focus/exposure
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        // Add pinch gesture recognizer for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Convert to device coordinates (0,0 to 1,1)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        
        onTap?(devicePoint)
        
        // Show focus indicator
        showFocusIndicator(at: location)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialPinchZoom = gesture.scale
        case .changed:
            // The scale relative to the start of this gesture
            let zoomDelta = gesture.scale / initialPinchZoom
            initialPinchZoom = gesture.scale
            onPinchZoom?(zoomDelta)
        default:
            break
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        // Remove existing indicators
        layer.sublayers?.filter { $0.name == "focusIndicator" }.forEach { $0.removeFromSuperlayer() }
        
        let indicator = CALayer()
        indicator.name = "focusIndicator"
        indicator.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        indicator.position = point
        indicator.borderColor = UIColor.yellow.cgColor
        indicator.borderWidth = 2
        indicator.cornerRadius = 40
        
        layer.addSublayer(indicator)
        
        // Animate
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.5
        animation.toValue = 1.0
        animation.duration = 0.3
        
        indicator.add(animation, forKey: "scale")
        
        // Remove after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            indicator.removeFromSuperlayer()
        }
    }
}
