"""track announcement reads

Revision ID: 0005_announcement_reads
Revises: 0004_user_profile
"""
from alembic import op
import sqlalchemy as sa

revision = "0005_announcement_reads"
down_revision = "0004_user_profile"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "announcement_reads",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("announcement_id", sa.Integer(), sa.ForeignKey("announcements.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("read_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("announcement_id", "user_id", name="uq_announcement_user_read"),
    )
    op.create_index("ix_announcement_reads_announcement_id", "announcement_reads", ["announcement_id"])
    op.create_index("ix_announcement_reads_user_id", "announcement_reads", ["user_id"])


def downgrade() -> None:
    op.drop_table("announcement_reads")
