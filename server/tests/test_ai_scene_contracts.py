import math
import uuid

import pytest
from pydantic import ValidationError

from app.schemas.ai_scene import (
    AdjustRequest,
    ArrangementPlan,
    ArrangementRequest,
    ArrangementTrack,
    CompileRequest,
    GenerateRequest,
    OutlineRequest,
    OutlineSection,
    SceneAssistOptions,
    SceneOutline,
    SelectedSourceIn,
    SpatialKeyframe,
)
from app.services.ai_scene_prompts import (
    build_adjust_prompts,
    build_arrangement_prompts,
    build_compile_prompts,
    build_outline_prompts,
)


def source() -> SelectedSourceIn:
    return SelectedSourceIn(
        source_id=uuid.uuid4(),
        resource_key="rain_soft",
        name="Rain",
        description="A distant soft rain bed",
        layer="environment",
        loop=True,
        duration_seconds=12.5,
        default_volume=0.3,
        angle=0.0,
        radius=0.8,
    )


def outline() -> SceneOutline:
    return SceneOutline(
        name="Quiet Rain",
        subtitle="Rain at a distance",
        description="A steady sleep-oriented rain scene.",
        theme="rain_room",
        use_case_tags=["sleep"],
        composition_profile="environment_led",
        foreground_priority="environment",
        trigger_focus="none",
        duration_policy="asset_budgeted",
        spatial_policy="mostly_fixed",
        trigger_mode="none",
        sections=[
            OutlineSection(name="settle", start_seconds=0, end_seconds=60)
        ],
    )


def arrangement() -> ArrangementPlan:
    selected = source()
    return ArrangementPlan(
        tracks=[
            ArrangementTrack(
                source_id=selected.source_id,
                resource_key=selected.resource_key,
                role="bed",
                start_seconds=0,
                end_seconds=60,
                loop=True,
                default_volume=0.3,
                keyframes=[SpatialKeyframe(t=0, angle=0, radius=0.8)],
            )
        ]
    )


def test_selected_source_requires_catalog_fields_and_bounded_spatial_mix() -> None:
    with pytest.raises(ValidationError):
        SelectedSourceIn(
            resource_key="rain_soft",
            name="Rain",
            description="Rain",
            layer="environment",
            loop=True,
            duration_seconds=1,
            default_volume=0.3,
            angle=0,
            radius=0.5,
        )
    values = source().model_dump()
    with pytest.raises(ValidationError):
        SelectedSourceIn(**(values | {"angle": math.pi + 0.01}))
    with pytest.raises(ValidationError):
        SelectedSourceIn(**(values | {"radius": 1.1}))


def test_outline_sections_reject_negative_or_reversed_time() -> None:
    request = OutlineRequest(
        selected_sources=[source()],
        options=SceneAssistOptions(duration_seconds=60),
    )
    assert request.options.duration_seconds == 60
    invalid_outline = outline().model_dump()
    invalid_outline["sections"] = [
        {"name": "bad", "start_seconds": 10, "end_seconds": 10}
    ]
    with pytest.raises(ValidationError):
        ArrangementRequest(
            selected_sources=[source()], outline=invalid_outline
        )


def test_outline_sections_must_be_chronological() -> None:
    invalid_outline = outline().model_dump()
    invalid_outline["sections"] = [
        {"name": "later", "start_seconds": 20, "end_seconds": 40},
        {"name": "earlier", "start_seconds": 0, "end_seconds": 10},
    ]
    with pytest.raises(ValidationError):
        SceneOutline(**invalid_outline)


def test_request_stages_keep_outline_arrangement_and_final_composition_separate() -> None:
    scene_outline = outline()
    plan = arrangement()
    request = CompileRequest(
        selected_sources=[source()], outline=scene_outline, arrangement=plan
    )
    assert request.outline == scene_outline
    assert request.arrangement == plan
    generated = GenerateRequest(selected_sources=[source()])
    assert generated.selected_sources[0].resource_key == "rain_soft"


def test_outline_prompt_requires_json_and_catalog_only_references() -> None:
    system, user = build_outline_prompts(
        OutlineRequest(
            selected_sources=[source()],
            options=SceneAssistOptions(scene_intent="sleep", language="en"),
        )
    )
    assert "JSON" in system
    assert "rain_soft" in user
    assert "source_id" in user
    assert "Do not invent" in system


def test_all_stage_prompts_include_a_minimal_json_example() -> None:
    selected = source()
    scene_outline = outline()
    plan = arrangement()
    prompts = [
        build_arrangement_prompts(
            ArrangementRequest(selected_sources=[selected], outline=scene_outline)
        ),
        build_compile_prompts(
            CompileRequest(
                selected_sources=[selected],
                outline=scene_outline,
                arrangement=plan,
            )
        ),
        build_adjust_prompts(
            AdjustRequest(
                selected_sources=[selected],
                scene={"composition": {"schema": "scene_composition_v2"}},
                instruction="make the rain quieter",
            )
        ),
    ]
    for system, user in prompts:
        assert "Return exactly one valid JSON object" in system
        assert "Minimal JSON shape" in user
        assert selected.resource_key in user


def test_arrangement_prompt_uses_the_selected_catalog_identifier() -> None:
    values = source().model_dump()
    values.update(
        resource_key="fire_soft",
        name="Fire",
        description="A quiet fire bed",
    )
    fire = SelectedSourceIn(**values)
    _, user = build_arrangement_prompts(
        ArrangementRequest(selected_sources=[fire], outline=outline())
    )
    assert '"resource_key":"fire_soft"' in user
    assert "rain_soft" not in user
    assert "Approved outline:\n<UNTRUSTED_DATA>" in user
    assert "</UNTRUSTED_DATA>\nMinimal JSON shape" in user
