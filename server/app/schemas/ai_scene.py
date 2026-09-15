"""Typed request and stage-result contracts for AI-assisted scene creation."""

from __future__ import annotations

import math
import uuid
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Layer = Literal["environment", "ambience", "trigger", "voice"]
SceneRole = Literal["bed", "ambience", "action", "trigger", "voice", "transition"]
CompositionProfile = Literal[
    "environment_led", "balanced_hybrid", "trigger_led", "voice_led"
]
ForegroundPriority = Literal["environment", "environment_and_detail", "trigger", "voice"]
TriggerFocus = Literal["none", "supporting_detail", "primary_object_sound"]
DurationPolicy = Literal["asset_budgeted", "continuous_loop", "script_bounded"]
SpatialPolicy = Literal["layer_specific", "mostly_fixed", "headphone_motion"]
TriggerMode = Literal["none", "episodic", "continuous"]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SelectedSourceIn(StrictModel):
    source_id: uuid.UUID
    resource_key: str = Field(min_length=1, max_length=128, pattern=r"^[a-z0-9_]+$")
    name: str = Field(min_length=1, max_length=128)
    description: str = Field(min_length=1, max_length=2_000)
    layer: Layer
    loop: bool
    duration_seconds: float = Field(gt=0, le=86_400)
    default_volume: float = Field(ge=0, le=1)
    angle: float = Field(ge=-math.pi, le=math.pi, description="Radians")
    radius: float = Field(ge=0, le=1)


class SceneAssistOptions(StrictModel):
    scene_intent: str | None = Field(default=None, min_length=1, max_length=2_000)
    duration_seconds: float | None = Field(default=None, gt=0, le=86_400)
    language: str = Field(default="zh-CN", min_length=2, max_length=32)
    constraints: list[str] = Field(default_factory=list, max_length=50)

    @model_validator(mode="before")
    @classmethod
    def normalize_constraint(cls, value: object) -> object:
        if isinstance(value, dict) and isinstance(value.get("constraints"), str):
            normalized = dict(value)
            normalized["constraints"] = [value["constraints"]]
            return normalized
        return value


class OutlineSection(StrictModel):
    name: str = Field(min_length=1, max_length=128)
    description: str = Field(default="", max_length=1_000)
    start_seconds: float = Field(ge=0)
    end_seconds: float = Field(gt=0)
    active_roles: list[SceneRole] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_window(self) -> OutlineSection:
        if self.end_seconds <= self.start_seconds:
            raise ValueError("end_seconds must be greater than start_seconds")
        return self


class SceneOutline(StrictModel):
    name: str = Field(min_length=1, max_length=128)
    subtitle: str = Field(default="", max_length=256)
    description: str = Field(min_length=1, max_length=2_000)
    theme: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_]+$")
    use_case_tags: list[str] = Field(min_length=1)
    composition_profile: CompositionProfile
    foreground_priority: ForegroundPriority
    trigger_focus: TriggerFocus
    duration_policy: DurationPolicy
    spatial_policy: SpatialPolicy
    trigger_mode: TriggerMode
    sections: list[OutlineSection] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_sections(self) -> SceneOutline:
        previous_end = -1.0
        for section in self.sections:
            if section.start_seconds < previous_end:
                raise ValueError("sections must be chronological and non-overlapping")
            previous_end = section.end_seconds
        return self


class SpatialKeyframe(StrictModel):
    t: float = Field(ge=0)
    angle: float = Field(ge=-math.pi, le=math.pi, description="Radians")
    radius: float = Field(ge=0, le=1)
    interpolation: Literal["linear", "smoothstep", "recorded_linear"] = "smoothstep"


class ArrangementTrack(StrictModel):
    source_id: uuid.UUID | None = None
    resource_key: str | None = Field(
        default=None, min_length=1, max_length=128, pattern=r"^[a-z0-9_]+$"
    )
    role: SceneRole
    start_seconds: float = Field(ge=0)
    end_seconds: float = Field(gt=0)
    loop: bool
    default_volume: float = Field(ge=0, le=1)
    fade_in_ms: int = Field(default=0, ge=0, le=2_000)
    fade_out_ms: int = Field(default=0, ge=0, le=2_000)
    keyframes: list[SpatialKeyframe] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_track(self) -> ArrangementTrack:
        if self.source_id is None and self.resource_key is None:
            raise ValueError("source_id or resource_key is required")
        if self.end_seconds <= self.start_seconds:
            raise ValueError("end_seconds must be greater than start_seconds")
        previous = -1.0
        for keyframe in self.keyframes:
            if keyframe.t < self.start_seconds or keyframe.t > self.end_seconds:
                raise ValueError("keyframe t must be inside the track time window")
            if keyframe.t <= previous:
                raise ValueError("keyframe t values must be strictly increasing")
            previous = keyframe.t
        duration_ms = (self.end_seconds - self.start_seconds) * 1_000
        if self.fade_in_ms + self.fade_out_ms > duration_ms:
            raise ValueError("combined fades must not exceed the track duration")
        return self


class ArrangementPlan(StrictModel):
    tracks: list[ArrangementTrack] = Field(min_length=1)


class OutlineRequest(StrictModel):
    selected_sources: list[SelectedSourceIn] = Field(min_length=1, max_length=64)
    options: SceneAssistOptions = Field(default_factory=SceneAssistOptions)


class ArrangementRequest(OutlineRequest):
    outline: SceneOutline


class CompileRequest(ArrangementRequest):
    arrangement: ArrangementPlan


class GenerateRequest(OutlineRequest):
    pass


class AdjustRequest(StrictModel):
    selected_sources: list[SelectedSourceIn] = Field(min_length=1, max_length=64)
    scene: dict[str, Any]
    instruction: str = Field(min_length=1, max_length=4_000)
    options: SceneAssistOptions = Field(default_factory=SceneAssistOptions)


class SceneAssistResult(StrictModel):
    outline: SceneOutline
    arrangement: ArrangementPlan
    scene: dict[str, Any]
    composition: dict[str, Any]
    validation_warnings: list[str] = Field(default_factory=list)


class SceneAdjustResult(StrictModel):
    scene: dict[str, Any]
    composition: dict[str, Any]
    change_summary: list[str] = Field(default_factory=list)
    validation_warnings: list[str] = Field(default_factory=list)
