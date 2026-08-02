"""Scene timeline (cue / phrase) reads and official catalog seeding."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Scene, SceneTimeline
from app.schemas.content import (
    CueActionOut,
    PhraseOut,
    SceneCueOut,
    SceneTimelineOut,
    VoiceBindingOut,
)

VOICE_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555503")
DRYER_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555505")
WASH_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555504")
AC_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555506")

RAIN_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555501")
WIND_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555502")

# Stable phrase/cue ids so clients can cache by id across restarts.
PHRASE_MOM_ID = uuid.UUID("f6666666-6666-4666-8666-666666666601")
CUE_FIRST_PHRASE_ID = uuid.UUID("f6666666-6666-4666-8666-666666666611")
CUE_REPEAT_PHRASE_ID = uuid.UUID("f6666666-6666-4666-8666-666666666612")
CUE_SOFTEN_DRYER_ID = uuid.UUID("f6666666-6666-4666-8666-666666666613")
CUE_NIGHT_PROGRESS_ID = uuid.UUID("f6666666-6666-4666-8666-666666666614")
CUE_RAIN_SETTLE_ID = uuid.UUID("f6666666-6666-4666-8666-666666666621")
CUE_WIND_SOFTEN_ID = uuid.UUID("f6666666-6666-4666-8666-666666666622")


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



def _hair_care_document(duration_hint: int) -> tuple[list[dict], list[dict]]:
    """Mirrors current iOS LocalPlaybackService voice cadence (6s then every 28s)."""
    phrases = [
        PhraseOut(
            id=PHRASE_MOM_ID,
            text="睡吧，我在。",
            review_status="approved",
            voice_binding=VoiceBindingOut(
                kind="official_resource",
                resource_key="voice_phrase_mom",
                track_id=VOICE_TRACK_ID,
                track_layer="voice",
            ),
        ).model_dump(mode="json")
    ]
    cues = [
        SceneCueOut(
            id=CUE_FIRST_PHRASE_ID,
            at_seconds=6.0,
            actions=[
                CueActionOut(type="play_phrase", phrase_id=PHRASE_MOM_ID, track_id=VOICE_TRACK_ID)
            ],
        ).model_dump(mode="json"),
        SceneCueOut(
            id=CUE_REPEAT_PHRASE_ID,
            at_seconds=34.0,
            repeat_every_seconds=28.0,
            until_seconds=float(duration_hint),
            actions=[
                CueActionOut(type="play_phrase", phrase_id=PHRASE_MOM_ID, track_id=VOICE_TRACK_ID)
            ],
        ).model_dump(mode="json"),
        SceneCueOut(
            id=CUE_SOFTEN_DRYER_ID,
            at_seconds=180.0,
            actions=[
                CueActionOut(
                    type="set_volume",
                    track_id=DRYER_TRACK_ID,
                    volume=0.18,
                    fade_ms=4000,
                )
            ],
        ).model_dump(mode="json"),
        SceneCueOut(
            id=CUE_NIGHT_PROGRESS_ID,
            progress=0.85,
            actions=[
                CueActionOut(
                    type="fade_out",
                    track_id=WASH_TRACK_ID,
                    fade_ms=8000,
                ),
                CueActionOut(
                    type="set_volume",
                    track_id=AC_TRACK_ID,
                    volume=0.15,
                    fade_ms=6000,
                ),
            ],
        ).model_dump(mode="json"),
    ]
    return phrases, cues


def _empty_document() -> tuple[list[dict], list[dict]]:
    return [], []


def _rain_eaves_document() -> tuple[list[dict], list[dict]]:
    """Non-voice demo scene: gentle environment automation only."""
    phrases: list[dict] = []
    cues = [
        SceneCueOut(
            id=CUE_RAIN_SETTLE_ID,
            at_seconds=90.0,
            actions=[
                CueActionOut(
                    type="set_volume",
                    track_id=RAIN_TRACK_ID,
                    volume=0.65,
                    fade_ms=5000,
                )
            ],
        ).model_dump(mode="json"),
        SceneCueOut(
            id=CUE_WIND_SOFTEN_ID,
            at_seconds=240.0,
            actions=[
                CueActionOut(
                    type="set_volume",
                    track_id=WIND_TRACK_ID,
                    volume=0.22,
                    fade_ms=6000,
                )
            ],
        ).model_dump(mode="json"),
    ]
    return phrases, cues


def build_official_timeline_payload(scene: Scene) -> dict:
    duration = scene.recommended_duration_seconds or 2700
    if scene.visual_style == "hairCare":
        phrases, cues = _hair_care_document(duration)
        version = 1
    elif scene.visual_style == "rainEaves":
        phrases, cues = _rain_eaves_document()
        version = 1
    else:
        # Scenes with a voice layer get a minimal approved phrase hook; others stay empty.
        voice_tracks = [t for t in scene.tracks if t.layer == "voice" and t.resource_key]
        if voice_tracks:
            track = voice_tracks[0]
            phrase_id = uuid.uuid5(scene.id, "official-phrase-0")
            phrases = [
                PhraseOut(
                    id=phrase_id,
                    text="",
                    review_status="approved",
                    voice_binding=VoiceBindingOut(
                        kind="official_resource",
                        resource_key=track.resource_key,
                        track_id=track.id,
                        track_layer="voice",
                    ),
                ).model_dump(mode="json")
            ]
            cues = [
                SceneCueOut(
                    id=uuid.uuid5(scene.id, "official-cue-first"),
                    at_seconds=6.0,
                    actions=[
                        CueActionOut(
                            type="play_phrase",
                            phrase_id=phrase_id,
                            track_id=track.id,
                        )
                    ],
                ).model_dump(mode="json"),
                SceneCueOut(
                    id=uuid.uuid5(scene.id, "official-cue-repeat"),
                    at_seconds=34.0,
                    repeat_every_seconds=28.0,
                    until_seconds=float(duration),
                    actions=[
                        CueActionOut(
                            type="play_phrase",
                            phrase_id=phrase_id,
                            track_id=track.id,
                        )
                    ],
                ).model_dump(mode="json"),
            ]
            version = 1
        else:
            phrases, cues = _empty_document()
            version = 1

    return {
        "version": version,
        "automation_mode": "official_auto",
        "duration_hint_seconds": duration,
        "override_policy": "per_source_manual_exit",
        "phrases": phrases,
        "cues": cues,
    }


async def ensure_official_timelines(session: AsyncSession) -> None:
    """Insert missing timelines for published scenes (idempotent)."""
    from sqlalchemy.orm import selectinload

    result = await session.scalars(
        select(Scene)
        .where(Scene.is_published.is_(True))
        .options(selectinload(Scene.tracks), selectinload(Scene.timeline))
    )
    scenes = list(result.all())
    added = False
    for scene in scenes:
        if scene.timeline is not None:
            continue
        payload = build_official_timeline_payload(scene)
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
        added = True
    if added:
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
