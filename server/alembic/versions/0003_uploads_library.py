"""Add upload sessions and user sound assets."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003_uploads_library"
down_revision: str | None = "0002_user_home_private"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "upload_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("filename", sa.String(length=256), nullable=False),
        sa.Column("content_type", sa.String(length=128), nullable=False),
        sa.Column("declared_byte_size", sa.BigInteger(), nullable=False),
        sa.Column("kind", sa.String(length=64), nullable=False),
        sa.Column("display_name", sa.String(length=128), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_upload_sessions_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_upload_sessions")),
        sa.UniqueConstraint("storage_key", name=op.f("uq_upload_sessions_storage_key")),
    )
    op.create_index(op.f("ix_upload_sessions_user_id"), "upload_sessions", ["user_id"])
    op.create_index(op.f("ix_upload_sessions_status"), "upload_sessions", ["status"])

    op.create_table(
        "user_sound_assets",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_user_id", sa.Uuid(), nullable=False),
        sa.Column("upload_id", sa.Uuid(), nullable=True),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("kind", sa.String(length=64), nullable=False),
        sa.Column("symbol_name", sa.String(length=128), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=128), nullable=False),
        sa.Column("byte_size", sa.BigInteger(), nullable=False),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("preview_storage_key", sa.String(length=512), nullable=True),
        sa.Column("is_favorite", sa.Boolean(), nullable=False),
        sa.Column("processing_status", sa.String(length=32), nullable=False),
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
            name=op.f("fk_user_sound_assets_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["upload_id"],
            ["upload_sessions.id"],
            name=op.f("fk_user_sound_assets_upload_id_upload_sessions"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_user_sound_assets")),
        sa.UniqueConstraint("storage_key", name=op.f("uq_user_sound_assets_storage_key")),
        sa.UniqueConstraint("upload_id", name=op.f("uq_user_sound_assets_upload_id")),
    )
    op.create_index(op.f("ix_user_sound_assets_owner_user_id"), "user_sound_assets", ["owner_user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_user_sound_assets_owner_user_id"), table_name="user_sound_assets")
    op.drop_table("user_sound_assets")
    op.drop_index(op.f("ix_upload_sessions_status"), table_name="upload_sessions")
    op.drop_index(op.f("ix_upload_sessions_user_id"), table_name="upload_sessions")
    op.drop_table("upload_sessions")
