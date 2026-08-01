"""Add voice authorizations and seed jobs."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0004_seed_jobs"
down_revision: str | None = "0003_uploads_library"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "voice_authorizations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("confirmed", sa.Boolean(), nullable=False),
        sa.Column("revocable", sa.Boolean(), nullable=False),
        sa.Column("purpose", sa.String(length=512), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_voice_authorizations_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_voice_authorizations")),
    )
    op.create_index(op.f("ix_voice_authorizations_user_id"), "voice_authorizations", ["user_id"])

    op.create_table(
        "seed_jobs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("authorization_id", sa.Uuid(), nullable=False),
        sa.Column("source_asset_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("progress", sa.Float(), nullable=False),
        sa.Column("message", sa.String(length=256), nullable=False),
        sa.Column("provider_job_id", sa.String(length=128), nullable=True),
        sa.Column("preview_storage_key", sa.String(length=512), nullable=True),
        sa.Column("result_asset_id", sa.Uuid(), nullable=True),
        sa.Column("relation", sa.String(length=64), nullable=True),
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
            ["authorization_id"],
            ["voice_authorizations.id"],
            name=op.f("fk_seed_jobs_authorization_id_voice_authorizations"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["result_asset_id"],
            ["user_sound_assets.id"],
            name=op.f("fk_seed_jobs_result_asset_id_user_sound_assets"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["source_asset_id"],
            ["user_sound_assets.id"],
            name=op.f("fk_seed_jobs_source_asset_id_user_sound_assets"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_seed_jobs_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_seed_jobs")),
    )
    op.create_index(op.f("ix_seed_jobs_user_id"), "seed_jobs", ["user_id"])
    op.create_index(op.f("ix_seed_jobs_authorization_id"), "seed_jobs", ["authorization_id"])
    op.create_index(op.f("ix_seed_jobs_status"), "seed_jobs", ["status"])


def downgrade() -> None:
    op.drop_index(op.f("ix_seed_jobs_status"), table_name="seed_jobs")
    op.drop_index(op.f("ix_seed_jobs_authorization_id"), table_name="seed_jobs")
    op.drop_index(op.f("ix_seed_jobs_user_id"), table_name="seed_jobs")
    op.drop_table("seed_jobs")
    op.drop_index(op.f("ix_voice_authorizations_user_id"), table_name="voice_authorizations")
    op.drop_table("voice_authorizations")
