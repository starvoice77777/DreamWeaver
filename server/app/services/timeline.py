"""Scene timeline (cue / phrase) reads and official catalog seeding."""

from __future__ import annotations

import json
import uuid
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Scene, SceneTimeline
from app.schemas.content import (
    PhraseOut,
    SceneCueOut,
    SceneTimelineOut,
)
from app.services.handoff_presets import FIXTURES, review_preset

VOICE_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555503")
AC_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555506")

HAIR_CARE_TIMELINE_VERSION = 12
RAIN_EAVES_TIMELINE_VERSION = 12
GENERIC_TIMELINE_VERSION = 2
_HAIR_FIXTURE_PATH = (
    Path(__file__).resolve().parent.parent / "fixtures" / "hair_care_timeline_v11.json"
)
_RAIN_FIXTURE_PATH = (
    Path(__file__).resolve().parent.parent / "fixtures" / "rain_eaves_timeline_v12.json"
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
    return _timeline_payload(json.loads(path.read_text(encoding="utf-8")))


def _timeline_payload(raw: dict[str, Any]) -> dict[str, Any]:
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
    if scene.id in FIXTURES:
        if preset := review_preset(scene.id):
            return _timeline_payload(preset["timeline"])
        duration = 2700  # Clear a prior review duration when the gate is disabled.
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
        review_changed = False
        if scene.id in FIXTURES:
            from app.services.seed_catalog import (
                official_scene_specs,
                refresh_official_scene_tracks,
            )

            spec = next(s for s in official_scene_specs() if s["id"] == scene.id)
            review_changed = (
                row is None
                or row.version != payload["version"]
                or {t.id for t in scene.tracks} != {t["id"] for t in spec["tracks"]}
            )
            if review_changed:
                refresh_official_scene_tracks(scene, spec)
                for key in ("name", "subtitle", "description", "tags", "is_demo_playable"):
                    setattr(scene, key, spec[key])
                scene.recommended_duration_seconds = payload["duration_hint_seconds"]
        if scene.visual_style == "rainEaves" and (
            row is None or row.version < RAIN_EAVES_TIMELINE_VERSION
        ):
            from app.services.seed_catalog import refresh_official_scene_tracks

            refresh_official_scene_tracks(scene)
            scene.recommended_duration_seconds = payload["duration_hint_seconds"]
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
        if needs_upgrade or review_changed:
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
