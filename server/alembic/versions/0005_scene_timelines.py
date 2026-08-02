"""Add versioned scene timelines for cue/phrase orchestration."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005_scene_timelines"
down_revision: str | None = "0004_seed_jobs"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

JSONType = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    op.create_table(
        "scene_timelines",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("scene_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("automation_mode", sa.String(length=32), nullable=False),
        sa.Column("duration_hint_seconds", sa.Integer(), nullable=True),
        sa.Column("override_policy", sa.String(length=64), nullable=False),
        sa.Column("phrases", JSONType, nullable=False),
        sa.Column("cues", JSONType, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["scene_id"],
            ["scenes.id"],
            name=op.f("fk_scene_timelines_scene_id_scenes"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_scene_timelines")),
        sa.UniqueConstraint("scene_id", name=op.f("uq_scene_timelines_scene_id")),
    )
    op.create_index(op.f("ix_scene_timelines_scene_id"), "scene_timelines", ["scene_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_scene_timelines_scene_id"), table_name="scene_timelines")
    op.drop_table("scene_timelines")
