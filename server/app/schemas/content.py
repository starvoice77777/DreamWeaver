from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class SpatialPositionOut(BaseModel):
    angle: float
    radius: float


class SceneTrackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    symbol_name: str
    layer: str
    volume: float
    position: SpatialPositionOut
    resource_key: str | None = None
    loop: bool = True
    enabled_by_default: bool = True


class ScenePaletteOut(BaseModel):
    top: int
    mid: int
    bottom: int
    accent: int


class SceneSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    subtitle: str
    description: str
    category: str
    tags: list[str]
    palette: ScenePaletteOut
    visual_style: str
    recommended_duration_seconds: int
    is_demo_playable: bool
    mock_listener_count: int
    sort_order: int


class SceneDetailOut(SceneSummaryOut):
    tracks: list[SceneTrackOut] = Field(default_factory=list)


class VoiceBindingOut(BaseModel):
    """Where a phrase gets its audio from."""

    kind: str = Field(description="official_resource | system | authorized_asset")
    resource_key: str | None = None
    asset_id: uuid.UUID | None = None
    track_id: uuid.UUID | None = None
    track_layer: str | None = "voice"


class PhraseOut(BaseModel):
    id: uuid.UUID
    text: str
    review_status: str = Field(description="draft | pending | approved | rejected")
    voice_binding: VoiceBindingOut


class CueActionOut(BaseModel):
    """Client-executed action. Unknown types should be ignored by older clients."""

    type: str = Field(
        description=(
            "play_phrase | play_oneshot | play | pause | fade_in | fade_out | set_volume | "
            "set_position | enable | disable | replace_source"
        )
    )
    phrase_id: uuid.UUID | None = None
    track_id: uuid.UUID | None = None
    volume: float | None = Field(default=None, ge=0, le=1)
    fade_ms: int | None = Field(default=None, ge=0)
    angle: float | None = None
    radius: float | None = Field(default=None, ge=0, le=1)
    resource_key: str | None = None


class SceneCueOut(BaseModel):
    id: uuid.UUID
    at_seconds: float | None = Field(
        default=None, description="Wall-clock offset from scene start; mutually exclusive with progress"
    )
    progress: float | None = Field(
        default=None, ge=0, le=1, description="Normalized session/text progress 0…1"
    )
    repeat_every_seconds: float | None = Field(default=None, ge=0)
    until_seconds: float | None = Field(default=None, ge=0)
    actions: list[CueActionOut] = Field(default_factory=list)


class SceneTimelineOut(BaseModel):
    scene_id: uuid.UUID
    version: int
    automation_mode: str = Field(description="official_auto | manual")
    duration_hint_seconds: int | None = None
    override_policy: str = Field(
        default="per_source_manual_exit",
        description="Manual edits on a source exit official automation for that source only",
    )
    manual_override_track_ids: list[uuid.UUID] = Field(
        default_factory=list,
        description="Tracks that exited official automation after user edits",
    )
    phrases: list[PhraseOut] = Field(default_factory=list)
    cues: list[SceneCueOut] = Field(default_factory=list)


class MixPresetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    style_hint: str | None = None
    author_name: str
    sources: list[dict]
    scene_id: uuid.UUID | None = None


class UserSettingsOut(BaseModel):
    reduce_motion: bool = False
    auto_play_enabled: bool = True
    background_play_enabled: bool = True
    lock_screen_play_enabled: bool = True
    animation_intensity: float = 0.7
    dark_mode_forced: bool = True
    audio_quality: str = "标准"
    notifications_enabled: bool = False
    default_scene_id: uuid.UUID | None = None


class BootstrapOut(BaseModel):
    greeting: str
    default_scene_id: uuid.UUID
    scenes: list[SceneSummaryOut]
    settings: UserSettingsOut
    server_time: datetime
    api_version: str = "v1"


class AppleAuthRequest(BaseModel):
    identity_token: str = Field(min_length=1)
    nickname: str | None = Field(default=None, max_length=64)
    device_label: str | None = Field(default=None, max_length=128)
    # Raw nonce from the client; compared to the JWT claim (or SHA-256 hex of it).
    nonce: str | None = Field(default=None, max_length=256)


class AuthTokensOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user_id: uuid.UUID
    nickname: str


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class UserSettingsUpdate(BaseModel):
    reduce_motion: bool | None = None
    auto_play_enabled: bool | None = None
    background_play_enabled: bool | None = None
    lock_screen_play_enabled: bool | None = None
    animation_intensity: float | None = Field(default=None, ge=0, le=1)
    dark_mode_forced: bool | None = None
    audio_quality: str | None = Field(default=None, max_length=32)
    notifications_enabled: bool | None = None
    default_scene_id: uuid.UUID | None = None


class SceneStatePatch(BaseModel):
    is_favorite: bool | None = None
    mark_opened: bool = False


class SceneStateOut(BaseModel):
    scene_id: uuid.UUID
    is_favorite: bool
    last_opened_at: datetime | None = None
    listen_count: int


class PrivateSceneSummaryOut(BaseModel):
    id: uuid.UUID
    name: str
    subtitle: str
    description: str
    category: str
    tags: list[str]
    visual_style: str
    source_scene_id: uuid.UUID | None = None
    has_saved_version: bool
    saved_version: int
    saved_at: datetime | None = None
    updated_at: datetime


class PrivateSceneDetailOut(PrivateSceneSummaryOut):
    palette: dict
    recommended_duration_seconds: int
    draft_sources: list[dict] = Field(default_factory=list)
    saved_sources: list[dict] | None = None
    draft_timeline: dict | None = None
    saved_timeline: dict | None = None


class PrivateSceneCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    subtitle: str = ""
    description: str = ""
    category: str = "personal"
    tags: list[str] = Field(default_factory=list)
    palette: dict | None = None
    visual_style: str = "custom"
    sources: list[dict] = Field(default_factory=list)
    timeline: dict | None = None


class PrivateSceneDraftUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    subtitle: str | None = None
    description: str | None = None
    category: str | None = None
    tags: list[str] | None = None
    palette: dict | None = None
    visual_style: str | None = None
    sources: list[dict] | None = None
    draft_timeline: dict | None = None


class HomeOut(BaseModel):
    greeting_scene_id: uuid.UUID
    recommended: list[SceneSummaryOut]
    recent: list[SceneSummaryOut]
    favorites: list[SceneSummaryOut]
    private_scenes: list[PrivateSceneSummaryOut]
