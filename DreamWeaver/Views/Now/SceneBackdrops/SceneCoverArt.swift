import SwiftUI
import UIKit

/// Shared loader for scene cover / full-bleed backdrop art.
/// Prefers `Resources/Scenes/...` drop-zone files, then Asset Catalog names.
enum SceneCoverArt {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for style: SceneVisualStyle) -> UIImage? {
        let key = style.rawValue as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let resource = resource(for: style) else { return nil }
        let loaded =
            loadFromBundle(file: resource.file, subdirectory: resource.subdirectory)
            ?? UIImage(named: resource.catalogName)
        if let loaded {
            cache.setObject(loaded, forKey: key)
        }
        return loaded
    }

    /// Decode into memory ahead of a swipe so the next backdrop paints immediately.
    static func preload(for style: SceneVisualStyle) {
        _ = image(for: style)
    }

    static func hasCover(for style: SceneVisualStyle) -> Bool {
        image(for: style) != nil
    }

    private static func resource(
        for style: SceneVisualStyle
    ) -> (catalogName: String, subdirectory: String, file: String)? {
        switch style {
        case .mistTide:
            // Unique filename — Copy Bundle Resources flattens paths; cannot share `bg.jpg` with RainEaves.
            return ("mist_tide_bg", "Scenes/MistTide", "mist_tide_bg.jpg")
        case .valleyStream:
            return ("valley_stream_bg", "Scenes/ValleyStream", "valley_stream_bg.jpg")
        case .snowStudy:
            return ("snow_study_bg", "Scenes/SnowStudy", "snow_study_bg.png")
        case .flight:
            return ("flight_bg", "Scenes/Flight", "flight_bg.jpg")
        case .emotionalFluid:
            return ("emotional_fluid_bg", "Scenes/EmotionalFluid", "emotional_fluid_bg.png")
        case .hairCare:
            return ("hair_care_bg", "Scenes/HairCare", "hair_care_bg.png")
        case .himalaya:
            return ("himalaya_bg", "Scenes/Himalaya", "himalaya_bg.jpg")
        case .starRiver:
            return ("star_river_bg", "Scenes/StarRiver", "star_river_bg.jpg")
        case .wheatWave:
            return ("wheat_wave_bg", "Scenes/WheatWave", "wheat_wave_bg.jpg")
        case .moonLake:
            return ("moon_lake_bg", "Scenes/MoonLake", "moon_lake_bg.png")
        case .longRoad:
            return ("long_road_bg", "Scenes/LongRoad", "long_road_bg.jpg")
        case .fireplaceWhisper:
            return ("fireplace_whisper_bg", "Scenes/FireplaceWhisper", "fireplace_whisper_bg.jpg")
        case .summerNight:
            return ("summer_night_bg", "Scenes/SummerNight", "summer_night_bg.jpg")
        case .rainEaves:
            return ("rain_eaves_bg", "Scenes/RainEaves", "bg.jpg")
        default:
            return nil
        }
    }

    private static func loadFromBundle(file: String, subdirectory: String) -> UIImage? {
        let ns = file as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension.isEmpty ? nil : ns.pathExtension
        let candidates: [String?] = [
            subdirectory,
            "Resources/\(subdirectory)",
            nil
        ]
        for sub in candidates {
            if let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: sub),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}
