"""Alembic migration script template."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("nickname", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
    )
    op.create_table(
        "scenes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("subtitle", sa.String(length=256), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("palette", sa.JSON(), nullable=False),
        sa.Column("visual_style", sa.String(length=64), nullable=False),
        sa.Column("recommended_duration_seconds", sa.Integer(), nullable=False),
        sa.Column("is_demo_playable", sa.Boolean(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("mock_listener_count", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_scenes")),
    )
    op.create_index(op.f("ix_scenes_category"), "scenes", ["category"], unique=False)

    op.create_table(
        "official_assets",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("kind", sa.String(length=64), nullable=False),
        sa.Column("symbol_name", sa.String(length=128), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("resource_key", sa.String(length=256), nullable=True),
        sa.Column("preview_resource_key", sa.String(length=256), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_official_assets")),
    )

    op.create_table(
        "apple_identities",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("apple_sub", sa.String(length=128), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_apple_identities_user_id_users"), ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_apple_identities")),
        sa.UniqueConstraint("user_id", name=op.f("uq_apple_identities_user_id")),
    )
    op.create_index(op.f("ix_apple_identities_apple_sub"), "apple_identities", ["apple_sub"], unique=True)

    op.create_table(
        "mix_presets",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("scene_id", sa.Uuid(), nullable=True),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("style_hint", sa.String(length=64), nullable=True),
        sa.Column("author_name", sa.String(length=64), nullable=False),
        sa.Column("sources", sa.JSON(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["scene_id"], ["scenes.id"], name=op.f("fk_mix_presets_scene_id_scenes"), ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mix_presets")),
    )
    op.create_index(op.f("ix_mix_presets_scene_id"), "mix_presets", ["scene_id"], unique=False)

    op.create_table(
        "scene_tracks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("scene_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("symbol_name", sa.String(length=128), nullable=False),
        sa.Column("layer", sa.String(length=32), nullable=False),
        sa.Column("volume", sa.Float(), nullable=False),
        sa.Column("angle", sa.Float(), nullable=False),
        sa.Column("radius", sa.Float(), nullable=False),
        sa.Column("resource_key", sa.String(length=256), nullable=True),
        sa.Column("loop", sa.Boolean(), nullable=False),
        sa.Column("enabled_by_default", sa.Boolean(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["scene_id"], ["scenes.id"], name=op.f("fk_scene_tracks_scene_id_scenes"), ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_scene_tracks")),
    )
    op.create_index(op.f("ix_scene_tracks_scene_id"), "scene_tracks", ["scene_id"], unique=False)

    op.create_table(
        "sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("refresh_token_hash", sa.String(length=128), nullable=False),
        sa.Column("access_token_hash", sa.String(length=128), nullable=False),
        sa.Column("device_label", sa.String(length=128), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_sessions_user_id_users"), ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sessions")),
        sa.UniqueConstraint("refresh_token_hash", name=op.f("uq_sessions_refresh_token_hash")),
        sa.UniqueConstraint("access_token_hash", name=op.f("uq_sessions_access_token_hash")),
    )
    op.create_index(op.f("ix_sessions_access_token_hash"), "sessions", ["access_token_hash"], unique=True)
    op.create_index(op.f("ix_sessions_user_id"), "sessions", ["user_id"], unique=False)

    op.create_table(
        "user_settings",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("reduce_motion", sa.Boolean(), nullable=False),
        sa.Column("auto_play_enabled", sa.Boolean(), nullable=False),
        sa.Column("background_play_enabled", sa.Boolean(), nullable=False),
        sa.Column("lock_screen_play_enabled", sa.Boolean(), nullable=False),
        sa.Column("animation_intensity", sa.Float(), nullable=False),
        sa.Column("dark_mode_forced", sa.Boolean(), nullable=False),
        sa.Column("audio_quality", sa.String(length=32), nullable=False),
        sa.Column("notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("default_scene_id", sa.Uuid(), nullable=True),
        sa.Column("extras", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_user_settings_user_id_users"), ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_user_settings")),
    )


def downgrade() -> None:
    op.drop_table("user_settings")
    op.drop_index(op.f("ix_sessions_user_id"), table_name="sessions")
    op.drop_index(op.f("ix_sessions_access_token_hash"), table_name="sessions")
    op.drop_table("sessions")
    op.drop_index(op.f("ix_scene_tracks_scene_id"), table_name="scene_tracks")
    op.drop_table("scene_tracks")
    op.drop_index(op.f("ix_mix_presets_scene_id"), table_name="mix_presets")
    op.drop_table("mix_presets")
    op.drop_index(op.f("ix_apple_identities_apple_sub"), table_name="apple_identities")
    op.drop_table("apple_identities")
    op.drop_table("official_assets")
    op.drop_index(op.f("ix_scenes_category"), table_name="scenes")
    op.drop_table("scenes")
    op.drop_table("users")
