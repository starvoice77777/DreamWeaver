"""Scene timeline (cue / phrase) reads and official catalog seeding."""

from __future__ import annotations

import json
import uuid
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Scene, SceneTimeline
from app.schemas.content import (
    PhraseOut,
    SceneCueOut,
    SceneTimelineOut,
)

VOICE_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555503")
AC_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555506")

HAIR_CARE_TIMELINE_VERSION = 12
RAIN_EAVES_TIMELINE_VERSION = 10
GENERIC_TIMELINE_VERSION = 2
_HAIR_FIXTURE_PATH = (
    Path(__file__).resolve().parent.parent / "fixtures" / "hair_care_timeline_v11.json"
)
_RAIN_FIXTURE_PATH = (
    Path(__file__).resolve().parent.parent / "fixtures" / "rain_eaves_timeline_v8.json"
)


def timeline_to_out(row: SceneTimeline) -> SceneTimelineOut:
    phrases = [PhraseOut.model_validate(item) for item in (row.phrases or [])]
    cues = [SceneCueOut.model_validate(item) for item in (row.cues or [])]
    return SceneTimelineOut(
        scene_id=row.scene_id,
        version=row.version,
        automation_mode=row.automation_mode,
        duration_hint_seconds=row.duration_hint_seconds,
        override_policy=row.override_policy,
        manual_override_track_ids=[],
        phrases=phrases,
        cues=cues,
    )


def timeline_document_dict(out: SceneTimelineOut) -> dict:
    """Serialize timeline for private-scene JSON columns."""
    return out.model_dump(mode="json")


def _load_fixture(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    out = SceneTimelineOut.model_validate(raw)
    return {
        "version": out.version,
        "automation_mode": out.automation_mode,
        "duration_hint_seconds": out.duration_hint_seconds,
        "override_policy": out.override_policy,
        "phrases": [p.model_dump(mode="json") for p in out.phrases],
        "cues": [c.model_dump(mode="json") for c in out.cues],
    }


def _load_hair_care_fixture() -> dict:
    return _load_fixture(_HAIR_FIXTURE_PATH)


def _load_rain_eaves_fixture() -> dict:
    return _load_fixture(_RAIN_FIXTURE_PATH)


def _empty_document() -> tuple[list[dict], list[dict]]:
    return [], []


def build_official_timeline_payload(scene: Scene) -> dict:
    duration = scene.recommended_duration_seconds or 2700
    if scene.visual_style == "hairCare":
        # Fixture is authoritative (script length + cues); do not override
        # with stale scene duration.
        payload = _load_hair_care_fixture()
        return {
            "version": payload["version"],
            "automation_mode": payload["automation_mode"],
            "duration_hint_seconds": payload["duration_hint_seconds"],
            "override_policy": payload["override_policy"],
            "phrases": payload["phrases"],
            "cues": payload["cues"],
        }
    if scene.visual_style == "rainEaves":
        payload = _load_rain_eaves_fixture()
        return {
            "version": payload["version"],
            "automation_mode": payload["automation_mode"],
            "duration_hint_seconds": payload["duration_hint_seconds"],
            "override_policy": payload["override_policy"],
            "phrases": payload["phrases"],
            "cues": payload["cues"],
        }

    # Bundled narration is exclusive to hair care. All other official scenes
    # intentionally have no phrase hooks, even if stale DB rows still contain
    # a legacy voice track before the catalog cleanup migration runs.
    phrases, cues = _empty_document()
    version = GENERIC_TIMELINE_VERSION

    return {
        "version": version,
        "automation_mode": "official_auto",
        "duration_hint_seconds": duration,
        "override_policy": "per_source_manual_exit",
        "phrases": phrases,
        "cues": cues,
    }


async def ensure_official_timelines(session: AsyncSession) -> None:
    """Insert missing timelines and refresh changed official fixture contracts."""
    from sqlalchemy.orm import selectinload

    result = await session.scalars(
        select(Scene)
        .where(Scene.is_published.is_(True))
        .options(selectinload(Scene.tracks), selectinload(Scene.timeline))
    )
    scenes = list(result.all())
    dirty = False
    for scene in scenes:
        payload = build_official_timeline_payload(scene)
        row = scene.timeline
        if row is None:
            session.add(
                SceneTimeline(
                    scene_id=scene.id,
                    version=payload["version"],
                    automation_mode=payload["automation_mode"],
                    duration_hint_seconds=payload["duration_hint_seconds"],
                    override_policy=payload["override_policy"],
                    phrases=payload["phrases"],
                    cues=payload["cues"],
                )
            )
            dirty = True
            continue
        needs_upgrade = (
            scene.visual_style == "hairCare" and row.version < HAIR_CARE_TIMELINE_VERSION
        ) or (scene.visual_style == "rainEaves" and row.version < RAIN_EAVES_TIMELINE_VERSION)
        needs_upgrade = needs_upgrade or (
            scene.visual_style not in {"hairCare", "rainEaves"}
            and (row.version < GENERIC_TIMELINE_VERSION or bool(row.phrases))
        )
        if needs_upgrade:
            row.version = payload["version"]
            row.automation_mode = payload["automation_mode"]
            row.duration_hint_seconds = payload["duration_hint_seconds"]
            row.override_policy = payload["override_policy"]
            row.phrases = payload["phrases"]
            row.cues = payload["cues"]
            if payload.get("duration_hint_seconds"):
                scene.recommended_duration_seconds = payload["duration_hint_seconds"]
            dirty = True
    if dirty:
        await session.commit()


async def get_timeline(session: AsyncSession, scene_id: uuid.UUID) -> SceneTimelineOut | None:
    from app.services.seed_catalog import ensure_official_catalog

    await ensure_official_catalog(session)
    await ensure_official_timelines(session)

    scene = await session.scalar(
        select(Scene).where(Scene.id == scene_id, Scene.is_published.is_(True))
    )
    if scene is None:
        return None

    row = await session.scalar(select(SceneTimeline).where(SceneTimeline.scene_id == scene_id))
    if row is None:
        # Should not happen after ensure; return empty contract shell.
        return SceneTimelineOut(
            scene_id=scene_id,
            version=1,
            automation_mode="official_auto",
            duration_hint_seconds=scene.recommended_duration_seconds,
            override_policy="per_source_manual_exit",
            manual_override_track_ids=[],
            phrases=[],
            cues=[],
        )
    return timeline_to_out(row)
