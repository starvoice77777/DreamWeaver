from __future__ import annotations

import math
import uuid

from sqlalchemy import func, select
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


def _track(
    *,
    track_id: uuid.UUID,
    name: str,
    symbol: str,
    angle: float,
    radius: float,
    volume: float,
    layer: str = "environment",
    resource_key: str | None = None,
    enabled: bool = True,
    sort_order: int = 0,
) -> dict:
    return {
        "id": track_id,
        "name": name,
        "symbol_name": symbol,
        "layer": layer,
        "volume": volume,
        "angle": angle,
        "radius": radius,
        "resource_key": resource_key,
        "enabled_by_default": enabled,
        "sort_order": sort_order,
    }


def official_scene_specs() -> list[dict]:
    pi = math.pi
    return [
        {
            "id": DEFAULT_SCENE_ID,
            "name": "洗头陪伴",
            "subtitle": "水流与暖风轻轻围着你。",
            "description": "洗头时的水流、吹风机与空调底噪交织，适合被温柔带着入睡。",
            "category": "companion",
            "tags": ["陪伴", "生活"],
            "palette": _palette(0x1B2A3A, 0x2F4458, 0x1A1412, 0xE0B089),
            "visual_style": "hairCare",
            "is_demo_playable": True,
            "sort_order": 0,
            "mock_listener_count": 2860,
            "tracks": [
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555504"),
                    name="水流",
                    symbol="drop.fill",
                    angle=pi * 0.85,
                    radius=0.5,
                    volume=0.72,
                    resource_key="hair_wash",
                    sort_order=0,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555505"),
                    name="吹风机",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.62,
                    volume=0.4,
                    resource_key="hair_dryer",
                    sort_order=1,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555506"),
                    name="空调",
                    symbol="fan",
                    angle=-pi * 0.35,
                    radius=0.78,
                    volume=0.28,
                    resource_key="ac_hum",
                    sort_order=2,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555503"),
                    name="人声",
                    symbol="person.wave.2.fill",
                    angle=pi * 1.25,
                    radius=0.42,
                    volume=0.35,
                    layer="voice",
                    resource_key="voice_phrase_mom",
                    sort_order=3,
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
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555501"),
                    name="雨声",
                    symbol="cloud.rain.fill",
                    angle=pi * 0.85,
                    radius=0.62,
                    volume=0.78,
                    resource_key="rain_soft",
                    sort_order=0,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555502"),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.2,
                    radius=0.72,
                    volume=0.35,
                    resource_key="wind_realistic",
                    sort_order=1,
                ),
                _track(
                    track_id=uuid.UUID("e5555555-5555-4555-8555-555555555507"),
                    name="钢琴",
                    symbol="pianokeys",
                    angle=pi * 1.25,
                    radius=0.58,
                    volume=0.28,
                    layer="music",
                    sort_order=2,
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
            "tags": ["森林", "安静"],
            "palette": _palette(0x102418, 0x1C3A28, 0x0C1410, 0xA8C989),
            "visual_style": "fireflies",
            "is_demo_playable": False,
            "sort_order": 2,
            "mock_listener_count": 942,
            "tracks": [
                _track(
                    track_id=uuid.uuid4(),
                    name="风声",
                    symbol="wind",
                    angle=pi * 0.15,
                    radius=0.7,
                    volume=0.65,
                    resource_key="wind_realistic",
                    sort_order=0,
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
                    "name": "水流",
                    "symbolName": "drop.fill",
                    "volume": 0.7,
                    "resourceName": "hair_wash",
                    "layer": "environment",
                },
                {
                    "name": "人声",
                    "symbolName": "person.wave.2.fill",
                    "volume": 0.4,
                    "resourceName": "voice_phrase_mom",
                    "layer": "voice",
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
                    "name": "雨声",
                    "symbolName": "cloud.rain.fill",
                    "volume": 0.8,
                    "resourceName": "rain_soft",
                    "layer": "environment",
                },
                {
                    "name": "风声",
                    "symbolName": "wind",
                    "volume": 0.3,
                    "resourceName": "wind_realistic",
                    "layer": "environment",
                },
            ],
        },
    ]


async def ensure_official_catalog(session: AsyncSession) -> None:
    count = await session.scalar(select(func.count()).select_from(Scene))
    if count and count > 0:
        return

    for spec in official_scene_specs():
        tracks = spec.pop("tracks")
        scene = Scene(**spec)
        session.add(scene)
        for index, track_spec in enumerate(tracks):
            session.add(
                SceneTrack(
                    scene_id=scene.id,
                    id=track_spec["id"],
                    name=track_spec["name"],
                    symbol_name=track_spec["symbol_name"],
                    layer=track_spec["layer"],
                    volume=track_spec["volume"],
                    angle=track_spec["angle"],
                    radius=track_spec["radius"],
                    resource_key=track_spec["resource_key"],
                    enabled_by_default=track_spec["enabled_by_default"],
                    sort_order=track_spec.get("sort_order", index),
                )
            )

    for preset in official_preset_specs():
        session.add(MixPreset(**preset))

    await session.commit()
