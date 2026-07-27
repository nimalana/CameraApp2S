//
//  FocusSliderView.swift
//  Microscope Viewer Camera
//
//  Custom vertical focus slider that spans most of the screen height
//  with a uniform track color and smooth autofocus tracking.
//

import SwiftUI

/// A tall vertical slider for fine-grained manual focus control.
/// Touching the slider switches to manual focus; tapping the camera
/// preview switches back to autofocus. The thumb is white when manual
/// and semi-transparent when autofocusing.
struct FocusSliderView: View {
    @Binding var value: Float
    let isAutoFocusEnabled: Bool
    let onChanged: (Float) -> Void
    /// Called when the user first touches the slider, before any drag values are sent.
    let onManualFocusStarted: () -> Void
    
    @State private var isDragging = false
    
    private let trackWidth: CGFloat = 3
    private let thumbSize: CGFloat = 24
    
    var body: some View {
        // The slider track + thumb
        GeometryReader { geometry in
            let trackHeight = geometry.size.height
            let thumbY = (1.0 - CGFloat(value)) * (trackHeight - thumbSize) + thumbSize / 2
            
            ZStack {
                // Track
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: trackWidth)
                
                // Thumb
                Circle()
                    .fill(isAutoFocusEnabled ? .white.opacity(0.5) : .white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .position(x: geometry.size.width / 2, y: thumbY)
                    .animation(isDragging ? nil : .easeOut(duration: 0.15), value: value)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            // First touch — switch to manual focus and sync position
                            isDragging = true
                            onManualFocusStarted()
                        }
                        let fraction = 1.0 - ((drag.location.y - thumbSize / 2) / (trackHeight - thumbSize))
                        let clamped = Float(min(max(fraction, 0), 1))
                        value = clamped
                        onChanged(clamped)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(width: 40)
    }
}
