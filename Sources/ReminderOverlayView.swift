//
//  ReminderOverlayView.swift
//  OnCue
//
//  SwiftUI view rendered inside the OverlayWindow.
//  Banner (trailing) → tow line → flyby character (leading), gliding left → right with a gentle bob.
//

import SwiftUI
import AppKit

struct ReminderOverlayView: View {
    let meetingTitle: String
    let minutesUntil: Int
    let reminderImageURL: URL?
    let onFinish: () -> Void

    @State private var animate = false
    @State private var hasStarted = false

    private let bannerGreen = Color(red: 8 / 255, green: 194 / 255, blue: 37 / 255)
    private let flightDuration: Double = 12.0

    var body: some View {
        GeometryReader { geo in
            let offscreenPadding = max(geo.size.width * 0.35, 760)

            TimelineView(.animation) { timeline in
                let bob = sin(timeline.date.timeIntervalSinceReferenceDate * 2.8) * 8

                reminderBanner
                    .offset(y: geo.size.height * 0.28 + bob)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: animate ? geo.size.width + offscreenPadding : -offscreenPadding)
            .animation(.linear(duration: flightDuration), value: animate)
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true

                // Start on the next run loop so SwiftUI commits the offscreen
                // left position before animating to the right.
                DispatchQueue.main.async {
                    animate = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration + 0.1) {
                    onFinish()
                }
            }
        }
    }

    private var reminderBanner: some View {
        HStack(spacing: -2) {
            // Banner trails behind the reminder image as the group moves left to right.
            Text("\(meetingTitle) in \(minutesUntil) min")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 460)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bannerGreen)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                )

            Rectangle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 28, height: 3)

            flybyImage
                .frame(width: 112, height: 72)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .fixedSize()
    }

    @ViewBuilder
    private var flybyImage: some View {
        if let url = reminderImageURL, let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
        } else {
            DefaultFlybyAssetView(animated: true)
        }
    }
}

struct DefaultFlybyAssetView: View {
    let animated: Bool

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                asset(phase: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            asset(phase: 0)
        }
    }

    private func asset(phase: TimeInterval) -> some View {
        let stride = animated ? sin(phase * 14) : 0
        let dustScale = animated ? (1 + sin(phase * 10) * 0.08) : 1

        return ZStack(alignment: .bottomLeading) {
            dustTrail(scale: dustScale)
                .offset(x: 2, y: -4)

            duck(stride: stride)
                .frame(width: 68, height: 58)
                .offset(x: 38, y: -1)
        }
        .frame(width: 112, height: 72, alignment: .bottomLeading)
        .accessibilityLabel("Running duck")
    }

    private func dustTrail(scale: Double) -> some View {
        ZStack {
            dustPuff(width: 24, height: 18)
                .offset(x: 20, y: 5)
            dustPuff(width: 18, height: 14)
                .offset(x: 8, y: 9)
            dustPuff(width: 14, height: 11)
                .offset(x: 35, y: 11)
        }
        .scaleEffect(scale, anchor: .bottomTrailing)
        .frame(width: 56, height: 34, alignment: .bottomLeading)
    }

    private func dustPuff(width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(Color.white.opacity(0.96))
            .frame(width: width, height: height)
            .shadow(color: Color(red: 0.93, green: 0.80, blue: 0.55).opacity(0.45), radius: 1, y: 1)
    }

    private func duck(stride: Double) -> some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.97, green: 0.58, blue: 0.20))
                .frame(width: 12, height: 6)
                .offset(x: -10, y: 23 + stride * 2)
                .rotationEffect(.degrees(16))

            Capsule()
                .fill(Color(red: 0.97, green: 0.58, blue: 0.20))
                .frame(width: 12, height: 6)
                .offset(x: 16, y: 24 - stride * 2)
                .rotationEffect(.degrees(-12))

            Ellipse()
                .fill(Color(red: 1.0, green: 0.84, blue: 0.28))
                .frame(width: 48, height: 42)
                .rotationEffect(.degrees(-8))
                .offset(x: 2, y: 8)

            Ellipse()
                .fill(Color(red: 0.91, green: 0.70, blue: 0.20))
                .frame(width: 20, height: 14)
                .rotationEffect(.degrees(-18))
                .offset(x: 2, y: 10)

            Circle()
                .fill(Color(red: 1.0, green: 0.86, blue: 0.31))
                .frame(width: 30, height: 30)
                .offset(x: 15, y: -14)

            Capsule()
                .fill(Color(red: 0.98, green: 0.50, blue: 0.16))
                .frame(width: 20, height: 9)
                .offset(x: 35, y: -12)
                .rotationEffect(.degrees(-2))

            Circle()
                .fill(.black.opacity(0.82))
                .frame(width: 4.5, height: 4.5)
                .offset(x: 22, y: -19)

            Path { path in
                path.move(to: CGPoint(x: 20, y: 6))
                path.addLine(to: CGPoint(x: 28, y: 0))
                path.addLine(to: CGPoint(x: 30, y: 11))
            }
            .stroke(Color(red: 0.83, green: 0.59, blue: 0.12), lineWidth: 2.2)
            .offset(x: -10, y: -2)
        }
    }
}
