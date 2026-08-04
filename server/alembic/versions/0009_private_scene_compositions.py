"""Add draft/saved composition documents on private scenes."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009_private_scene_compositions"
down_revision: str | None = "0008_audit"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

JSONType = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    op.add_column("private_scenes", sa.Column("draft_composition", JSONType, nullable=True))
    op.add_column("private_scenes", sa.Column("saved_composition", JSONType, nullable=True))


def downgrade() -> None:
    op.drop_column("private_scenes", "saved_composition")
    op.drop_column("private_scenes", "draft_composition")
