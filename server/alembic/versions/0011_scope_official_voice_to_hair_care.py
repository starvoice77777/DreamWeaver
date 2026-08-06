"""Scope bundled official voice tracks to the hair-care scene."""

import uuid
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0011_scope_official_voice"
down_revision: str | None = "0010_initial_envelope"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

HAIR_CARE_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111101")
RAIN_EAVES_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111102")


def upgrade() -> None:
    scene_tracks = sa.table(
        "scene_tracks",
        sa.column("scene_id", sa.Uuid()),
        sa.column("layer", sa.String()),
    )
    scene_timelines = sa.table(
        "scene_timelines",
        sa.column("scene_id", sa.Uuid()),
        sa.column("version", sa.Integer()),
        sa.column("phrases", sa.JSON()),
        sa.column("cues", sa.JSON()),
    )
    op.execute(
        scene_tracks.delete().where(
            scene_tracks.c.layer == "voice",
            scene_tracks.c.scene_id != HAIR_CARE_SCENE_ID,
        )
    )
    op.execute(
        scene_timelines.update()
        .where(
            scene_timelines.c.scene_id.not_in(
                [HAIR_CARE_SCENE_ID, RAIN_EAVES_SCENE_ID]
            )
        )
        .values(version=2, phrases=[], cues=[])
    )


def downgrade() -> None:
    # Removed catalog narration was invalid product data and is intentionally
    # not recreated. Older application versions tolerate empty timelines.
    pass
