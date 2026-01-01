//
//  NewYearGreetingView.swift
//  RunAnywhereAI
//
//  A festive New Year 2026 greeting view with confetti, fireworks,
//  and the "RunAnywhere" brand message - perfect for viral sharing!
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Screen Size Helper

private struct ScreenSize {
    static var width: CGFloat {
        #if os(iOS)
        return ScreenSize.width
        #else
        return NSScreen.main?.frame.width ?? 800
        #endif
    }
    
    static var height: CGFloat {
        #if os(iOS)
        return ScreenSize.height
        #else
        return NSScreen.main?.frame.height ?? 600
        #endif
    }
}

// MARK: - New Year Greeting View

/// A stunning New Year 2026 greeting with animations
/// Shows when TTS speaks New Year messages - perfect for viral moments!
struct NewYearGreetingView: View {
    @Binding var isVisible: Bool
    var onDismiss: (() -> Void)?
    
    @State private var showGreeting = false
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var fireworks: [Firework] = []
    @State private var glowIntensity: Double = 0.5
    @State private var yearScale: CGFloat = 0.1
    @State private var messageOpacity: Double = 0
    @State private var runnerVisible = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: 0x0F0C29),
                    Color(hex: 0x302B63),
                    Color(hex: 0x24243E)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated stars background
            StarsBackground()
            
            // Fireworks
            ForEach(fireworks) { firework in
                FireworkView(firework: firework)
            }
            
            // Confetti
            ForEach(confettiPieces) { piece in
                ConfettiPieceView(piece: piece)
            }
            
            // Main greeting content
            VStack(spacing: 30) {
                Spacer()
                
                // Glowing "2026"
                ZStack {
                    // Glow effect
                    Text("2026")
                        .font(.system(size: 100, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primaryAccent)
                        .blur(radius: 20)
                        .opacity(glowIntensity)
                    
                    // Main text with gradient
                    Text("2026")
                        .font(.system(size: 100, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xFFD700),
                                    AppColors.primaryAccent,
                                    Color(hex: 0xFF6B35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AppColors.primaryAccent.opacity(0.5), radius: 10)
                }
                .scaleEffect(yearScale)
                
                // "Happy New Year" text
                VStack(spacing: 8) {
                    Text("Happy New Year!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("from")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // RunAnywhere branding
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primaryAccent)
                        
                        Text("RunAnywhere")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.primaryAccent, Color(hex: 0xFFD700)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .opacity(messageOpacity)
                
                // Tagline
                Text("AI that runs anywhere, anytime! 🚀")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(messageOpacity)
                    .padding(.top, 10)
                
                Spacer()
                
                // Running athlete animation
                if runnerVisible {
                    RunningAthleteView(isRunning: true, showNewYearTheme: true)
                        .frame(height: 120)
                }
                
                Spacer()
                
                // Dismiss button
                Button(action: {
                    dismissGreeting()
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Start Speaking!")
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primaryAccent, Color(hex: 0xFF6B35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: AppColors.primaryAccent.opacity(0.5), radius: 10)
                }
                .opacity(messageOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate year scaling in
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            yearScale = 1.0
        }
        
        // Start glow pulsing
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
        
        // Fade in message
        withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
            messageOpacity = 1.0
        }
        
        // Show runner
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring()) {
                runnerVisible = true
            }
        }
        
        // Start confetti
        startConfetti()
        
        // Start fireworks
        startFireworks()
    }
    
    private func startConfetti() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard isVisible else {
                timer.invalidate()
                return
            }
            
            let colors: [Color] = [
                .red, .orange, .yellow, .green, .blue, .purple, .pink,
                AppColors.primaryAccent, Color(hex: 0xFFD700)
            ]
            
            let piece = ConfettiPiece(
                id: UUID(),
                x: CGFloat.random(in: 0...ScreenSize.width),
                y: -20,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5),
                color: colors.randomElement() ?? .yellow,
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle,
                velocity: CGFloat.random(in: 100...300),
                rotationSpeed: Double.random(in: -360...360)
            )
            confettiPieces.append(piece)
            
            // Animate falling
            withAnimation(.linear(duration: 4.0)) {
                if let index = confettiPieces.firstIndex(where: { $0.id == piece.id }) {
                    confettiPieces[index].y = ScreenSize.height + 50
                    confettiPieces[index].rotation += confettiPieces[index].rotationSpeed * 4
                }
            }
            
            // Clean up
            confettiPieces.removeAll { $0.y > ScreenSize.height }
        }
    }
    
    private func startFireworks() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            guard isVisible else {
                timer.invalidate()
                return
            }
            
            let colors: [Color] = [
                AppColors.primaryAccent,
                Color(hex: 0xFFD700),
                .red,
                .blue,
                .green,
                .purple
            ]
            
            let firework = Firework(
                id: UUID(),
                x: CGFloat.random(in: 50...(ScreenSize.width - 50)),
                y: CGFloat.random(in: 100...300),
                color: colors.randomElement() ?? AppColors.primaryAccent,
                particles: (0..<20).map { _ in
                    FireworkParticle(
                        id: UUID(),
                        angle: Double.random(in: 0...360),
                        distance: CGFloat.random(in: 30...80),
                        size: CGFloat.random(in: 3...8)
                    )
                }
            )
            fireworks.append(firework)
            
            // Remove after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                fireworks.removeAll { $0.id == firework.id }
            }
        }
    }
    
    private func dismissGreeting() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }
        onDismiss?()
    }
}

// MARK: - Stars Background

struct StarsBackground: View {
    @State private var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: stars.count > index ? stars[index].size : 2, 
                               height: stars.count > index ? stars[index].size : 2)
                        .position(x: stars.count > index ? stars[index].x : 0,
                                  y: stars.count > index ? stars[index].y : 0)
                        .opacity(stars.count > index ? stars[index].opacity : 0.5)
                }
            }
            .onAppear {
                stars = (0..<50).map { _ in
                    (
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        size: CGFloat.random(in: 1...4),
                        opacity: Double.random(in: 0.3...1.0)
                    )
                }
                
                // Twinkle animation
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    for i in 0..<stars.count {
                        stars[i].opacity = Double.random(in: 0.2...1.0)
                    }
                }
            }
        }
    }
}

// MARK: - Firework View

struct FireworkView: View {
    let firework: Firework
    @State private var exploded = false
    
    var body: some View {
        ZStack {
            ForEach(firework.particles) { particle in
                Circle()
                    .fill(firework.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: exploded ? cos(particle.angle * .pi / 180) * particle.distance : 0,
                        y: exploded ? sin(particle.angle * .pi / 180) * particle.distance : 0
                    )
                    .opacity(exploded ? 0 : 1)
            }
        }
        .position(x: firework.x, y: firework.y)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                exploded = true
            }
        }
    }
}

// MARK: - Confetti Piece View

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    
    var body: some View {
        Group {
            switch piece.shape {
            case .rectangle:
                Rectangle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 6 * piece.scale)
            case .circle:
                Circle()
                    .fill(piece.color)
                    .frame(width: 8 * piece.scale, height: 8 * piece.scale)
            case .triangle:
                Triangle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            case .star:
                SparkleShape()
                    .fill(piece.color)
                    .frame(width: 12 * piece.scale, height: 12 * piece.scale)
            }
        }
        .rotationEffect(.degrees(piece.rotation))
        .position(x: piece.x, y: piece.y)
    }
}

// MARK: - Models

struct Firework: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let particles: [FireworkParticle]
}

struct FireworkParticle: Identifiable {
    let id: UUID
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
}

struct ConfettiPiece: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var color: Color
    var shape: ConfettiShape
    var velocity: CGFloat
    var rotationSpeed: Double
}

enum ConfettiShape: CaseIterable {
    case rectangle, circle, triangle, star
}

// MARK: - Supporting Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = 4
        let innerRadius = rect.width * 0.2
        let outerRadius = rect.width * 0.5
        
        for i in 0..<points * 2 {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - New Year Banner (Compact Version)

/// A compact banner for showing New Year wishes during TTS
struct NewYearBanner: View {
    let isVisible: Bool
    
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Text("🎆")
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Happy New Year 2026!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("RunAnywhere wishes you success!")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text("🎇")
                    .font(.system(size: 24))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: 0x302B63),
                            Color(hex: 0x24243E)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Shimmer effect
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 100)
                    .offset(x: shimmerOffset)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.primaryAccent, Color(hex: 0xFFD700)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppColors.primaryAccent.opacity(0.3), radius: 8)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerOffset = 400
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

struct NewYearGreetingView_Previews: PreviewProvider {
    static var previews: some View {
        NewYearGreetingView(isVisible: .constant(true))
        
        VStack {
            NewYearBanner(isVisible: true)
                .padding()
            Spacer()
        }
        .background(Color.black)
    }
}

