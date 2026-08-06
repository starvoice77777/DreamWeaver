import Foundation

/// Fixture factory for offline demo. Prefer fixed IDs so persistence survives relaunches.
enum MockDataService {
    static let greetings = [
        "晚上好，今天辛苦了。",
        "今晚，也给自己一点安静。",
        "夜已经慢下来了。",
        "准备好进入今晚的梦境了吗？",
        "今晚，为你留了一片安静。"
    ]

    static let frequentSceneLimit = 6

    static func makeScenes() -> [DreamScene] {
        markTopFrequentScenes([
            hairCareScene(),
            rainEavesScene(),
            scene(
                id: DemoIDs.firefliesScene,
                name: "深林萤火",
                subtitle: "风穿过树梢，微光停在夜色里。",
                description: "林间微风与零星萤火交织，把呼吸带回更慢的节奏。",
                category: .forest,
                tags: ["森林", "微光"],
                palette: ScenePalette(top: 0x0B1A14, mid: 0x1A3A2E, bottom: 0x0A1520, accent: 0xE0A868),
                style: .fireflies,
                favorite: true,
                listens: 41,
                listeners: 964,
                sources: [
                    source("风声", "wind", angle: .pi * 0.15, radius: 0.7),
                    source("虫鸣", "leaf.fill", angle: .pi * 0.7, radius: 0.55, initialEnvelope: 0.5),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.4, radius: 0.4, initialEnvelope: 0.4, layer: .voice),
                    source("雨声", "cloud.rain.fill", angle: .pi * 1.1, radius: 0.75, initialEnvelope: 0.2, enabled: false),
                    source("钢琴", "pianokeys", angle: .pi * 1.4, radius: 0.6, initialEnvelope: 0.25)
                ]
            ),
            scene(
                id: DemoIDs.mistTideScene,
                name: "雾岸听潮",
                subtitle: "潮声从雾的另一边缓缓靠近。",
                description: "远岸潮水起伏，雾气把世界推远一点，只留下规律的海声。",
                category: .ocean,
                tags: ["海洋", "雾"],
                palette: ScenePalette(top: 0x1B2736, mid: 0x4A5C6E, bottom: 0x15202C, accent: 0xE8B070),
                style: .mistTide,
                favorite: false,
                listens: 36,
                listeners: 742,
                sources: [
                    source("潮声", "water.waves", angle: .pi * 0.9, radius: 0.65, initialEnvelope: 0.8),
                    source("风声", "wind", angle: .pi * 0.25, radius: 0.7, initialEnvelope: 0.4),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.3, radius: 0.45, initialEnvelope: 0.35, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 1.3, radius: 0.55, initialEnvelope: 0.2, enabled: false),
                    source("雨声", "cloud.rain.fill", angle: .pi * 0.5, radius: 0.78, initialEnvelope: 0.15, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.valleyStreamScene,
                name: "幽谷清流",
                subtitle: "水声沿着石缝，轻轻绕过心口。",
                description: "山谷溪流清亮而连续，适合需要被轻轻带着走的夜晚。",
                category: .nature,
                tags: ["流水", "山谷"],
                palette: ScenePalette(top: 0x13241F, mid: 0x1F3D38, bottom: 0x101820, accent: 0x7FB8A8),
                style: .valleyStream,
                favorite: false,
                listens: 12,
                listeners: 531,
                sources: [
                    source("流水", "drop.fill", angle: .pi * 0.8, radius: 0.5, initialEnvelope: 0.75, resourceName: "stream_nature"),
                    source("风声", "wind", angle: .pi * 0.2, radius: 0.7, initialEnvelope: 0.3),
                    source("鸟鸣", "bird.fill", angle: -.pi * 0.5, radius: 0.6, initialEnvelope: 0.2, enabled: false),
                    source("人声", "person.wave.2.fill", angle: .pi * 1.35, radius: 0.42, initialEnvelope: 0.35, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 0.45, radius: 0.72, initialEnvelope: 0.22)
                ]
            ),
            scene(
                id: DemoIDs.moonLakeScene,
                name: "月夜静湖",
                subtitle: "月光落在水面，夜色变得很薄。",
                description: "静湖倒映月光，几乎没有多余的声音，只留下一层柔和的回响。",
                category: .nature,
                tags: ["月光", "湖"],
                palette: ScenePalette(top: 0x10182A, mid: 0x243552, bottom: 0x0C1018, accent: 0xE0B878),
                style: .moonLake,
                favorite: true,
                listens: 18,
                listeners: 1102,
                sources: [
                    source("湖面", "water.waves", angle: .pi * 0.95, radius: 0.58, initialEnvelope: 0.45, resourceName: "stream_nature"),
                    source("风声", "wind", angle: .pi * 0.18, radius: 0.68, initialEnvelope: 0.25),
                    source("钢琴", "pianokeys", angle: -.pi * 0.25, radius: 0.5, initialEnvelope: 0.4),
                    source("人声", "person.wave.2.fill", angle: .pi * 1.4, radius: 0.4, initialEnvelope: 0.3, layer: .voice),
                    source("虫鸣", "leaf.fill", angle: .pi * 0.55, radius: 0.8, initialEnvelope: 0.15, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.starRiverScene,
                name: "星河远眠",
                subtitle: "把目光交给很远的光。",
                description: "星河缓慢流动，像把白天的嘈杂一点点推到天边。",
                category: .lightMusic,
                tags: ["星空", "空灵"],
                palette: ScenePalette(top: 0x090B18, mid: 0x1A1F3A, bottom: 0x0A0C16, accent: 0xE0A878),
                style: .starRiver,
                favorite: false,
                listens: 44,
                listeners: 1588,
                sources: [
                    source("星声", "sparkles", angle: .pi * 0.6, radius: 0.75, initialEnvelope: 0.35),
                    source("钢琴", "pianokeys", angle: -.pi * 0.2, radius: 0.48, initialEnvelope: 0.55),
                    source("人声", "person.wave.2.fill", angle: .pi * 1.2, radius: 0.42, initialEnvelope: 0.35, layer: .voice),
                    source("风声", "wind", angle: .pi * 0.15, radius: 0.7, initialEnvelope: 0.2),
                    source("虫鸣", "leaf.fill", angle: .pi * 0.9, radius: 0.8, initialEnvelope: 0.12, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.warmLampScene,
                name: "暖灯陪伴",
                subtitle: "房间不大，灯光刚刚好。",
                description: "一盏暖灯、轻微人声与柔和钢琴，像有人静静坐在旁边。",
                category: .companion,
                tags: ["陪伴", "暖光"],
                palette: ScenePalette(top: 0x2A1E16, mid: 0x4A3424, bottom: 0x18120E, accent: 0xE0A878),
                style: .warmLamp,
                favorite: true,
                listens: 52,
                listeners: 2031,
                sources: [
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.15, radius: 0.35, initialEnvelope: 0.55, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 0.85, radius: 0.55, initialEnvelope: 0.4),
                    source("雨声", "cloud.rain.fill", angle: .pi * 0.3, radius: 0.72, initialEnvelope: 0.25),
                    source("风声", "wind", angle: .pi * 1.3, radius: 0.7, initialEnvelope: 0.15, enabled: false),
                    source("炉火", "flame.fill", angle: .pi * 0.55, radius: 0.48, initialEnvelope: 0.3)
                ]
            ),
            scene(
                id: DemoIDs.snowStudyScene,
                name: "雪夜书房",
                subtitle: "窗外落雪，纸页很静。",
                description: "雪夜把世界盖软，书房里只剩细小的翻页与远处风声。",
                category: .whisper,
                tags: ["雪夜", "安静"],
                palette: ScenePalette(top: 0x1A2230, mid: 0x3A4658, bottom: 0x12161E, accent: 0xD8DEE8),
                style: .snowStudy,
                favorite: false,
                listens: 9,
                listeners: 687,
                sources: [
                    source("雪声", "snowflake", angle: .pi * 0.7, radius: 0.65, initialEnvelope: 0.5),
                    source("风声", "wind", angle: .pi * 0.2, radius: 0.75, initialEnvelope: 0.3),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.35, radius: 0.4, initialEnvelope: 0.35, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 1.25, radius: 0.52, initialEnvelope: 0.28),
                    source("翻页", "book.closed.fill", angle: .pi * 0.45, radius: 0.38, initialEnvelope: 0.2)
                ]
            ),
            scene(
                id: DemoIDs.wheatWindScene,
                name: "风过麦田",
                subtitle: "风把白天的热气带走了。",
                description: "麦浪轻轻起伏，风声开阔而不喧闹，适合想要一点空间感的夜晚。",
                category: .nature,
                tags: ["田野", "风"],
                palette: ScenePalette(top: 0x2A2214, mid: 0x6A5430, bottom: 0x1A1610, accent: 0xE8B070),
                style: .wheatWind,
                favorite: false,
                listens: 7,
                listeners: 412,
                sources: [
                    source("风声", "wind", angle: .pi * 0.25, radius: 0.6, initialEnvelope: 0.7),
                    source("虫鸣", "leaf.fill", angle: .pi * 0.8, radius: 0.55, initialEnvelope: 0.4),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.4, radius: 0.42, initialEnvelope: 0.3, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 1.35, radius: 0.58, initialEnvelope: 0.22, enabled: false),
                    source("雨声", "cloud.rain.fill", angle: .pi * 0.55, radius: 0.78, initialEnvelope: 0.15, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.cloudBreathScene,
                name: "云间呼吸",
                subtitle: "跟着云层一起慢慢呼气。",
                description: "柔和的呼吸引导与轻薄氛围声，帮助身体一点点松下来。",
                category: .breath,
                tags: ["呼吸", "放松"],
                palette: ScenePalette(top: 0x182030, mid: 0x2E3C52, bottom: 0x10161E, accent: 0xA8B8D0),
                style: .cloudBreath,
                favorite: false,
                listens: 33,
                listeners: 895,
                sources: [
                    source("呼吸", "wind.circle.fill", angle: -.pi * 0.1, radius: 0.35, initialEnvelope: 0.65),
                    source("人声", "person.wave.2.fill", angle: .pi * 0.9, radius: 0.45, initialEnvelope: 0.45, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 0.35, radius: 0.62, initialEnvelope: 0.3),
                    source("风声", "wind", angle: .pi * 1.3, radius: 0.72, initialEnvelope: 0.25),
                    source("潮声", "water.waves", angle: .pi * 0.65, radius: 0.8, initialEnvelope: 0.18, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.summerInsectsScene,
                name: "夏夜虫鸣",
                subtitle: "院子里，夏天还没走远。",
                description: "虫鸣层层叠叠，像夏天的夜还停在窗外，温柔而不打扰。",
                category: .nature,
                tags: ["夏夜", "虫鸣"],
                palette: ScenePalette(top: 0x142018, mid: 0x243828, bottom: 0x101410, accent: 0x88C878),
                style: .summerInsects,
                favorite: false,
                listens: 11,
                listeners: 623,
                sources: [
                    source("虫鸣", "leaf.fill", angle: .pi * 0.6, radius: 0.55, initialEnvelope: 0.7),
                    source("风声", "wind", angle: .pi * 0.15, radius: 0.7, initialEnvelope: 0.3),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.35, radius: 0.42, initialEnvelope: 0.35, layer: .voice),
                    source("雨声", "cloud.rain.fill", angle: .pi * 1.1, radius: 0.75, initialEnvelope: 0.2, enabled: false),
                    source("钢琴", "pianokeys", angle: .pi * 1.4, radius: 0.58, initialEnvelope: 0.2)
                ]
            ),
            scene(
                id: DemoIDs.fireplaceScene,
                name: "炉边低语",
                subtitle: "火光轻轻说着不重要的事。",
                description: "炉火细碎作响，低语与暖色把夜晚收得很近。",
                category: .companion,
                tags: ["炉火", "低语"],
                palette: ScenePalette(top: 0x241810, mid: 0x4A2C1A, bottom: 0x140E0A, accent: 0xE09060),
                style: .fireplaceWhisper,
                favorite: true,
                listens: 15,
                listeners: 1344,
                sources: [
                    source("炉火", "flame.fill", angle: .pi * 0.55, radius: 0.4, initialEnvelope: 0.65),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.25, radius: 0.38, initialEnvelope: 0.5, layer: .voice),
                    source("雨声", "cloud.rain.fill", angle: .pi * 0.95, radius: 0.72, initialEnvelope: 0.3),
                    source("钢琴", "pianokeys", angle: .pi * 0.2, radius: 0.6, initialEnvelope: 0.25),
                    source("风声", "wind", angle: .pi * 1.35, radius: 0.75, initialEnvelope: 0.18, enabled: false)
                ]
            ),
            scene(
                id: DemoIDs.emotionalFluidScene,
                name: "流光溢彩",
                subtitle: "颜色在呼吸，像一团安静的情绪。",
                description: "缓慢流动的情绪色彩空间。云雾、水波与暖焰轮转，没有文字打扰，只留下疗愈般的光色。",
                category: .lightMusic,
                tags: ["色彩", "助眠", "氛围"],
                palette: ScenePalette(top: 0x24324A, mid: 0x4B4668, bottom: 0x163A4A, accent: 0xE8DCC5),
                style: .emotionalFluid,
                favorite: true,
                listens: 8,
                listeners: 426,
                sources: [
                    source("风声", "wind", angle: .pi * 0.2, radius: 0.68, initialEnvelope: 0.35, resourceName: "wind_realistic"),
                    source("雨声", "cloud.rain.fill", angle: .pi * 0.9, radius: 0.55, initialEnvelope: 0.4, resourceName: "rain_soft"),
                    source("潮声", "water.waves", angle: .pi * 1.25, radius: 0.72, initialEnvelope: 0.3, resourceName: "stream_nature"),
                    source("钢琴", "pianokeys", angle: -.pi * 0.35, radius: 0.48, initialEnvelope: 0.28),
                    source("人声", "person.wave.2.fill", angle: .pi * 0.55, radius: 0.4, initialEnvelope: 0.25, enabled: false, layer: .voice)
                ]
            )
        ])
    }

    private static func hairCareScene() -> DreamScene {
        // Tracks follow 洗头场景_文本与声音时间戳协同表 v4. Start quiet;
        // SceneTimelineScheduler raises/fades layers per cue.
        let sources: [SoundSource] = [
            SoundSource(
                id: DemoIDs.sourceAC,
                name: "底噪",
                symbolName: "wind.circle.fill",
                isEnabled: true,
                initialEnvelope: 0.18,
                position: SpatialPosition(angle: .pi * 1.2, radius: 0.82),
                resourceName: "ac_hum",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceHairWaterCycle,
                name: "水循环",
                symbolName: "drop.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: 0.4, radius: 0.78),
                resourceName: "hair_wash_water_cycle",
                layer: .environment
            ),
            SoundSource(
                id: DemoIDs.sourceHairWet,
                name: "打湿",
                symbolName: "drop.triangle.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.85, radius: 0.55),
                resourceName: "hair_wash_wet",
                layer: .trigger
            ),
            SoundSource(
                id: DemoIDs.sourceHairFoamStart,
                name: "起泡",
                symbolName: "bubbles.and.sparkles",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.5, radius: 0.45),
                resourceName: "hair_wash_foam_start",
                layer: .trigger
            ),
            SoundSource(
                id: DemoIDs.sourceHairFoamRub,
                name: "泡沫揉洗",
                symbolName: "hand.raised.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.9, radius: 0.48),
                resourceName: "hair_wash_foam_rub",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceHairScalpFoam,
                name: "头皮按摩",
                symbolName: "hand.point.up.left.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.5, radius: 0.42),
                resourceName: "hair_wash_scalp_foam",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceHairRinse,
                name: "冲洗",
                symbolName: "shower.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.7, radius: 0.58),
                resourceName: "hair_wash_rinse",
                layer: .trigger
            ),
            SoundSource(
                id: DemoIDs.sourceHairFingerMassage,
                name: "指腹按压",
                symbolName: "hand.tap.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.5, radius: 0.4),
                resourceName: "hair_wash_finger_massage",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceHairTowel,
                name: "毛巾",
                symbolName: "rectangle.fill",
                isEnabled: true,
                initialEnvelope: 0.01,
                position: SpatialPosition(angle: .pi * 0.55, radius: 0.5),
                resourceName: "hair_towel",
                layer: .trigger
            ),
            SoundSource(
                id: DemoIDs.sourceVoice,
                name: "轻声陪伴",
                symbolName: "person.wave.2.fill",
                isEnabled: true,
                initialEnvelope: 0.48,
                position: SpatialPosition(angle: -.pi * 0.25, radius: 0.36),
                assetId: DemoIDs.seedMom,
                resourceName: "voice_phrase_mom",
                layer: .voice
            )
        ]
        let manifest = SceneAudioManifest(
            tracks: sources.compactMap { s in
                guard let resource = s.resourceName else { return nil }
                return AudioTrackRef(
                    id: s.id,
                    name: s.name,
                    symbolName: s.symbolName,
                    resourceName: resource,
                    layer: s.layer,
                    loops: s.layer == .environment || s.layer == .ambience,
                    initialEnvelope: s.initialEnvelope,
                    defaultPosition: s.position,
                    isRequired: s.layer == .ambience || s.layer == .voice
                )
            },
            voicePhraseResourceName: "voice_phrase_mom"
        )
        return DreamScene(
            id: DemoIDs.hairCareScene,
            name: "洗头陪伴",
            subtitle: "温水、轻声，还有熟悉的陪伴。",
            description: "约 10 分 20 秒的温和洗头实景演绎：文本提示 + 水流/泡沫/冲洗/毛巾分层时间线。手机外放即可成立。人声短句待正式录制前暂用占位音频。",
            category: .companion,
            tags: ["洗头", "陪伴"],
            palette: ScenePalette(top: 0x1A2438, mid: 0x2E4058, bottom: 0x141820, accent: 0xA8C8E0),
            soundSources: sources,
            isFavorite: true,
            isFrequentlyUsed: false,
            listenCount: 60,
            mockListenerCount: 2180,
            visualStyle: .hairCare,
            isDemoPlayable: true,
            audioManifest: manifest
        )
    }

    private static func rainEavesScene() -> DreamScene {
        // Template B (environment, no voice): A01 far soft → A02 near parasol → A03 bamboo → A04 wind cues.
        let sources: [SoundSource] = [
            SoundSource(
                id: DemoIDs.sourceRainSoftFar,
                name: "远雨",
                symbolName: "cloud.drizzle.fill",
                isEnabled: true,
                initialEnvelope: 0.22,
                position: SpatialPosition(angle: -0.35, radius: 0.85),
                resourceName: "rain_soft",
                layer: .environment
            ),
            SoundSource(
                id: DemoIDs.sourceRain,
                name: "檐下雨",
                symbolName: "cloud.rain.fill",
                isEnabled: false,
                initialEnvelope: 0.0,
                position: SpatialPosition(angle: 0.7, radius: 0.62),
                resourceName: "rain_parasol",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceRainBambooLeaf,
                name: "竹叶雨",
                symbolName: "leaf.fill",
                isEnabled: false,
                initialEnvelope: 0.0,
                position: SpatialPosition(angle: -1.2, radius: 0.88),
                resourceName: "rain_bamboo_leaf",
                layer: .ambience
            ),
            SoundSource(
                id: DemoIDs.sourceWind,
                name: "阵风",
                symbolName: "wind",
                isEnabled: false,
                initialEnvelope: 0.0,
                position: SpatialPosition(angle: -2.4, radius: 0.95),
                resourceName: "wind_gust",
                layer: .trigger
            )
        ]
        let manifest = SceneAudioManifest(
            tracks: sources.compactMap { s in
                guard let resource = s.resourceName else { return nil }
                return AudioTrackRef(
                    id: s.id,
                    name: s.name,
                    symbolName: s.symbolName,
                    resourceName: resource,
                    layer: s.layer,
                    loops: s.layer != .trigger,
                    initialEnvelope: s.initialEnvelope,
                    defaultPosition: s.position,
                    isRequired: s.id == DemoIDs.sourceRainSoftFar
                )
            },
            voicePhraseResourceName: nil
        )
        return DreamScene(
            id: DemoIDs.rainEavesScene,
            name: "檐下听雨",
            subtitle: "雨声落在窗外，房间里仍有一盏灯。",
            description: "檐角细雨轻轻敲打，暖灯把夜色留在窗边。适合慢慢放下一天的声音。",
            category: .rainyNight,
            tags: ["雨夜", "温暖"],
            palette: ScenePalette(top: 0x1A2740, mid: 0x2C3E55, bottom: 0x1B1410, accent: 0xD79A72),
            soundSources: sources,
            isFavorite: true,
            isFrequentlyUsed: false,
            listenCount: 48,
            mockListenerCount: 1286,
            visualStyle: .rainEaves,
            isDemoPlayable: true,
            audioManifest: manifest
        )
    }

    static func markTopFrequentScenes(_ scenes: [DreamScene]) -> [DreamScene] {
        let ranked = scenes.sorted { lhs, rhs in
            if lhs.listenCount == rhs.listenCount {
                return lhs.name < rhs.name
            }
            return lhs.listenCount > rhs.listenCount
        }
        let topIds = Set(ranked.prefix(frequentSceneLimit).map(\.id))
        return scenes.map { scene in
            var updated = scene
            updated.isFrequentlyUsed = topIds.contains(scene.id)
            return updated
        }
    }

    static func makeSoundAssets() -> [SoundAsset] {
        let now = Date(timeIntervalSince1970: 1_751_328_000) // stable demo anchor
        return [
            SoundAsset(
                id: DemoIDs.recordingRain,
                name: "雨巷片段",
                kind: .recording,
                durationSeconds: 84,
                symbolName: "mic.fill",
                avatarColor: 0x8197B5,
                isFavorite: false,
                relation: nil,
                createdAt: now.addingTimeInterval(-86400 * 3),
                lastUsedAt: now.addingTimeInterval(-7200)
            ),
            SoundAsset(
                id: DemoIDs.recordingStudy,
                name: "书房试录",
                kind: .recording,
                durationSeconds: 45,
                symbolName: "mic.fill",
                avatarColor: 0xA8B8D0,
                isFavorite: false,
                relation: nil,
                createdAt: now.addingTimeInterval(-86400),
                lastUsedAt: now.addingTimeInterval(-86400)
            ),
            SoundAsset(
                id: DemoIDs.seedMom,
                name: "妈妈的晚安",
                kind: .seed,
                durationSeconds: 126,
                symbolName: "leaf.fill",
                avatarColor: 0xD79A72,
                isFavorite: true,
                relation: .family,
                createdAt: now.addingTimeInterval(-86400 * 12),
                lastUsedAt: now.addingTimeInterval(-3600),
                previewResourceName: "voice_phrase_mom",
                processingStatus: .ready,
                authorization: VoiceAuthorization(confirmed: true, revocable: true, authorizationId: "auth-mom-demo")
            ),
            SoundAsset(
                id: DemoIDs.seedFriend,
                name: "朋友的故事",
                kind: .seed,
                durationSeconds: 201,
                symbolName: "leaf.fill",
                avatarColor: 0x7FB8A8,
                isFavorite: false,
                relation: .friend,
                createdAt: now.addingTimeInterval(-86400 * 8),
                lastUsedAt: nil,
                previewResourceName: "voice_phrase_mom",
                processingStatus: .ready,
                authorization: VoiceAuthorization(confirmed: true, revocable: true, authorizationId: "auth-friend-demo")
            ),
            SoundAsset(
                id: DemoIDs.seedPartner,
                name: "伴侣轻语",
                kind: .seed,
                durationSeconds: 158,
                symbolName: "leaf.fill",
                avatarColor: 0x8D87A8,
                isFavorite: true,
                relation: .partner,
                createdAt: now.addingTimeInterval(-86400 * 20),
                lastUsedAt: now.addingTimeInterval(-1800),
                previewResourceName: "voice_phrase_mom",
                processingStatus: .ready,
                authorization: VoiceAuthorization(confirmed: true, revocable: true, authorizationId: "auth-partner-demo")
            ),
            SoundAsset(id: DemoIDs.communityBreath, name: "温柔呼吸引导", kind: .community, durationSeconds: 180, symbolName: "wind", avatarColor: 0x9AA6D8, isFavorite: true, relation: nil, createdAt: now.addingTimeInterval(-86400 * 30), lastUsedAt: now.addingTimeInterval(-5400)),
            SoundAsset(id: DemoIDs.communityRain, name: "夜窗细雨", kind: .community, durationSeconds: 240, symbolName: "cloud.rain.fill", avatarColor: 0x5A7A9A, isFavorite: true, relation: nil, createdAt: now.addingTimeInterval(-86400 * 15), lastUsedAt: nil),
            SoundAsset(id: DemoIDs.communityTide, name: "海边慢潮", kind: .community, durationSeconds: 300, symbolName: "water.waves", avatarColor: 0x6A90A8, isFavorite: false, relation: nil, createdAt: now.addingTimeInterval(-86400 * 9), lastUsedAt: nil),
            SoundAsset(id: DemoIDs.communityInsects, name: "林间虫鸣", kind: .community, durationSeconds: 210, symbolName: "leaf.fill", avatarColor: 0x6A8A68, isFavorite: true, relation: nil, createdAt: now.addingTimeInterval(-86400 * 6), lastUsedAt: now.addingTimeInterval(-4000)),
            SoundAsset(id: DemoIDs.communityPiano, name: "午夜钢琴", kind: .community, durationSeconds: 195, symbolName: "pianokeys", avatarColor: 0x8D87A8, isFavorite: false, relation: nil, createdAt: now.addingTimeInterval(-86400 * 4), lastUsedAt: nil),
            SoundAsset(id: DemoIDs.communityFire, name: "炉火轻响", kind: .community, durationSeconds: 220, symbolName: "flame.fill", avatarColor: 0xC08060, isFavorite: true, relation: nil, createdAt: now.addingTimeInterval(-86400 * 11), lastUsedAt: nil),
            SoundAsset(id: DemoIDs.communityStream, name: "山谷流水", kind: .community, durationSeconds: 260, symbolName: "drop.fill", avatarColor: 0x7FB8A8, isFavorite: false, relation: nil, createdAt: now.addingTimeInterval(-86400 * 2), lastUsedAt: nil)
        ]
    }

    static func makeUsageRecord() -> UsageRecord {
        UsageRecord(
            id: DemoIDs.usageRecord,
            totalMinutes: 1864,
            weekMinutes: 248,
            usualBedtime: "23:20",
            lastUsedAt: Date(timeIntervalSince1970: 1_751_328_000).addingTimeInterval(-3600 * 5),
            sleepTrend: [28, 42, 18, 55, 36, 40, 29]
        )
    }

    static func makeMixPresets() -> [MixPreset] {
        [
            MixPreset(
                id: DemoIDs.presetHairCare,
                title: "洗头轻声",
                subtitle: "水循环与泡沫贴近，人声在身侧",
                authorType: .official,
                authorName: "织梦",
                sources: [
                    source("水循环", "drop.fill", angle: 0.4, radius: 0.55, initialEnvelope: 0.32, resourceName: "hair_wash_water_cycle"),
                    source("泡沫揉洗", "hand.raised.fill", angle: .pi * 0.9, radius: 0.48, initialEnvelope: 0.3, resourceName: "hair_wash_foam_rub", layer: .ambience),
                    source("底噪", "wind.circle.fill", angle: .pi * 1.2, radius: 0.82, initialEnvelope: 0.18, resourceName: "ac_hum", layer: .ambience),
                    source("轻声陪伴", "person.wave.2.fill", angle: -.pi * 0.25, radius: 0.36, initialEnvelope: 0.48, resourceName: "voice_phrase_mom", layer: .voice, assetId: DemoIDs.seedMom)
                ],
                sceneId: DemoIDs.hairCareScene,
                styleHint: SceneVisualStyle.hairCare.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetRainFine,
                title: "细雨慢听",
                subtitle: "远雨垫底，檐雨近听，竹叶轻扫",
                authorType: .official,
                authorName: "织梦",
                sources: [
                    source("远雨", "cloud.drizzle.fill", angle: -0.35, radius: 0.85, initialEnvelope: 0.22, resourceName: "rain_soft", layer: .environment),
                    source("檐下雨", "cloud.rain.fill", angle: 0.7, radius: 0.62, initialEnvelope: 0.4, resourceName: "rain_parasol", layer: .ambience),
                    source("竹叶雨", "leaf.fill", angle: -1.2, radius: 0.88, initialEnvelope: 0.27, resourceName: "rain_bamboo_leaf", layer: .ambience),
                    source("阵风", "wind", angle: -2.4, radius: 0.95, initialEnvelope: 0.20, resourceName: "wind_gust", layer: .trigger)
                ],
                sceneId: DemoIDs.rainEavesScene,
                styleHint: SceneVisualStyle.rainEaves.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetForestGlow,
                title: "深林微光",
                subtitle: "虫鸣环绕，人声轻轻靠近",
                authorType: .official,
                authorName: "织梦",
                sources: [
                    source("虫鸣", "leaf.fill", angle: .pi * 0.55, radius: 0.48, initialEnvelope: 0.7),
                    source("风声", "wind", angle: .pi * 0.15, radius: 0.72, initialEnvelope: 0.32),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.4, radius: 0.36, initialEnvelope: 0.42, layer: .voice),
                    source("钢琴", "pianokeys", angle: .pi * 1.2, radius: 0.68, initialEnvelope: 0.2)
                ],
                sceneId: DemoIDs.firefliesScene,
                styleHint: SceneVisualStyle.fireflies.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetMistTide,
                title: "雾岸双潮",
                subtitle: "潮声一近一远，像潮汐在呼吸",
                authorType: .community,
                authorName: "晚风拾句",
                sources: [
                    source("潮声", "water.waves", angle: .pi * 0.85, radius: 0.4, initialEnvelope: 0.78),
                    source("潮声", "water.waves", angle: -.pi * 0.2, radius: 0.82, initialEnvelope: 0.3),
                    source("风声", "wind", angle: .pi * 0.3, radius: 0.7, initialEnvelope: 0.35),
                    source("人声", "person.wave.2.fill", angle: .pi * 1.4, radius: 0.42, initialEnvelope: 0.38, layer: .voice)
                ],
                sceneId: DemoIDs.mistTideScene,
                styleHint: SceneVisualStyle.mistTide.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetFireplace,
                title: "炉边低语",
                subtitle: "炉火贴近，雨声留在窗外",
                authorType: .community,
                authorName: "小满夜读",
                sources: [
                    source("炉火", "flame.fill", angle: .pi * 0.5, radius: 0.32, initialEnvelope: 0.72),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.2, radius: 0.36, initialEnvelope: 0.55, layer: .voice),
                    source("雨声", "cloud.rain.fill", angle: .pi * 1.0, radius: 0.76, initialEnvelope: 0.34),
                    source("钢琴", "pianokeys", angle: .pi * 0.15, radius: 0.58, initialEnvelope: 0.26)
                ],
                sceneId: DemoIDs.fireplaceScene,
                styleHint: SceneVisualStyle.fireplaceWhisper.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetStarRiver,
                title: "空灵星河",
                subtitle: "钢琴居中，风与星点散开",
                authorType: .community,
                authorName: "北岸",
                sources: [
                    source("钢琴", "pianokeys", angle: -.pi * 0.1, radius: 0.3, initialEnvelope: 0.68),
                    source("风声", "wind", angle: .pi * 0.4, radius: 0.74, initialEnvelope: 0.28),
                    source("人声", "person.wave.2.fill", angle: .pi * 1.15, radius: 0.5, initialEnvelope: 0.32, layer: .voice),
                    source("虫鸣", "leaf.fill", angle: .pi * 0.75, radius: 0.8, initialEnvelope: 0.18)
                ],
                sceneId: DemoIDs.starRiverScene,
                styleHint: SceneVisualStyle.starRiver.rawValue
            ),
            MixPreset(
                id: DemoIDs.presetBreathOnly,
                title: "只留呼吸",
                subtitle: "极简：一层风，一层轻语",
                authorType: .community,
                authorName: "安然",
                sources: [
                    source("风声", "wind", angle: .pi * 0.25, radius: 0.55, initialEnvelope: 0.45),
                    source("人声", "person.wave.2.fill", angle: -.pi * 0.3, radius: 0.4, initialEnvelope: 0.5, layer: .voice)
                ],
                sceneId: DemoIDs.cloudBreathScene,
                styleHint: SceneVisualStyle.cloudBreath.rawValue
            )
        ]
    }

    static func makeBootstrap() -> BootstrapPayload {
        BootstrapPayload(
            greeting: greetings[0],
            recommendedSceneId: DemoIDs.hairCareScene,
            defaultSceneId: DemoIDs.hairCareScene,
            nickname: "夜行者",
            isAppleSignedIn: true,
            isMember: true
        )
    }

    static func makeSeedQuality(durationSeconds: Int) -> SeedQualityReport {
        SeedQualityReport(
            clarity: "良好",
            noiseLevel: "较低",
            effectiveDurationSeconds: max(durationSeconds, 3),
            recommendation: "可以直接继续",
            passed: true
        )
    }

    // MARK: - Helpers

    private static func scene(
        id: UUID,
        name: String,
        subtitle: String,
        description: String,
        category: SceneCategory,
        tags: [String],
        palette: ScenePalette,
        style: SceneVisualStyle,
        favorite: Bool,
        listens: Int,
        listeners: Int,
        sources: [SoundSource]
    ) -> DreamScene {
        DreamScene(
            id: id,
            name: name,
            subtitle: subtitle,
            description: description,
            category: category,
            tags: tags,
            palette: palette,
            soundSources: sources,
            isFavorite: favorite,
            isFrequentlyUsed: false,
            listenCount: listens,
            mockListenerCount: listeners,
            visualStyle: style,
            isDemoPlayable: false,
            audioManifest: nil
        )
    }

    private static func source(
        _ name: String,
        _ symbol: String,
        angle: Double,
        radius: Double,
        initialEnvelope: Double = 0.7,
        enabled: Bool = true,
        resourceName: String? = nil,
        layer: AudioLayerKind = .environment,
        assetId: UUID? = nil
    ) -> SoundSource {
        SoundSource(
            name: name,
            symbolName: symbol,
            isEnabled: enabled,
            initialEnvelope: initialEnvelope,
            position: SpatialPosition(angle: angle, radius: radius),
            assetId: assetId,
            resourceName: resourceName,
            layer: layer
        )
    }
}
