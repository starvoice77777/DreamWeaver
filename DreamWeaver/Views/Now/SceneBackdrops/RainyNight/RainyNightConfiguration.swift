import CoreGraphics
import Foundation
import UIKit

/// Asset + design-space parameters for the rainy-night 5-layer stack.
struct RainyNightConfiguration: Equatable {
    /// Logical authoring size for the art stack (should match bg/mask aspect).
    /// Original spec was 360×640; current RainEaves art is 852×1846.
    var designSize: CGSize

    /// Asset Catalog image names.
    var backgroundCatalogName: String
    var rainMaskCatalogName: String
    var lampMaskCatalogName: String

    /// Bundle subdirectory under Resources (artist drop zone).
    var resourceSubdirectory: String
    /// Filenames inside `resourceSubdirectory`.
    var backgroundFileName: String
    var rainMaskFileName: String
    var lampMaskFileName: String

    /// Lamp center in `designSize` coordinates.
    var lampDesignPoint: CGPoint

    var dropletCount: Int
    var baseLampRadius: CGFloat

    /// Spec design space used to author lamp/rain before art export.
    static let specDesignSize = CGSize(width: 360, height: 640)
    static let specLampPoint = CGPoint(x: 282, y: 504)

    static let rainEaves = RainyNightConfiguration(
        // Matches current `Resources/Scenes/RainEaves` export.
        designSize: CGSize(width: 852, height: 1846),
        backgroundCatalogName: "rain_eaves_bg",
        rainMaskCatalogName: "rain_eaves_mask",
        lampMaskCatalogName: "rain_eaves_mask_lamp",
        resourceSubdirectory: "Scenes/RainEaves",
        backgroundFileName: "bg.jpg",
        rainMaskFileName: "mask.png",
        lampMaskFileName: "mask_lamp_opacity.png",
        lampDesignPoint: scaledPoint(specLampPoint, from: specDesignSize, to: CGSize(width: 852, height: 1846)),
        dropletCount: 135,
        // Scale 100pt @360 width → current art width.
        baseLampRadius: 100 * (852 / 360)
    )

    private static func scaledPoint(_ point: CGPoint, from: CGSize, to: CGSize) -> CGPoint {
        CGPoint(x: point.x * to.width / from.width, y: point.y * to.height / from.height)
    }

    func loadBackground() -> UIImage? {
        Self.loadImage(catalog: backgroundCatalogName, file: backgroundFileName, subdirectory: resourceSubdirectory)
    }

    func loadRainMask() -> UIImage? {
        Self.loadImage(catalog: rainMaskCatalogName, file: rainMaskFileName, subdirectory: resourceSubdirectory)
    }

    func loadLampMask() -> UIImage? {
        Self.loadImage(catalog: lampMaskCatalogName, file: lampMaskFileName, subdirectory: resourceSubdirectory)
    }

    private static func loadImage(catalog: String, file: String, subdirectory: String) -> UIImage? {
        // Prefer Resources drop-zone files so replacing art under
        // `Resources/Scenes/...` shows up without fighting stale Assets.car entries.
        if let image = loadFromBundle(file: file, subdirectory: subdirectory) {
            return image
        }
        if let image = UIImage(named: catalog) {
            return image
        }
        // Last resort: catalog file basename (e.g. "bg") if someone renamed imagesets.
        let ns = file as NSString
        if let image = UIImage(named: ns.deletingPathExtension) {
            return image
        }
        return nil
    }

    private static func loadFromBundle(file: String, subdirectory: String) -> UIImage? {
        let ns = file as NSString
        let name = ns.deletingPathExtension
        let ext = ns.pathExtension
        let candidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/\(subdirectory)"),
            Bundle.main.url(forResource: name, withExtension: ext),
            Bundle.main.resourceURL?
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(file),
            Bundle.main.resourceURL?
                .appendingPathComponent("Scenes")
                .appendingPathComponent("RainEaves")
                .appendingPathComponent(file)
        ]
        for url in candidates {
            guard let url, FileManager.default.fileExists(atPath: url.path) else { continue }
            if let image = UIImage(contentsOfFile: url.path) { return image }
        }
        return nil
    }
}

/// Maps design space ↔ view bounds with Aspect Fill + centered crop.
enum RainyNightLayout {
    static func aspectFillScale(design: CGSize, bounds: CGSize) -> CGFloat {
        guard design.width > 0, design.height > 0 else { return 1 }
        return max(bounds.width / design.width, bounds.height / design.height)
    }

    static func designToView(_ point: CGPoint, design: CGSize, bounds: CGRect) -> CGPoint {
        let scale = aspectFillScale(design: design, bounds: bounds.size)
        let ox = (bounds.width - design.width * scale) * 0.5
        let oy = (bounds.height - design.height * scale) * 0.5
        return CGPoint(x: ox + point.x * scale, y: oy + point.y * scale)
    }
}
