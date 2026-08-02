import Combine
import Foundation
import SwiftUI

/// Time-driven palette / mode cycling with seamless cross-dissolves (no hard cuts).
@MainActor
final class ColorPaletteManager: ObservableObject {
    /// Published for audio hooks / debugging; render path should prefer `sample(at:)`.
    @Published private(set) var sceneType: FluidSceneType
    @Published private(set) var dissolveProgress: Double = 0

    /// One palette occupies this many seconds of gradual blend into the next.
    let paletteInterval: TimeInterval

    /// Morph phase period for organic motion (independent of palette cycle).
    let morphPeriod: TimeInterval

    private var sessionOrigin: Date
    private let sequence: [Slot]

    struct Slot: Hashable {
        let sceneType: FluidSceneType
        let palette: FluidColorPalette
    }

    /// Continuous sample — blend is a pure function of time, so wraps never jump.
    struct Sample {
        let sceneType: FluidSceneType
        let nextSceneType: FluidSceneType
        /// 0 = fully current mode draw, 1 = fully next mode draw.
        let modeMix: Double
        let palette: FluidColorPalette
        let morphPhase: Double
    }

    init(
        sceneType: FluidSceneType = .cloud,
        paletteInterval: TimeInterval = 30,
        morphPeriod: TimeInterval = 22
    ) {
        self.sceneType = sceneType
        self.paletteInterval = paletteInterval
        self.morphPeriod = morphPeriod
        self.sessionOrigin = Date()
        self.sequence = Self.buildSequence()
    }

    func sample(at now: Date) -> Sample {
        let elapsed = max(0, now.timeIntervalSince(sessionOrigin))
        let count = max(sequence.count, 1)
        let slotFloat = elapsed / paletteInterval
        let index = Int(floor(slotFloat)) % count
        let nextIndex = (index + 1) % count
        // 0…1 within the current 30s window
        var local = slotFloat - floor(slotFloat)
        if local < 0 { local += 1 }
        // Smoothstep keeps endpoints flat → derivative ~0 at commit → no pop.
        let blend = Self.smoothstep(local)

        let current = sequence[index]
        let upcoming = sequence[nextIndex]
        let mixed = current.palette.blended(toward: upcoming.palette, amount: blend)

        // Mode mix only when the visual algorithm changes; still continuous.
        let modeMix: Double
        if current.sceneType == upcoming.sceneType {
            modeMix = 0
        } else {
            modeMix = blend
        }

        let morph = (elapsed / morphPeriod).truncatingRemainder(dividingBy: 1)

        // Keep published mirrors in sync at low frequency via tick().
        return Sample(
            sceneType: current.sceneType,
            nextSceneType: upcoming.sceneType,
            modeMix: modeMix,
            palette: mixed,
            morphPhase: morph < 0 ? morph + 1 : morph
        )
    }

    /// Optional low-rate publish for audio manager; safe to call ~1 Hz.
    func tick(now: Date, active: Bool) {
        guard active else { return }
        let s = sample(at: now)
        if s.sceneType != sceneType {
            sceneType = s.sceneType
        }
        dissolveProgress = {
            let elapsed = max(0, now.timeIntervalSince(sessionOrigin))
            var local = (elapsed / paletteInterval).truncatingRemainder(dividingBy: 1)
            if local < 0 { local += 1 }
            return Self.smoothstep(local)
        }()
    }

    func setSceneType(_ type: FluidSceneType) {
        // Re-anchor timeline so the next slot starts on the requested mode
        // without a color hard-cut: pick the first matching slot and set origin
        // so local blend ≈ 0 at that slot.
        guard let idx = sequence.firstIndex(where: { $0.sceneType == type }) else { return }
        sceneType = type
        sessionOrigin = Date().addingTimeInterval(-Double(idx) * paletteInterval)
        dissolveProgress = 0
    }

    private static func buildSequence() -> [Slot] {
        var slots: [Slot] = []
        for type in FluidSceneType.allCases {
            for palette in FluidColorPalette.palettes(for: type) {
                slots.append(Slot(sceneType: type, palette: palette))
            }
        }
        return slots
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }
}
