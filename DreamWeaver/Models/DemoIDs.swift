import Foundation

/// Stable UUIDs for demo fixtures. Never regenerate at runtime.
enum DemoIDs {
    static let schemaVersion = 1

    static let hairCareScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111101")!
    static let rainEavesScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111102")!
    static let firefliesScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111103")!
    static let mistTideScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111104")!
    static let valleyStreamScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111105")!
    static let moonLakeScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111106")!
    static let starRiverScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111107")!
    static let warmLampScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111108")!
    static let snowStudyScene = UUID(uuidString: "A1111111-1111-4111-8111-111111111109")!
    static let wheatWindScene = UUID(uuidString: "A1111111-1111-4111-8111-11111111110A")!
    static let cloudBreathScene = UUID(uuidString: "A1111111-1111-4111-8111-11111111110B")!
    static let summerInsectsScene = UUID(uuidString: "A1111111-1111-4111-8111-11111111110C")!
    static let fireplaceScene = UUID(uuidString: "A1111111-1111-4111-8111-11111111110D")!
    static let emotionalFluidScene = UUID(uuidString: "A1111111-1111-4111-8111-11111111110E")!

    static let seedMom = UUID(uuidString: "B2222222-2222-4222-8222-222222222201")!
    static let seedFriend = UUID(uuidString: "B2222222-2222-4222-8222-222222222202")!
    static let seedPartner = UUID(uuidString: "B2222222-2222-4222-8222-222222222203")!
    static let recordingRain = UUID(uuidString: "B2222222-2222-4222-8222-222222222204")!
    static let recordingStudy = UUID(uuidString: "B2222222-2222-4222-8222-222222222205")!
    static let communityBreath = UUID(uuidString: "B2222222-2222-4222-8222-222222222206")!
    static let communityRain = UUID(uuidString: "B2222222-2222-4222-8222-222222222207")!
    static let communityTide = UUID(uuidString: "B2222222-2222-4222-8222-222222222208")!
    static let communityInsects = UUID(uuidString: "B2222222-2222-4222-8222-222222222209")!
    static let communityPiano = UUID(uuidString: "B2222222-2222-4222-8222-22222222220A")!
    static let communityFire = UUID(uuidString: "B2222222-2222-4222-8222-22222222220B")!
    static let communityStream = UUID(uuidString: "B2222222-2222-4222-8222-22222222220C")!

    static let usageRecord = UUID(uuidString: "C3333333-3333-4333-8333-333333333301")!

    static let presetRainFine = UUID(uuidString: "D4444444-4444-4444-8444-444444444401")!
    static let presetForestGlow = UUID(uuidString: "D4444444-4444-4444-8444-444444444402")!
    static let presetMistTide = UUID(uuidString: "D4444444-4444-4444-8444-444444444403")!
    static let presetFireplace = UUID(uuidString: "D4444444-4444-4444-8444-444444444404")!
    static let presetStarRiver = UUID(uuidString: "D4444444-4444-4444-8444-444444444405")!
    static let presetBreathOnly = UUID(uuidString: "D4444444-4444-4444-8444-444444444406")!
    static let presetHairCare = UUID(uuidString: "D4444444-4444-4444-8444-444444444407")!

    static let sourceRain = UUID(uuidString: "E5555555-5555-4555-8555-555555555501")!
    static let sourceWind = UUID(uuidString: "E5555555-5555-4555-8555-555555555502")!
    static let sourceVoice = UUID(uuidString: "E5555555-5555-4555-8555-555555555503")!
    static let sourceHairWash = UUID(uuidString: "E5555555-5555-4555-8555-555555555504")!
    static let sourceHairDryer = UUID(uuidString: "E5555555-5555-4555-8555-555555555505")!
    static let sourceAC = UUID(uuidString: "E5555555-5555-4555-8555-555555555506")!
    static let sourcePiano = UUID(uuidString: "E5555555-5555-4555-8555-555555555507")!

    // Hair-care script v4 (洗头场景时间戳协同表)
    static let sourceHairWaterCycle = UUID(uuidString: "E5555555-5555-4555-8555-555555555508")!
    static let sourceHairWet = UUID(uuidString: "E5555555-5555-4555-8555-555555555509")!
    static let sourceHairFoamStart = UUID(uuidString: "E5555555-5555-4555-8555-55555555550A")!
    static let sourceHairFoamRub = UUID(uuidString: "E5555555-5555-4555-8555-55555555550B")!
    static let sourceHairScalpFoam = UUID(uuidString: "E5555555-5555-4555-8555-55555555550C")!
    static let sourceHairRinse = UUID(uuidString: "E5555555-5555-4555-8555-55555555550D")!
    static let sourceHairFingerMassage = UUID(uuidString: "E5555555-5555-4555-8555-55555555550E")!
    static let sourceHairTowel = UUID(uuidString: "E5555555-5555-4555-8555-55555555550F")!

    // Rain eaves extras (must not collide with hair-care 508–50F)
    static let sourceRainSoftFar = UUID(uuidString: "E5555555-5555-4555-8555-555555555510")!
    static let sourceRainEavesVoice = UUID(uuidString: "E5555555-5555-4555-8555-555555555511")!
    static let sourceRainBambooLeaf = UUID(uuidString: "E5555555-5555-4555-8555-555555555512")!
}
