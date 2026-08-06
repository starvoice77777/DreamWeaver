from __future__ import annotations

import math
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import MixPreset, Scene, SceneTrack

DEFAULT_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111101")

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
    """Official catalog aligned with iOS MockDataService / DemoIDs (14 scenes)."""
    pi = math.pi
    return [
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
                    name="底噪",
                    symbol="wind.circle.fill",
                    angle=-pi * 0.35,
                    radius=0.82,
                    initial_envelope=0.18,
                    layer="ambience",
                    resource_key="ac_hum",
                    sort_order=0,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555508"),
                    name="水循环",
                    symbol="drop.fill",
                    angle=0.4,
                    radius=0.78,
                    initial_envelope=0.01,
                    resource_key="hair_wash_water_cycle",
                    sort_order=1,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555509"),
                    name="打湿",
                    symbol="drop.triangle.fill",
                    angle=pi * 0.85,
                    radius=0.55,
                    initial_envelope=0.01,
                    layer="trigger",
                    resource_key="hair_wash_wet",
                    loop=False,
                    sort_order=2,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550a"),
                    name="起泡",
                    symbol="bubbles.and.sparkles",
                    angle=pi * 0.5,
                    radius=0.45,
                    initial_envelope=0.01,
                    layer="trigger",
                    resource_key="hair_wash_foam_start",
                    loop=False,
                    sort_order=3,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550b"),
                    name="泡沫揉洗",
                    symbol="hand.raised.fill",
                    angle=pi * 0.9,
                    radius=0.48,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_foam_rub",
                    sort_order=4,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550c"),
                    name="头皮按摩",
                    symbol="hand.point.up.left.fill",
                    angle=pi * 0.5,
                    radius=0.42,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_scalp_foam",
                    sort_order=5,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550d"),
                    name="冲洗",
                    symbol="shower.fill",
                    angle=pi * 0.7,
                    radius=0.58,
                    initial_envelope=0.01,
                    layer="trigger",
                    resource_key="hair_wash_rinse",
                    loop=False,
                    sort_order=6,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550e"),
                    name="指腹按压",
                    symbol="hand.tap.fill",
                    angle=pi * 0.5,
                    radius=0.4,
                    initial_envelope=0.01,
                    layer="ambience",
                    resource_key="hair_wash_finger_massage",
                    sort_order=7,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-55555555550f"),
                    name="毛巾",
                    symbol="rectangle.fill",
                    angle=pi * 0.55,
                    radius=0.5,
                    initial_envelope=0.01,
                    layer="trigger",
                    resource_key="hair_towel",
                    loop=False,
                    sort_order=8,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555503"),
                    name="轻声陪伴",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.25,
                    radius=0.36,
                    initial_envelope=0.48,
                    layer="voice",
                    resource_key="voice_phrase_mom",
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
                    radius=0.85,
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
                    radius=0.88,
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
                    radius=0.95,
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
            "name": "深林萤火",
            "subtitle": "风穿过树梢，微光停在夜色里。",
            "description": "林间微风与零星萤火交织，把呼吸带回更慢的节奏。",
            "category": "forest",
            "tags": ["森林", "微光"],
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
                _track(
                    track_id=_tid(10303),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.4,
                    radius=0.4,
                    initial_envelope=0.4,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111104"),
            "name": "雾岸听潮",
            "subtitle": "潮声从雾的另一边缓缓靠近。",
            "description": "远岸潮水起伏，雾气把世界推远一点，只留下规律的海声。",
            "category": "ocean",
            "tags": ["海洋", "雾"],
            "palette": _palette(0x1A2533, 0x3A4E63, 0x1C2430, 0xA8C4D8),
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
                _track(
                    track_id=_tid(10403),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.3,
                    radius=0.45,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
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
                _track(
                    track_id=_tid(10503),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 1.35,
                    radius=0.42,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111106"),
            "name": "月下静湖",
            "subtitle": "月光落在水面，夜色变得很薄。",
            "description": "静湖倒映月光，几乎没有多余的声音，只留下一层柔和的回响。",
            "category": "nature",
            "tags": ["月光", "湖"],
            "palette": _palette(0x10182A, 0x243552, 0x0C1018, 0xE8E2D0),
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
                _track(
                    track_id=_tid(10603),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 1.4,
                    radius=0.4,
                    initial_envelope=0.3,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111107"),
            "name": "星河远眠",
            "subtitle": "把目光交给很远的光。",
            "description": "星河缓慢流动，像把白天的嘈杂一点点推到天边。",
            "category": "lightMusic",
            "tags": ["星空", "空灵"],
            "palette": _palette(0x090B18, 0x1A1F3A, 0x0A0C16, 0x9AA6D8),
            "visual_style": "starRiver",
            "is_demo_playable": False,
            "sort_order": 6,
            "mock_listener_count": 1588,
            "tracks": [
                _track(
                    track_id=_tid(10701),
                    name="星声",
                    symbol="sparkles",
                    angle=pi * 0.6,
                    radius=0.75,
                    initial_envelope=0.35,
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10702),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.15,
                    radius=0.7,
                    initial_envelope=0.2,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
                _track(
                    track_id=_tid(10703),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 1.2,
                    radius=0.42,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111108"),
            "name": "暖灯陪伴",
            "subtitle": "房间不大，灯光刚刚好。",
            "description": "一盏暖灯、轻微人声与柔和钢琴，像有人静静坐在旁边。",
            "category": "companion",
            "tags": ["陪伴", "暖光"],
            "palette": _palette(0x2A1E16, 0x4A3424, 0x18120E, 0xE0A878),
            "visual_style": "warmLamp",
            "is_demo_playable": False,
            "sort_order": 7,
            "mock_listener_count": 2031,
            "tracks": [
                _track(
                    track_id=_tid(10801),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.15,
                    radius=0.35,
                    initial_envelope=0.55,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=0,
                ),
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
            "id": uuid.UUID("a1111111-1111-4111-8111-111111111109"),
            "name": "雪夜书房",
            "subtitle": "窗外落雪，纸页很静。",
            "description": "雪夜把世界盖软，书房里只剩细小的翻页与远处风声。",
            "category": "whisper",
            "tags": ["雪夜", "安静"],
            "palette": _palette(0x1A2230, 0x3A4658, 0x12161E, 0xD8DEE8),
            "visual_style": "snowStudy",
            "is_demo_playable": False,
            "sort_order": 8,
            "mock_listener_count": 687,
            "tracks": [
                _track(
                    track_id=_tid(10901),
                    name="雪声",
                    symbol="snowflake",
                    angle=pi * 0.7,
                    radius=0.65,
                    initial_envelope=0.5,
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(10902),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.75,
                    initial_envelope=0.3,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
                _track(
                    track_id=_tid(10903),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.35,
                    radius=0.4,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110a"),
            "name": "风过麦田",
            "subtitle": "风把白天的热气带走了。",
            "description": "麦浪轻轻起伏，风声开阔而不喧闹，适合想要一点空间感的夜晚。",
            "category": "nature",
            "tags": ["田野", "风"],
            "palette": _palette(0x1C2418, 0x3A4630, 0x141810, 0xC8B070),
            "visual_style": "wheatWind",
            "is_demo_playable": False,
            "sort_order": 9,
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
                _track(
                    track_id=_tid(11003),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.4,
                    radius=0.42,
                    initial_envelope=0.3,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110b"),
            "name": "云间呼吸",
            "subtitle": "跟着云层一起慢慢呼气。",
            "description": "柔和的呼吸引导与轻薄氛围声，帮助身体一点点松下来。",
            "category": "breath",
            "tags": ["呼吸", "放松"],
            "palette": _palette(0x182030, 0x2E3C52, 0x10161E, 0xA8B8D0),
            "visual_style": "cloudBreath",
            "is_demo_playable": False,
            "sort_order": 10,
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
                    track_id=_tid(11102),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 0.9,
                    radius=0.45,
                    initial_envelope=0.45,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=1,
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
            "name": "夏夜虫鸣",
            "subtitle": "院子里，夏天还没走远。",
            "description": "虫鸣层层叠叠，像夏天的夜还停在窗外，温柔而不打扰。",
            "category": "nature",
            "tags": ["夏夜", "虫鸣"],
            "palette": _palette(0x142018, 0x243828, 0x101410, 0x88C878),
            "visual_style": "summerInsects",
            "is_demo_playable": False,
            "sort_order": 11,
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
                _track(
                    track_id=_tid(11203),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.35,
                    radius=0.42,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=2,
                ),
            ],
        },
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110d"),
            "name": "炉边低语",
            "subtitle": "火光轻轻说着不重要的事。",
            "description": "炉火细碎作响，低语与暖色把夜晚收得很近。",
            "category": "companion",
            "tags": ["炉火", "低语"],
            "palette": _palette(0x241810, 0x4A2C1A, 0x140E0A, 0xE09060),
            "visual_style": "fireplaceWhisper",
            "is_demo_playable": False,
            "sort_order": 12,
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
                    track_id=_tid(11302),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=-pi * 0.25,
                    radius=0.38,
                    initial_envelope=0.5,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=1,
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
        {
            "id": uuid.UUID("a1111111-1111-4111-8111-11111111110e"),
            "name": "流光溢彩",
            "subtitle": "颜色在呼吸，像一团安静的情绪。",
            "description": (
                "缓慢流动的情绪色彩空间。云雾、水波与暖焰轮转，"
                "没有文字打扰，只留下疗愈般的光色。"
            ),
            "category": "lightMusic",
            "tags": ["色彩", "助眠", "氛围"],
            "palette": _palette(0x24324A, 0x4B4668, 0x163A4A, 0xE8DCC5),
            "visual_style": "emotionalFluid",
            "is_demo_playable": True,
            "sort_order": 13,
            "mock_listener_count": 426,
            "tracks": [
                _track(
                    track_id=_tid(11401),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.72,
                    initial_envelope=0.35,
                    layer="ambience",
                    resource_key="wind_realistic",
                    sort_order=0,
                ),
                _track(
                    track_id=_tid(11402),
                    name="雨声",
                    symbol="cloud.rain.fill",
                    angle=pi * 0.85,
                    radius=0.58,
                    initial_envelope=0.4,
                    resource_key="rain_soft",
                    sort_order=1,
                ),
                _track(
                    track_id=_tid(11403),
                    name="潮声",
                    symbol="water.waves",
                    angle=pi * 1.15,
                    radius=0.65,
                    initial_envelope=0.45,
                    resource_key="stream_nature",
                    sort_order=2,
                ),
                _track(
                    track_id=_tid(11404),
                    name="钢琴",
                    symbol="pianokeys",
                    angle=-pi * 0.35,
                    radius=0.5,
                    initial_envelope=0.28,
                    layer="ambience",
                    resource_key=None,
                    enabled=False,
                    sort_order=3,
                ),
                _track(
                    track_id=_tid(11405),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 1.4,
                    radius=0.4,
                    initial_envelope=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    enabled=False,
                    sort_order=4,
                ),
            ],
        },
    ]


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
                    "name": "底噪",
                    "symbolName": "wind.circle.fill",
                    "resourceName": "ac_hum",
                    "layer": "ambience",
                    "position": {"angle": math.pi * 1.2, "radius": 0.82},
                },
                {
                    "name": "轻声陪伴",
                    "symbolName": "person.wave.2.fill",
                    "resourceName": "voice_phrase_mom",
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
                    "position": {"angle": -0.35, "radius": 0.85},
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
                    "position": {"angle": -1.2, "radius": 0.88},
                },
                {
                    "name": "阵风",
                    "symbolName": "wind",
                    "resourceName": "wind_gust",
                    "layer": "trigger",
                    "position": {"angle": -2.4, "radius": 0.95},
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
    """Upsert official scene metadata/tracks/presets by id. Does not delete orphan tracks."""
    tracks_inserted = 0
    tracks_updated = 0
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

    When ``refresh_tracks`` is true, also upsert official track/preset fields (no deletes).
    """
    existing_scene_ids = set(await session.scalars(select(Scene.id)))
    existing_preset_ids = set(await session.scalars(select(MixPreset.id)))
    added = False

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
