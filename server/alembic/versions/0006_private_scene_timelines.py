"""Add draft/saved timeline snapshots on private scenes."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006_private_scene_timelines"
down_revision: str | None = "0005_scene_timelines"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

JSONType = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    op.add_column("private_scenes", sa.Column("draft_timeline", JSONType, nullable=True))
    op.add_column("private_scenes", sa.Column("saved_timeline", JSONType, nullable=True))


def downgrade() -> None:
    op.drop_column("private_scenes", "saved_timeline")
    op.drop_column("private_scenes", "draft_timeline")
