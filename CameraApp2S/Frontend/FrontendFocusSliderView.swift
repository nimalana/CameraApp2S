//
//  FocusSliderView.swift
//  CameraApp2S
//
//  Custom vertical focus slider that spans most of the screen height
//  with a uniform track color and smooth autofocus tracking.
//

import SwiftUI

/// A tall vertical slider for fine-grained manual focus control.
/// When autofocus is enabled the thumb tracks the lens position but
/// cannot be dragged. A prominent AF/MF toggle sits above the slider.
struct FocusSliderView: View {
    @Binding var value: Float
    let isAutoFocusEnabled: Bool
    let onChanged: (Float) -> Void
    let onToggleAutoFocus: () -> Void
    
    @State private var isDragging = false
    
    private let trackWidth: CGFloat = 3
    private let thumbSize: CGFloat = 24
    
    var body: some View {
        VStack(spacing: 10) {
            // AF / MF toggle — prominent pill at the top
            Button {
                onToggleAutoFocus()
            } label: {
                HStack(spacing: 0) {
                    Text("AF")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isAutoFocusEnabled ? .black : .white.opacity(0.5))
                        .frame(width: 30, height: 26)
                        .background(isAutoFocusEnabled ? .white : .clear, in: RoundedRectangle(cornerRadius: 6))
                    
                    Text("MF")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(!isAutoFocusEnabled ? .black : .white.opacity(0.5))
                        .frame(width: 30, height: 26)
                        .background(!isAutoFocusEnabled ? .white : .clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(2)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel(isAutoFocusEnabled ? "Auto focus on, tap for manual" : "Manual focus on, tap for auto")
            
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
                    isAutoFocusEnabled ? nil :
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
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
}
