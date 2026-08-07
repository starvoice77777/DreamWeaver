from __future__ import annotations

import math
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import MixPreset, Scene, SceneTrack

DEFAULT_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111101")
RETIRED_SCENE_IDS = frozenset(
    {
        uuid.UUID("a1111111-1111-4111-8111-111111111107"),
        uuid.UUID("a1111111-1111-4111-8111-111111111109"),
        uuid.UUID("a1111111-1111-4111-8111-11111111110e"),
    }
)

GREETINGS = [
    "晚上好，今天辛苦了。",
    "夜色刚好，慢慢把心放下来。",
    "把呼吸交给这一小会儿。",
    "今晚，为你留了一片安静。",
]


def _palette(top: int, mid: int, bottom: int, accent: int) -> dict[str, int]:
    return {"top": top, "mid": mid, "bottom": bottom, "accent": accent}


def _tid(suffix: int) -> uuid.UUID:
    return uuid.UUID(f"f6666666-6666-4666-8666-{suffix:012d}")


def _track(
    *,
    track_id: uuid.UUID,
    name: str,
    symbol: str,
    angle: float,
    radius: float,
    initial_envelope: float,
    layer: str = "environment",
    resource_key: str | None = None,
    enabled: bool = True,
    loop: bool | None = None,
    sort_order: int = 0,
) -> dict:
    loops = loop if loop is not None else layer not in {"voice", "trigger"}
    return {
        "id": track_id,
        "name": name,
        "symbol_name": symbol,
        "layer": layer,
        "initial_envelope": initial_envelope,
        "angle": angle,
        "radius": radius,
        "resource_key": resource_key,
        "loop": loops,
        "enabled_by_default": enabled,
        "sort_order": sort_order,
    }


def official_scene_specs() -> list[dict]:
    """Official catalog aligned with iOS MockDataService / DemoIDs (15 scenes)."""
    pi = math.pi
    specs = [
        {
            "id": DEFAULT_SCENE_ID,
            "name": "洗头陪伴",
            "subtitle": "温水、轻声，还有熟悉的陪伴。",
            "description": (
                "约 10 分 20 秒的温和洗头实景演绎："
                "文本提示与水流/泡沫/冲洗/毛巾分层时间线。"
            ),
            "category": "companion",
            "tags": ["陪伴", "生活", "洗头"],
            "palette": _palette(0x1B2A3A, 0x2F4458, 0x1A1412, 0xE0B089),
            "visual_style": "hairCare",
            "is_demo_playable": True,
            "sort_order": 0,
            "mock_listener_count": 2860,
            "recommended_duration_seconds": 620,
            "tracks": [
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555506"),
                    name="水滴房间底噪",
                    symbol="drop.circle.fill",
                    angle=-0.62,
                    radius=0.74,
                    initial_envelope=0.22,
                    layer="trigger",
                    resource_key="water_drip_roomtone",
                    loop=False,
                    sort_order=0,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555508"),
                    name="水循环",
                    symbol="drop.fill",
                    angle=0.18,
                    radius=0.80,
                    initial_envelope=0.2,
                    resource_key="hair_wash_water_cycle",
                    sort_order=1,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555509"),
                    name="打湿",
                    symbol="drop.triangle.fill",
                    angle=0.0,
                    radius=0.66,
                    initial_envelope=0.33,
                    layer="trigger",
                    resource_key="hair_wash_wet",
                    loop=False,
                    sort_order=2,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550a"),
                    name="起泡",
                    symbol="bubbles.and.sparkles",
                    angle=-0.35,
                    radius=0.32,
                    initial_envelope=0.45,
                    layer="trigger",
                    resource_key="hair_wash_foam_start",
                    loop=False,
                    sort_order=3,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550b"),
                    name="泡沫揉洗",
                    symbol="hand.raised.fill",
                    angle=-0.28,
                    radius=0.42,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_foam_rub",
                    sort_order=4,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550c"),
                    name="头皮按摩",
                    symbol="hand.point.up.left.fill",
                    angle=0.25,
                    radius=0.39,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_scalp_foam",
                    sort_order=5,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550d"),
                    name="冲洗",
                    symbol="shower.fill",
                    angle=0.45,
                    radius=0.68,
                    initial_envelope=0.36,
                    layer="trigger",
                    resource_key="hair_wash_rinse",
                    loop=False,
                    sort_order=6,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550e"),
                    name="指腹按压",
                    symbol="hand.tap.fill",
                    angle=0.32,
                    radius=0.34,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_finger_massage",
                    sort_order=7,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550f"),
                    name="毛巾",
                    symbol="rectangle.fill",
                    angle=-0.55,
                    radius=0.34,
                    initial_envelope=0.43,
                    layer="trigger",
                    resource_key="hair_towel",
                    loop=False,
                    sort_order=8,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555503"),
                    name="轻声陪伴",
                    symbol="person.wave.2.fill",
                    angle=0.0,
                    radius=0.38,
                    initial_envelope=0.68,
                    layer="voice",
                    resource_key="voice_phrase_01",
                    loop=False,
                    sort_order=9,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111102"),
            "name": "檐下听雨",
            "subtitle": "雨声落在窗外，房间里仍有一盏灯。",
            "description": "檐角细雨轻轻敲打，暖灯把夜色留在窗边。",
            "category": "rainyNight",
            "tags": ["雨夜", "温暖"],
            "palette": _palette(0x1A2740, 0x2C3E55, 0x1B1410, 0xD79A72),
            "visual_style": "rainEaves",
            "is_demo_playable": True,
            "sort_order": 1,
            "mock_listener_count": 1286,
            "tracks": [
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555510"),
                    name="远雨",
                    symbol="cloud.drizzle.fill",
                    angle=-0.35,
                    radius=0.78,
                    initial_envelope=0.22,
                    layer="environment",
                    resource_key="rain_soft",
                    sort_order=0,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555501"),
                    name="檐下雨",
                    symbol="cloud.rain.fill",
                    angle=0.7,
                    radius=0.62,
                    initial_envelope=0.0,
                    layer="ambience",
                    resource_key="rain_parasol",
                    sort_order=1,
                    enabled=False,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555512"),
                    name="竹叶雨",
                    symbol="leaf.fill",
                    angle=-1.2,
                    radius=0.78,
                    initial_envelope=0.0,
                    layer="ambience",
                    resource_key="rain_bamboo_leaf",
                    sort_order=2,
                    enabled=False,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555502"),
                    name="阵风",
                    symbol="wind",
                    angle=-2.4,
                    radius=0.77,
                    initial_envelope=0.0,
                    layer="trigger",
                    resource_key="wind_gust",
                    loop=False,
                    sort_order=3,
                    enabled=False,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111103"),
            "name": "喜马拉雅",
            "subtitle": "离天空最近的地方",
            "description": "离天空最近的地方",
            "category": "forest",
            "tags": ["雪山", "天空"],
            "palette": _palette(0x0B1A14, 0x163028, 0x0A1520, 0xC8E6A0),
            "visual_style": "fireflies",
            "is_demo_playable": False,
            "sort_order": 2,
            "mock_listener_count": 964,
            "tracks": [
                _track(
                    track_id=_tid(10301),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.15,
                    radius=0.7,
                    initial_envelope=0.65,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10302),
                    name="虫鸣",
                    symbol="leaf.fill",
                    angle=pi * 0.7,
                    radius=0.55,
                    initial_envelope=0.5,
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111104"),
            "name": "星期天",
            "subtitle": "偷得浮生半日闲。",
            "description": "偷得浮生半日闲。",
            "category": "ocean",
            "tags": ["星期天", "海边"],
            "palette": _palette(0x72AAB8, 0x1688A0, 0x0A5063, 0xE7D7C5),
            "visual_style": "mistTide",
            "is_demo_playable": False,
            "sort_order": 3,
            "mock_listener_count": 742,
            "tracks": [
                _track(
                    track_id=_tid(10401),
                    name="潮声",
                    symbol="water.waves",
                    angle=pi * 0.9,
                    radius=0.65,
                    initial_envelope=0.8,
                    resource_key="stream_nature",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10402),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.25,
                    radius=0.7,
                    initial_envelope=0.4,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111105"),
            "name": "幽谷清流",
            "subtitle": "水声沿着石缝，轻轻绕过心口。",
            "description": "山谷溪流清亮而连续，适合需要被轻轻带着走的夜晚。",
            "category": "nature",
            "tags": ["流水", "山谷"],
            "palette": _palette(0x13241F, 0x1F3D38, 0x101820, 0x7FB8A8),
            "visual_style": "valleyStream",
            "is_demo_playable": False,
            "sort_order": 4,
            "mock_listener_count": 531,
            "tracks": [
                _track(
                    track_id=_tid(10501),
                    name="流水",
                    symbol="drop.fill",
                    angle=pi * 0.8,
                    radius=0.5,
                    initial_envelope=0.75,
                    resource_key="stream_nature",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10502),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.7,
                    initial_envelope=0.3,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111106"),
            "name": "山色",
            "subtitle": "山色有无中",
            "description": "山色有无中。",
            "category": "nature",
            "tags": ["山色", "湖"],
            "palette": _palette(0xAEB9C4, 0x287F93, 0x003544, 0xB7D1D7),
            "visual_style": "moonLake",
            "is_demo_playable": False,
            "sort_order": 5,
            "mock_listener_count": 1102,
            "tracks": [
                _track(
                    track_id=_tid(10601),
                    name="湖面",
                    symbol="water.waves",
                    angle=pi * 0.95,
                    radius=0.58,
                    initial_envelope=0.45,
                    resource_key="stream_nature",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10602),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.18,
                    radius=0.68,
                    initial_envelope=0.25,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110f"),
            "name": "阿尔卑斯",
            "subtitle": "坐缆车上山滑雪",
            "description": "坐缆车上山滑雪",
            "category": "nature",
            "tags": ["雪山", "缆车"],
            "palette": _palette(0xD7DDD8, 0xA8B5B6, 0x273533, 0xB9C8C4),
            "visual_style": "alpsCableCar",
            "is_demo_playable": False,
            "sort_order": 6,
            "mock_listener_count": 912,
            "tracks": [
                _track(
                    track_id=_tid(11501),
                    name="高山风",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.72,
                    initial_envelope=0.55,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11502),
                    name="缆车",
                    symbol="cablecar.fill",
                    angle=pi * 0.85,
                    radius=0.5,
                    initial_envelope=0.28,
                    sort_order=1,
                ),
                _track(
                    track_id=_tid(11503),
                    name="雪道",
                    symbol="figure.skiing.downhill",
                    angle=-pi * 0.35,
                    radius=0.62,
                    initial_envelope=0.22,
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111110"),
            "name": "黄昏",
            "subtitle": "明天又是新的一天",
            "description": "明天又是新的一天",
            "category": "breath",
            "tags": ["黄昏", "新一天"],
            "palette": _palette(0x3A294A, 0xA96F5D, 0x12131C, 0xC9A083),
            "visual_style": "twilight",
            "is_demo_playable": False,
            "sort_order": 7,
            "mock_listener_count": 1264,
            "tracks": [
                _track(
                    track_id=_tid(11601),
                    name="晚风",
                    symbol="wind",
                    angle=pi * 0.15,
                    radius=0.68,
                    initial_envelope=0.42,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11602),
                    name="远野",
                    symbol="leaf.fill",
                    angle=pi * 0.82,
                    radius=0.58,
                    initial_envelope=0.24,
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111111"),
            "name": "序幕",
            "subtitle": "INTRO...",
            "description": "INTRO...",
            "category": "lightMusic",
            "tags": ["序幕", "远空"],
            "palette": _palette(0x51484A, 0xA57562, 0xD77A3B, 0xC7A49B),
            "visual_style": "prelude",
            "is_demo_playable": False,
            "sort_order": 8,
            "mock_listener_count": 768,
            "tracks": [
                _track(
                    track_id=_tid(11701),
                    name="远空",
                    symbol="airplane",
                    angle=pi * 0.72,
                    radius=0.78,
                    initial_envelope=0.22,
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11702),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.18,
                    radius=0.64,
                    initial_envelope=0.3,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111112"),
            "name": "雕梁画栋",
            "subtitle": "建筑是大地的文字",
            "description": "建筑是大地的文字",
            "category": "companion",
            "tags": ["建筑", "东方"],
            "palette": _palette(0xB6B6B6, 0x676767, 0x151515, 0xA3AAA6),
            "visual_style": "ornateArchitecture",
            "is_demo_playable": False,
            "sort_order": 9,
            "mock_listener_count": 694,
            "tracks": [
                _track(
                    track_id=_tid(11801),
                    name="檐下风",
                    symbol="wind",
                    angle=pi * 0.22,
                    radius=0.7,
                    initial_envelope=0.34,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11802),
                    name="脚步",
                    symbol="shoeprints.fill",
                    angle=pi * 0.9,
                    radius=0.48,
                    initial_envelope=0.18,
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111108"),
            "name": "长路",
            "subtitle": "行走于漫漫长路",
            "description": "行走于漫漫长路",
            "category": "companion",
            "tags": ["长路", "行走"],
            "palette": _palette(0x2A1E16, 0x4A3424, 0x18120E, 0xE0A878),
            "visual_style": "warmLamp",
            "is_demo_playable": False,
            "sort_order": 10,
            "mock_listener_count": 2031,
            "tracks": [
                _track(
                    track_id=_tid(10802),
                    name="雨声",
                    symbol="cloud.rain.fill",
                    angle=pi * 0.3,
                    radius=0.72,
                    initial_envelope=0.25,
                    resource_key="rain_soft",
                    sort_order=1,
                ),
                _track(
                    track_id=_tid(10803),
                    name="炉火",
                    symbol="flame.fill",
                    angle=pi * 0.55,
                    radius=0.48,
                    initial_envelope=0.3,
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110a"),
            "name": "麦浪",
            "subtitle": "天地的两种色彩",
            "description": "天地的两种色彩",
            "category": "nature",
            "tags": ["麦浪", "天地"],
            "palette": _palette(0x1C2418, 0x3A4630, 0x141810, 0xC8B070),
            "visual_style": "wheatWind",
            "is_demo_playable": False,
            "sort_order": 11,
            "mock_listener_count": 412,
            "tracks": [
                _track(
                    track_id=_tid(11001),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.25,
                    radius=0.6,
                    initial_envelope=0.7,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11002),
                    name="虫鸣",
                    symbol="leaf.fill",
                    angle=pi * 0.8,
                    radius=0.55,
                    initial_envelope=0.4,
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110b"),
            "name": "飞行",
            "subtitle": "傍晚时分的落日飞行",
            "description": "傍晚时分的落日飞行",
            "category": "breath",
            "tags": ["飞行", "落日"],
            "palette": _palette(0x182030, 0x2E3C52, 0x10161E, 0xA8B8D0),
            "visual_style": "cloudBreath",
            "is_demo_playable": False,
            "sort_order": 12,
            "mock_listener_count": 895,
            "tracks": [
                _track(
                    track_id=_tid(11101),
                    name="呼吸",
                    symbol="wind.circle.fill",
                    angle=-pi * 0.1,
                    radius=0.35,
                    initial_envelope=0.65,
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11103),
                    name="风声",
                    symbol="wind",
                    angle=pi * 1.3,
                    radius=0.72,
                    initial_envelope=0.25,
                    resource_key="wind_realistic",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110c"),
            "name": "夏夜",
            "subtitle": "一个林间的夜晚",
            "description": "一个林间的夜晚",
            "category": "nature",
            "tags": ["夏夜", "林间"],
            "palette": _palette(0x142018, 0x243828, 0x101410, 0x88C878),
            "visual_style": "summerInsects",
            "is_demo_playable": False,
            "sort_order": 13,
            "mock_listener_count": 623,
            "tracks": [
                _track(
                    track_id=_tid(11201),
                    name="虫鸣",
                    symbol="leaf.fill",
                    angle=pi * 0.6,
                    radius=0.55,
                    initial_envelope=0.7,
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11202),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.15,
                    radius=0.7,
                    initial_envelope=0.3,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110d"),
            "name": "炉边低语",
            "subtitle": "火光轻轻说着不重要的事。",
            "description": "炉火细碎作响，雨声与暖色把夜晚收得很近。",
            "category": "companion",
            "tags": ["炉火", "低语"],
            "palette": _palette(0x241810, 0x4A2C1A, 0x140E0A, 0xE09060),
            "visual_style": "fireplaceWhisper",
            "is_demo_playable": False,
            "sort_order": 14,
            "mock_listener_count": 1344,
            "tracks": [
                _track(
                    track_id=_tid(11301),
                    name="炉火",
                    symbol="flame.fill",
                    angle=pi * 0.55,
                    radius=0.4,
                    initial_envelope=0.65,
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11303),
                    name="雨声",
                    symbol="cloud.rain.fill",
                    angle=pi * 0.95,
                    radius=0.72,
                    initial_envelope=0.3,
                    resource_key="rain_soft",
                    sort_order=2,
                ),
            ],
        },
    ]
    # Product invariant: bundled narration belongs exclusively to hair care.
    # Keep this guard at the catalog boundary so a future scene fixture cannot
    # accidentally expose or schedule the mastered hair-care phrases.
    for spec in specs:
        if spec["id"] != DEFAULT_SCENE_ID:
            spec["tracks"] = [track for track in spec["tracks"] if track["layer"] != "voice"]
    return specs


def official_preset_specs() -> list[dict]:
    return [
        {
            "id": uuid.UUID("d4444444-4444-4444-8444-444444444407"),
            "scene_id": DEFAULT_SCENE_ID,
            "name": "洗头轻声",
            "style_hint": "hairCare",
            "author_name": "织梦",
            "sort_order": 0,
            "sources": [
                {
                    "name": "水循环",
                    "symbolName": "drop.fill",
                    "resourceName": "hair_wash_water_cycle",
                    "layer": "environment",
                    "position": {"angle": 0.4, "radius": 0.55},
                },
                {
                    "name": "泡沫揉洗",
                    "symbolName": "hand.raised.fill",
                    "resourceName": "hair_wash_foam_rub",
                    "layer": "ambience",
                    "position": {"angle": math.pi * 0.9, "radius": 0.48},
                },
                {
                    "name": "水滴房间底噪",
                    "symbolName": "drop.circle.fill",
                    "resourceName": "water_drip_roomtone",
                    "layer": "ambience",
                    "position": {"angle": math.pi * 1.2, "radius": 0.74},
                },
                {
                    "name": "轻声陪伴",
                    "symbolName": "person.wave.2.fill",
                    "resourceName": "voice_phrase_01",
                    "layer": "voice",
                    "position": {"angle": -math.pi * 0.25, "radius": 0.36},
                },
            ],
        },
        {
            "id": uuid.UUID("d4444444-4444-4444-8444-444444444401"),
            "scene_id": uuid.UUID("a1111111-1111-4111-8111-111111111102"),
            "name": "细雨慢听",
            "style_hint": "rainEaves",
            "author_name": "织梦",
            "sort_order": 1,
            "sources": [
                {
                    "name": "远雨",
                    "symbolName": "cloud.drizzle.fill",
                    "resourceName": "rain_soft",
                    "layer": "environment",
                    "position": {"angle": -0.35, "radius": 0.78},
                },
                {
                    "name": "檐下雨",
                    "symbolName": "cloud.rain.fill",
                    "resourceName": "rain_parasol",
                    "layer": "ambience",
                    "position": {"angle": 0.7, "radius": 0.62},
                },
                {
                    "name": "竹叶雨",
                    "symbolName": "leaf.fill",
                    "resourceName": "rain_bamboo_leaf",
                    "layer": "ambience",
                    "position": {"angle": -1.2, "radius": 0.78},
                },
                {
                    "name": "阵风",
                    "symbolName": "wind",
                    "resourceName": "wind_gust",
                    "layer": "trigger",
                    "position": {"angle": -2.4, "radius": 0.77},
                },
            ],
        },
    ]


_SCENE_META_KEYS = (
    "name",
    "subtitle",
    "description",
    "category",
    "tags",
    "palette",
    "visual_style",
    "is_demo_playable",
    "sort_order",
    "mock_listener_count",
)


def _track_row(scene_id: uuid.UUID, track_spec: dict, index: int) -> SceneTrack:
    return SceneTrack(
        scene_id=scene_id,
        id=track_spec["id"],
        name=track_spec["name"],
        symbol_name=track_spec["symbol_name"],
        layer=track_spec["layer"],
        initial_envelope=track_spec["initial_envelope"],
        angle=track_spec["angle"],
        radius=track_spec["radius"],
        resource_key=track_spec["resource_key"],
        loop=track_spec.get("loop", True),
        enabled_by_default=track_spec["enabled_by_default"],
        sort_order=track_spec.get("sort_order", index),
    )


def _apply_track_fields(row: SceneTrack, track_spec: dict, index: int) -> None:
    row.name = track_spec["name"]
    row.symbol_name = track_spec["symbol_name"]
    row.layer = track_spec["layer"]
    row.initial_envelope = track_spec["initial_envelope"]
    row.angle = track_spec["angle"]
    row.radius = track_spec["radius"]
    row.resource_key = track_spec["resource_key"]
    row.loop = track_spec.get("loop", True)
    row.enabled_by_default = track_spec["enabled_by_default"]
    row.sort_order = track_spec.get("sort_order", index)


def _add_scene(session: AsyncSession, spec: dict) -> None:
    tracks = spec.pop("tracks")
    session.add(Scene(**spec))
    for index, track_spec in enumerate(tracks):
        session.add(_track_row(spec["id"], track_spec, index))


async def sync_official_scene_tracks(session: AsyncSession) -> dict[str, int]:
    """Make official scene metadata/tracks/presets match the authored catalog."""
    tracks_inserted = 0
    tracks_updated = 0
    tracks_deleted = 0
    scenes_updated = 0
    presets_inserted = 0
    presets_updated = 0

    for spec in official_scene_specs():
        scene = await session.get(Scene, spec["id"])
        if scene is None:
            continue
        for key in _SCENE_META_KEYS:
            if key in spec:
                setattr(scene, key, spec[key])
        scenes_updated += 1
        desired_track_ids = {track_spec["id"] for track_spec in spec["tracks"]}
        existing_tracks = list(
            await session.scalars(select(SceneTrack).where(SceneTrack.scene_id == spec["id"]))
        )
        for row in existing_tracks:
            if row.id not in desired_track_ids:
                await session.delete(row)
                tracks_deleted += 1
        for index, track_spec in enumerate(spec["tracks"]):
            row = await session.get(SceneTrack, track_spec["id"])
            if row is None:
                session.add(_track_row(spec["id"], track_spec, index))
                tracks_inserted += 1
            else:
                _apply_track_fields(row, track_spec, index)
                tracks_updated += 1

    for preset in official_preset_specs():
        existing = await session.get(MixPreset, preset["id"])
        if existing is None:
            session.add(MixPreset(**preset))
            presets_inserted += 1
        else:
            for key, value in preset.items():
                if key == "id":
                    continue
                setattr(existing, key, value)
            presets_updated += 1

    await session.commit()
    return {
        "scenes_updated": scenes_updated,
        "tracks_inserted": tracks_inserted,
        "tracks_updated": tracks_updated,
        "tracks_deleted": tracks_deleted,
        "presets_inserted": presets_inserted,
        "presets_updated": presets_updated,
    }


async def reseed_official_catalog(session: AsyncSession) -> dict[str, int]:
    """Insert missing official rows, then upsert tracks/presets and refresh timelines."""
    await ensure_official_catalog(session, refresh_tracks=False)
    stats = await sync_official_scene_tracks(session)
    from app.services.timeline import ensure_official_timelines

    await ensure_official_timelines(session)
    return stats


async def ensure_official_catalog(
    session: AsyncSession,
    *,
    refresh_tracks: bool = False,
) -> None:
    """Insert any missing official scenes/presets (idempotent; safe for existing DBs).

    When ``refresh_tracks`` is true, also reconcile official tracks and presets,
    including removal of stale official-track rows.
    """
    existing_scene_ids = set(await session.scalars(select(Scene.id)))
    existing_preset_ids = set(await session.scalars(select(MixPreset.id)))
    added = False

    retired_scenes = await session.scalars(
        select(Scene).where(Scene.id.in_(RETIRED_SCENE_IDS))
    )
    for retired_scene in retired_scenes:
        if retired_scene.is_published:
            retired_scene.is_published = False
            added = True

    for spec in official_scene_specs():
        if spec["id"] in existing_scene_ids:
            continue
        _add_scene(session, dict(spec))
        added = True

    for preset in official_preset_specs():
        if preset["id"] in existing_preset_ids:
            existing = await session.get(MixPreset, preset["id"])
            if existing is not None and existing.sources != preset["sources"]:
                for key, value in preset.items():
                    if key == "id":
                        continue
                    setattr(existing, key, value)
                added = True
            continue
        session.add(MixPreset(**preset))
        added = True

    if added:
        await session.commit()

    if refresh_tracks:
        await sync_official_scene_tracks(session)

    from app.services.timeline import ensure_official_timelines

    await ensure_official_timelines(session)
