"""Add user scene states and private scenes."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002_user_home_private"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_scene_states",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("scene_id", sa.Uuid(), nullable=False),
        sa.Column("is_favorite", sa.Boolean(), nullable=False),
        sa.Column("last_opened_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("listen_count", sa.Integer(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["scene_id"], ["scenes.id"], name=op.f("fk_user_scene_states_scene_id_scenes"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_user_scene_states_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("user_id", "scene_id", name=op.f("pk_user_scene_states")),
    )

    op.create_table(
        "private_scenes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("subtitle", sa.String(length=256), nullable=False),
        sa.Column("description", sa.String(length=2000), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("palette", sa.JSON(), nullable=False),
        sa.Column("visual_style", sa.String(length=64), nullable=False),
        sa.Column("recommended_duration_seconds", sa.Integer(), nullable=False),
        sa.Column("source_scene_id", sa.Uuid(), nullable=True),
        sa.Column("draft_sources", sa.JSON(), nullable=False),
        sa.Column("saved_sources", sa.JSON(), nullable=True),
        sa.Column("saved_version", sa.Integer(), nullable=False),
        sa.Column("saved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
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
            ["owner_user_id"],
            ["users.id"],
            name=op.f("fk_private_scenes_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_private_scenes")),
    )
    op.create_index(op.f("ix_private_scenes_owner_user_id"), "private_scenes", ["owner_user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_private_scenes_owner_user_id"), table_name="private_scenes")
    op.drop_table("private_scenes")
    op.drop_table("user_scene_states")
