//
//  RunningAthleteView.swift
//  RunAnywhereAI
//
//  A beautiful, impressive running athlete animation
//  Represents RunAnywhere - AI that runs anywhere!
//

import SwiftUI
import AudioToolbox
import AVFoundation
#if os(iOS)
import UIKit
#endif

// MARK: - Running Athlete View

struct RunningAthleteView: View {
    let isRunning: Bool
    var showNewYearTheme: Bool = true
    
    @State private var legPhase = false
    @State private var armPhase = false
    @State private var bounce: CGFloat = 0
    @State private var breathe: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Magical clouds! ☁️✨
            MovingClouds(isRunning: isRunning)
                .offset(y: 65)
            
            // Speed lines (behind athlete)
            if isRunning {
                SpeedTrails()
                    .offset(x: -50, y: 10)
            }
            
            // Magical sparkle glow when running! 🦄✨
            if isRunning {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0xFF69B4).opacity(0.35), Color(hex: 0xFFB6C1).opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(breathe)
                    .offset(y: 5)
            }
            
            // MAGICAL UNICORN! 🦄✨
            RunningUnicorn(
                legPhase: legPhase,
                showNewYearTheme: showNewYearTheme
            )
            .offset(y: bounce + 5)
            .scaleEffect(1.5)
        }
        .frame(height: 160) // MORE HEIGHT for breathing room!
        .clipped()
        .onAppear { if isRunning { startRunning() } }
        .onChange(of: isRunning) { running in
            if running { startRunning() } else { stopRunning() }
        }
    }
    
    private func startRunning() {
        // Leg animation - fast running
        withAnimation(.linear(duration: 0.08).repeatForever(autoreverses: true)) {
            legPhase = true
            armPhase = true
        }
        // Bounce
        withAnimation(.easeInOut(duration: 0.08).repeatForever(autoreverses: true)) {
            bounce = -4
        }
        // Energy pulse
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            breathe = 1.3
        }
    }
    
    private func stopRunning() {
        withAnimation(.easeOut(duration: 0.3)) {
            legPhase = false
            armPhase = false
            bounce = 0
            breathe = 1.0
        }
    }
}

// MARK: - Running Unicorn! 🦄✨ (Realistic like reference!)

struct RunningUnicorn: View {
    let legPhase: Bool
    var showNewYearTheme: Bool
    
    // Unicorn Colors (matching reference exactly!)
    private let bodyWhite = Color(hex: 0xFFFAFA) // Snow white body
    private let bodyPink = Color(hex: 0xFFF0F5) // Lavender blush tint
    private let maneColor = Color(hex: 0xFF1493) // Deep pink mane (like reference)
    private let maneDark = Color(hex: 0xC71585) // Medium violet red for depth
    private let hornGold = Color(hex: 0xFFA500) // Orange gold horn
    private let hornLight = Color(hex: 0xFFD700) // Lighter gold
    private let hoofPink = Color(hex: 0xFFB6C1) // Light pink hooves
    private let nosePink = Color(hex: 0xFFB6C1) // Pink muzzle
    private let eyeColor = Color(hex: 0x4169E1) // Royal blue eye
    
    var body: some View {
        ZStack {
            // Soft cloud shadow
            Ellipse()
                .fill(Color.white.opacity(0.3))
                .frame(width: 60, height: 15)
                .blur(radius: 5)
                .offset(y: 48)
            
            // === BACK LEGS (behind body) ===
            RealisticUnicornLeg(phase: !legPhase, isBackPair: true, isRearLeg: true, bodyColor: bodyPink, hoofColor: hoofPink)
                .offset(x: -18, y: 12)
            
            RealisticUnicornLeg(phase: legPhase, isBackPair: true, isRearLeg: false, bodyColor: bodyPink, hoofColor: hoofPink)
                .offset(x: -5, y: 12)
            
            // === FLOWING TAIL (like reference - long & wavy!) ===
            RealisticUnicornTail(phase: legPhase, primaryColor: maneColor, secondaryColor: maneDark)
                .offset(x: -35, y: -5)
            
            // === BODY (elegant horse shape) ===
            ZStack {
                // Main body - elongated elegant shape
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [bodyWhite, bodyPink, bodyPink.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 55, height: 32)
                
                // Highlight on back
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 30, height: 12)
                    .offset(x: 0, y: -8)
                
                // ✨ Stars on flank (like reference!)
                Group {
                    Image(systemName: "star.fill")
                        .font(.system(size: 5))
                        .foregroundColor(maneColor.opacity(0.4))
                        .offset(x: 8, y: -2)
                    Image(systemName: "star.fill")
                        .font(.system(size: 4))
                        .foregroundColor(maneColor.opacity(0.3))
                        .offset(x: 14, y: 3)
                    Image(systemName: "star.fill")
                        .font(.system(size: 3))
                        .foregroundColor(maneColor.opacity(0.35))
                        .offset(x: 5, y: 5)
                }
                
                // "26" for New Year
                if showNewYearTheme {
                    Text("26")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(hornGold.opacity(0.8))
                        .offset(x: -5, y: 0)
                }
            }
            .rotationEffect(.degrees(-3))
            
            // === FRONT LEGS ===
            RealisticUnicornLeg(phase: !legPhase, isBackPair: false, isRearLeg: true, bodyColor: bodyWhite, hoofColor: hoofPink)
                .offset(x: 8, y: 12)
            
            RealisticUnicornLeg(phase: legPhase, isBackPair: false, isRearLeg: false, bodyColor: bodyWhite, hoofColor: hoofPink)
                .offset(x: 20, y: 12)
            
            // === NECK (elegant, curved) ===
            ZStack {
                // Neck shape
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [bodyWhite, bodyPink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 18, height: 35)
                
                // Neck highlight
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 8, height: 25)
                    .offset(x: 3)
                
                // Flowing mane on neck! (like reference)
                RealisticMane(primaryColor: maneColor, secondaryColor: maneDark)
                    .offset(x: -8, y: 5)
            }
            .rotationEffect(.degrees(40))
            .offset(x: 22, y: -22)
            
            // === HEAD (realistic horse head like reference!) ===
            ZStack {
                // Head base (elongated like real horse)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [bodyWhite, bodyPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 16, height: 30)
                
                // Forehead
                Ellipse()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 10, height: 12)
                    .offset(y: -6)
                
                // Muzzle (pink like reference!)
                Ellipse()
                    .fill(nosePink)
                    .frame(width: 14, height: 12)
                    .offset(y: 8)
                
                // Nostril
                Ellipse()
                    .fill(Color(hex: 0xDB7093).opacity(0.6))
                    .frame(width: 3, height: 2)
                    .offset(x: 3, y: 10)
                
                // Mouth line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 4, y: 2))
                }
                .stroke(Color(hex: 0xDB7093).opacity(0.4), lineWidth: 1)
                .frame(width: 8, height: 4)
                .offset(x: -1, y: 12)
                
                // Beautiful eye (like reference - big & expressive!)
                ZStack {
                    // Eye white
                    Ellipse()
                        .fill(Color.white)
                        .frame(width: 9, height: 8)
                    
                    // Iris
                    Ellipse()
                        .fill(eyeColor)
                        .frame(width: 6, height: 6)
                    
                    // Pupil
                    Circle()
                        .fill(Color.black)
                        .frame(width: 3.5, height: 3.5)
                    
                    // Eye shine (2 highlights like in reference)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 2.5, height: 2.5)
                        .offset(x: -1, y: -1)
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1.5, height: 1.5)
                        .offset(x: 1, y: 1)
                    
                    // Eyelashes (like reference!)
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 0.8, height: 3)
                            .offset(x: CGFloat(i) * 2 - 3, y: -5)
                            .rotationEffect(.degrees(Double(i - 2) * 12))
                    }
                }
                .offset(x: 1, y: -4)
                
                // Ear
                RealisticUnicornEar(bodyColor: bodyWhite, innerColor: nosePink)
                    .offset(x: -3, y: -16)
            }
            .rotationEffect(.degrees(30))
            .offset(x: 38, y: -42)
            
            // === GOLDEN SPIRAL HORN! 🦄 ===
            RealisticUnicornHorn(goldLight: hornLight, goldDark: hornGold)
                .offset(x: 48, y: -62)
            
            // === Forelock (flowing hair on forehead like reference) ===
            ForEach(0..<5, id: \.self) { i in
                WavyHairStrand(color: i % 2 == 0 ? maneColor : maneDark, 
                              length: CGFloat(15 - i * 2),
                              thickness: 3)
                    .rotationEffect(.degrees(Double(i) * 10 - 10))
                    .offset(x: 34 + CGFloat(i), y: -55)
            }
        }
    }
}

// MARK: - Realistic Unicorn Horn (Spiral like reference!)

struct RealisticUnicornHorn: View {
    let goldLight: Color
    let goldDark: Color
    
    var body: some View {
        ZStack {
            // Main horn cone
            HornShape()
                .fill(
                    LinearGradient(
                        colors: [goldLight, goldDark, goldLight, goldDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 7, height: 25)
            
            // Spiral ridges (like reference!)
            ForEach(0..<6, id: \.self) { i in
                Capsule()
                    .fill(goldLight.opacity(0.9))
                    .frame(width: CGFloat(7 - i), height: 1.5)
                    .offset(y: CGFloat(i * 4) - 10)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
        }
        .rotationEffect(.degrees(-45))
    }
}

// MARK: - Horn Shape

struct HornShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Realistic Unicorn Leg (elegant like reference)

struct RealisticUnicornLeg: View {
    let phase: Bool
    let isBackPair: Bool
    let isRearLeg: Bool
    let bodyColor: Color
    let hoofColor: Color
    
    private var opacity: Double { isBackPair ? 0.75 : 1.0 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Upper leg (thigh)
            Capsule()
                .fill(bodyColor.opacity(opacity))
                .frame(width: 10, height: 18)
            
            // Knee joint
            Ellipse()
                .fill(bodyColor.opacity(opacity))
                .frame(width: 9, height: 8)
                .offset(y: -3)
            
            // Lower leg (cannon bone - thinner)
            Capsule()
                .fill(bodyColor.opacity(opacity))
                .frame(width: 6, height: 16)
                .offset(y: -4)
            
            // Fetlock
            Ellipse()
                .fill(bodyColor.opacity(opacity))
                .frame(width: 7, height: 5)
                .offset(y: -5)
            
            // Hoof (pink!)
            RealisticHoof(color: hoofColor, opacity: opacity)
                .offset(y: -5)
        }
        .rotationEffect(.degrees(phase ? 55 : -50), anchor: .top)
        .offset(x: isRearLeg ? -3 : 3)
    }
}

// MARK: - Realistic Hoof

struct RealisticHoof: View {
    let color: Color
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Hoof shape
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(opacity))
                .frame(width: 11, height: 7)
            
            // Shine
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 2)
                .offset(y: -1)
        }
    }
}

// MARK: - Realistic Unicorn Ear

struct RealisticUnicornEar: View {
    let bodyColor: Color
    let innerColor: Color
    
    var body: some View {
        ZStack {
            // Outer ear (pointed like horse)
            EarShape()
                .fill(bodyColor)
                .frame(width: 7, height: 14)
            
            // Inner ear (pink)
            EarShape()
                .fill(innerColor.opacity(0.6))
                .frame(width: 4, height: 9)
                .offset(y: 1)
        }
        .rotationEffect(.degrees(-30))
    }
}

// MARK: - Ear Shape

struct EarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX + 2, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX - 2, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Realistic Mane (Flowing waves like reference!)

struct RealisticMane: View {
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        ZStack {
            // Multiple wavy strands for realistic flowing mane
            ForEach(0..<8, id: \.self) { i in
                WavyHairStrand(
                    color: i % 2 == 0 ? primaryColor : secondaryColor,
                    length: CGFloat(22 - i * 2),
                    thickness: CGFloat(4 - (i / 3))
                )
                .rotationEffect(.degrees(Double(i) * 8 - 15))
                .offset(y: CGFloat(i * 4))
            }
        }
    }
}

// MARK: - Wavy Hair Strand

struct WavyHairStrand: View {
    let color: Color
    let length: CGFloat
    let thickness: CGFloat
    
    var body: some View {
        WavyPath()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: length, height: thickness + 2)
    }
}

// MARK: - Wavy Path Shape

struct WavyPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        
        let waveHeight = rect.height * 0.3
        let segments = 3
        let segmentWidth = rect.width / CGFloat(segments)
        
        for i in 0..<segments {
            let x1 = CGFloat(i) * segmentWidth + segmentWidth * 0.5
            let x2 = CGFloat(i + 1) * segmentWidth
            let yOffset = i % 2 == 0 ? waveHeight : -waveHeight
            
            path.addQuadCurve(
                to: CGPoint(x: x2, y: rect.midY),
                control: CGPoint(x: x1, y: rect.midY + yOffset)
            )
        }
        
        // Close the path
        path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Realistic Unicorn Tail (Long & Flowing like reference!)

struct RealisticUnicornTail: View {
    let phase: Bool
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        ZStack {
            // Multiple flowing strands for beautiful realistic tail!
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [i % 2 == 0 ? primaryColor : secondaryColor,
                                    (i % 2 == 0 ? primaryColor : secondaryColor).opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: CGFloat(5 - i / 3), height: CGFloat(35 - i * 2))
                    .rotationEffect(.degrees(phase ? -10 + Double(i * 6) : -30 + Double(i * 6)))
                    .offset(x: CGFloat(i * 2), y: CGFloat(i))
            }
        }
        .rotationEffect(.degrees(-20))
    }
}

// MARK: - Moving Clouds ☁️✨

struct MovingClouds: View {
    let isRunning: Bool
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Cloud layer
            HStack(spacing: 20) {
                ForEach(0..<15, id: \.self) { i in
                    CloudPuff(size: CGFloat.random(in: 20...35))
                }
            }
            .offset(x: offset)
        }
        .onAppear {
            if isRunning { startScrolling() }
        }
        .onChange(of: isRunning) { running in
            if running { startScrolling() }
        }
    }
    
    private func startScrolling() {
        offset = 0
        withAnimation(.linear(duration: 0.3).repeatForever(autoreverses: false)) {
            offset = -55
        }
    }
}

// MARK: - Cloud Puff

struct CloudPuff: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Main cloud puff
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size * 0.5)
            
            // Top puff
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.2, y: -size * 0.15)
            
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: size * 0.15, y: -size * 0.1)
        }
    }
}

// MARK: - Moving Ground (Fallback)

struct MovingGround: View {
    let isRunning: Bool
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Ground line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
            
            // Moving dashes
            HStack(spacing: 12) {
                ForEach(0..<30, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 15, height: 2)
                }
            }
            .offset(x: offset)
        }
        .onAppear {
            if isRunning { startScrolling() }
        }
        .onChange(of: isRunning) { running in
            if running { startScrolling() }
        }
    }
    
    private func startScrolling() {
        offset = 0
        withAnimation(.linear(duration: 0.15).repeatForever(autoreverses: false)) {
            offset = -27
        }
    }
}

// MARK: - Speed Trails (Magical sparkle trails! ✨🦄)

struct SpeedTrails: View {
    @State private var visible = false
    
    // Magical colors (pink & gold sparkles!)
    private let trailColors: [Color] = [
        Color(hex: 0xFF1493), // Deep pink
        Color(hex: 0xFFB6C1), // Light pink
        Color(hex: 0xFFD700), // Gold
        Color.white,
    ]
    
    var body: some View {
        ZStack {
            // Sparkle trails
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { j in
                            // Sparkle stars
                            Image(systemName: j % 2 == 0 ? "sparkle" : "star.fill")
                                .font(.system(size: CGFloat(6 - j)))
                                .foregroundColor(trailColors[(i + j) % trailColors.count].opacity(0.8 - Double(j) * 0.15))
                        }
                    }
                    .offset(x: visible ? -70 : 0)
                    .animation(
                        .linear(duration: 0.35)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.06),
                        value: visible
                    )
                }
            }
            
            // Additional flowing trails
            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [trailColors[i % trailColors.count].opacity(0.5), .clear],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .frame(width: 30, height: 2)
                        .offset(x: visible ? -50 : 0)
                        .animation(
                            .linear(duration: 0.3)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.08),
                            value: visible
                        )
                }
            }
            .offset(y: 5)
        }
        .onAppear { visible = true }
    }
}

// MARK: - Compact Indicator (Unicorn themed! 🦄)

struct RunningIndicatorCompact: View {
    let isRunning: Bool
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("🦄")
                .font(.system(size: 14))
                .offset(y: bounce ? -2 : 2)
            
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 6))
                        .foregroundColor(Color(hex: 0xFF69B4)) // Pink sparkles!
                        .scaleEffect(bounce ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.25)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                            value: bounce
                        )
                }
            }
        }
        .onAppear { if isRunning { bounce = true } }
        .onChange(of: isRunning) { bounce = $0 }
    }
}

// MARK: - Fireworks View (For New Year Celebration!)

struct FireworksView: View {
    @State private var bursts: [FireworkBurst] = []
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bursts) { burst in
                    FireworkBurstView(burst: burst)
                }
            }
            .onAppear {
                startFireworks(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func startFireworks(in size: CGSize) {
        // Initial burst
        addBurst(in: size)
        
        // Continuous bursts
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            addBurst(in: size)
            // Clean up old bursts
            bursts.removeAll { Date().timeIntervalSince($0.createdAt) > 2.0 }
        }
    }
    
    private func addBurst(in size: CGSize) {
        let burst = FireworkBurst(
            id: UUID(),
            x: CGFloat.random(in: 30...(size.width - 30)),
            y: CGFloat.random(in: 50...(size.height * 0.6)),
            color: [
                Color(hex: 0xFFD700), // Gold
                Color(hex: 0xFF5500), // Orange
                Color(hex: 0xFF3366), // Pink
                Color(hex: 0x00FF88), // Green
                Color(hex: 0x00CCFF), // Cyan
                Color(hex: 0xFF00FF), // Magenta
                .white
            ].randomElement()!,
            createdAt: Date()
        )
        bursts.append(burst)
    }
}

struct FireworkBurst: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let createdAt: Date
}

struct FireworkBurstView: View {
    let burst: FireworkBurst
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    @State private var particleScale: CGFloat = 0.0
    
    private let particleCount = 12
    
    var body: some View {
        ZStack {
            // Center flash
            Circle()
                .fill(burst.color)
                .frame(width: 8, height: 8)
                .scaleEffect(scale * 2)
                .opacity(opacity)
            
            // Expanding particles
            ForEach(0..<particleCount, id: \.self) { i in
                let angle = (Double(i) / Double(particleCount)) * 2 * .pi
                
                Circle()
                    .fill(burst.color)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: cos(angle) * 50 * particleScale,
                        y: sin(angle) * 50 * particleScale + (particleScale * 20) // gravity
                    )
                    .opacity(opacity)
                
                // Trailing sparkle
                Circle()
                    .fill(burst.color.opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: cos(angle) * 30 * particleScale,
                        y: sin(angle) * 30 * particleScale + (particleScale * 10)
                    )
                    .opacity(opacity * 0.7)
            }
        }
        .position(x: burst.x, y: burst.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 1.2)) {
                particleScale = 1.0
            }
            withAnimation(.easeIn(duration: 1.5).delay(0.3)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Crackers View (Bursting Firecrackers!)

struct CrackersView: View {
    @State private var crackers: [Cracker] = []
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(crackers) { cracker in
                    CrackerBurstView(cracker: cracker)
                }
            }
            .onAppear {
                startCrackers(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func startCrackers(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            let cracker = Cracker(
                id: UUID(),
                x: CGFloat.random(in: 20...(size.width - 20)),
                y: CGFloat.random(in: 20...(size.height - 20)),
                colors: [
                    Color(hex: 0xFFD700),
                    Color(hex: 0xFF5500),
                    Color(hex: 0xFF3366)
                ].shuffled(),
                createdAt: Date()
            )
            crackers.append(cracker)
            
            // Cleanup
            crackers.removeAll { Date().timeIntervalSince($0.createdAt) > 1.5 }
        }
    }
}

struct Cracker: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let colors: [Color]
    let createdAt: Date
}

struct CrackerBurstView: View {
    let cracker: Cracker
    @State private var exploded = false
    
    var body: some View {
        ZStack {
            // Sparks flying in all directions
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                
                SparkLine(color: cracker.colors[i % cracker.colors.count])
                    .rotationEffect(.radians(angle))
                    .offset(
                        x: exploded ? cos(angle) * 25 : 0,
                        y: exploded ? sin(angle) * 25 : 0
                    )
                    .opacity(exploded ? 0 : 1)
            }
        }
        .position(x: cracker.x, y: cracker.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                exploded = true
            }
        }
    }
}

struct SparkLine: View {
    let color: Color
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 12, height: 3)
    }
}

// MARK: - 🎉 CELEBRATION OVERLAY (Full Screen!)

struct CelebrationOverlay: View {
    @Binding var isShowing: Bool
    
    @State private var textScale: CGFloat = 0.1
    @State private var textOpacity: Double = 0
    @State private var runAnywhereScale: CGFloat = 0.5
    @State private var runAnywhereOpacity: Double = 0
    @State private var yearOpacity: Double = 0
    @State private var showMassiveFireworks = false
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            // MASSIVE FIREWORKS!
            if showMassiveFireworks {
                MassiveFireworksView()
                    .ignoresSafeArea()
            }
            
            // Center content
            VStack(spacing: 30) {
                // "from" text
                Text("from")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(textScale)
                    .opacity(textOpacity)
                
                // RUNANYWHERE - Giant!
                Text("RunAnywhere")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: 0xFF5500),
                                Color(hex: 0xFFD700),
                                Color(hex: 0xFF5500)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: 0xFF5500).opacity(0.5), radius: 20)
                    .scaleEffect(runAnywhereScale)
                    .opacity(runAnywhereOpacity)
                
                // Year badge
                Text("🎆 2026 🎇")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xFFD700), .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(yearOpacity)
                
                // Tagline
                Text("AI that runs anywhere!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(yearOpacity)
            }
            
            // Tap to dismiss hint
            VStack {
                Spacer()
                Text("Tap anywhere to continue")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 50)
                    .opacity(yearOpacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                isShowing = false
            }
        }
        .onAppear {
            startCelebration()
        }
    }
    
    private func startCelebration() {
        // 🎺 Play celebration fanfare ONCE at the start!
        playFireworkSound()
        
        // Sequence the animations for dramatic effect
        
        // 1. Show "from" text
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            textScale = 1.0
            textOpacity = 1.0
        }
        
        // 2. Show RunAnywhere with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                runAnywhereScale = 1.0
                runAnywhereOpacity = 1.0
            }
            
            // Trigger massive fireworks!
            showMassiveFireworks = true
        }
        
        // 3. Show year and tagline
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) {
                yearOpacity = 1.0
            }
        }
        
        // 4. Auto dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                isShowing = false
            }
        }
    }
    
    /// Play a firework/celebration effect with sound!
    private func playFireworkSound() {
        #if os(iOS)
        // Heavy haptic for the "boom" feeling
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        #endif
        
        // Play celebratory sound
        CelebrationSoundManager.shared.playPopSound()
    }
}

// MARK: - Celebration Sound Manager

/// Sound manager that plays the real fireworks MP3 sound!
class CelebrationSoundManager {
    static let shared = CelebrationSoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        #endif
    }
    
    /// Play the fireworks sound from trimmed MP3 file (0:02 to 0:04 = 2 seconds)
    func playPopSound() {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: "fireworks", withExtension: "mp3") else {
            print("Fireworks sound file not found, using fallback")
            playFallbackSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play fireworks sound: \(error)")
            playFallbackSound()
        }
    }
    
    /// Fallback sound if MP3 not available
    private func playFallbackSound() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

// MARK: - Massive Fireworks (For Celebration!)

struct MassiveFireworksView: View {
    @State private var bursts: [CelebrationBurst] = []
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bursts) { burst in
                    CelebrationBurstView(burst: burst, screenSize: geometry.size)
                }
            }
            .onAppear {
                startMassiveFireworks(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func startMassiveFireworks(in size: CGSize) {
        // Initial burst of 5 fireworks
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                addBurst(in: size)
            }
        }
        
        // Continuous bursts
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            addBurst(in: size)
            // Clean up old bursts
            bursts.removeAll { Date().timeIntervalSince($0.createdAt) > 2.5 }
        }
    }
    
    private func addBurst(in size: CGSize) {
        let burst = CelebrationBurst(
            id: UUID(),
            x: CGFloat.random(in: 40...(size.width - 40)),
            y: CGFloat.random(in: 80...(size.height * 0.7)),
            color: [
                Color(hex: 0xFFD700), // Gold
                Color(hex: 0xFF5500), // Orange
                Color(hex: 0xFF3366), // Pink
                Color(hex: 0x00FF88), // Green
                Color(hex: 0x00CCFF), // Cyan
                Color(hex: 0xFF00FF), // Magenta
                Color(hex: 0xFFFFFF), // White
                Color(hex: 0xFF0000), // Red
            ].randomElement()!,
            size: CGFloat.random(in: 60...100),
            createdAt: Date()
        )
        bursts.append(burst)
    }
}

struct CelebrationBurst: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let createdAt: Date
}

struct CelebrationBurstView: View {
    let burst: CelebrationBurst
    let screenSize: CGSize
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    @State private var particleScale: CGFloat = 0.0
    
    private let particleCount = 16
    
    var body: some View {
        ZStack {
            // Center flash - bigger!
            Circle()
                .fill(burst.color)
                .frame(width: 12, height: 12)
                .scaleEffect(scale * 3)
                .opacity(opacity)
                .blur(radius: 2)
            
            // Expanding particles - more!
            ForEach(0..<particleCount, id: \.self) { i in
                let angle = (Double(i) / Double(particleCount)) * 2 * .pi
                let distance = burst.size * particleScale
                
                // Main particle
                Circle()
                    .fill(burst.color)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance + (particleScale * 30)
                    )
                    .opacity(opacity)
                
                // Secondary particle
                Circle()
                    .fill(burst.color.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .offset(
                        x: cos(angle) * distance * 0.6,
                        y: sin(angle) * distance * 0.6 + (particleScale * 15)
                    )
                    .opacity(opacity * 0.8)
                
                // Sparkle trail
                Circle()
                    .fill(.white)
                    .frame(width: 3, height: 3)
                    .offset(
                        x: cos(angle) * distance * 0.3,
                        y: sin(angle) * distance * 0.3 + (particleScale * 5)
                    )
                    .opacity(opacity * 0.5)
            }
        }
        .position(x: burst.x, y: burst.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 1.5)) {
                particleScale = 1.0
            }
            withAnimation(.easeIn(duration: 2.0).delay(0.3)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Preview

struct RunningAthleteView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Sky gradient background
            LinearGradient(
                colors: [
                    Color(hex: 0x1a1a2e),
                    Color(hex: 0x16213e),
                    Color(hex: 0x0f3460)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("🦄 Magical Unicorn! ✨")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("Happy New Year 2026!")
                    .font(.headline)
                    .foregroundColor(Color(hex: 0xFF1493))
                
                RunningAthleteView(isRunning: true, showNewYearTheme: true)
                    .frame(height: 160)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x111122), Color(hex: 0x1a1a2e)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                
                RunningIndicatorCompact(isRunning: true)
            }
            .padding()
        }
    }
}
