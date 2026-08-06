"""Rename scene-track volume to initial envelope."""

from collections.abc import Sequence

from alembic import op

revision: str = "0010_initial_envelope"
down_revision: str | None = "0009_private_scene_compositions"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("scene_tracks", "volume", new_column_name="initial_envelope")


def downgrade() -> None:
    op.alter_column("scene_tracks", "initial_envelope", new_column_name="volume")
