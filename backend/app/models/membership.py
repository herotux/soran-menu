from enum import Enum

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.session import Base


class MembershipRole(str, Enum):
    OWNER = "owner"
    ADMIN = "admin"
    STAFF = "staff"


class Membership(Base):
    __tablename__ = "memberships"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "restaurant_id",
            name="uq_user_restaurant",
        ),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"),
        nullable=False,
    )

    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=MembershipRole.STAFF.value,
    )

    user = relationship(
        "User",
        back_populates="memberships",
    )

    restaurant = relationship(
        "Restaurant",
        back_populates="memberships",
    )
