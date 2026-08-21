from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.membership import Membership
from app.models.platform import Order, OrderStatus, Wallet, WalletTransaction

router = APIRouter(tags=["Owner Platform"])


class OrderStatusUpdate(BaseModel):
    status: str


class WalletCredit(BaseModel):
    customer_id: int
    amount: int = Field(gt=0)
    description: str = "شارژ کیف پول توسط رستوران"


def _admin(restaurant_id: int, user_id: int, db: Session):
    membership = db.scalar(select(Membership).where(Membership.restaurant_id == restaurant_id, Membership.user_id == user_id))
    if membership is None or membership.role not in {"owner", "admin", "staff"}:
        raise HTTPException(status_code=403, detail="دسترسی ندارید")
    return membership


@router.get("/api/owner/{restaurant_id}/orders")
def orders(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(restaurant_id, current_user.id, db)
    rows = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id).order_by(Order.created_at.desc()).limit(200)).all()
    return [{"id": o.id, "customer_id": o.customer_id, "status": o.status, "subtotal": o.subtotal, "discount": o.discount_amount, "total": o.total, "created_at": o.created_at} for o in rows]


@router.patch("/api/owner/{restaurant_id}/orders/{order_id}")
def update_order(restaurant_id: int, order_id: int, data: OrderStatusUpdate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(restaurant_id, current_user.id, db)
    if data.status not in {s.value for s in OrderStatus}:
        raise HTTPException(status_code=400, detail="وضعیت سفارش نامعتبر است")
    order = db.scalar(select(Order).where(Order.id == order_id, Order.restaurant_id == restaurant_id))
    if order is None:
        raise HTTPException(status_code=404, detail="سفارش پیدا نشد")
    order.status = data.status
    if data.status == OrderStatus.COMPLETED.value and order.completed_at is None:
        order.completed_at = datetime.utcnow()
    db.commit()
    return {"id": order.id, "status": order.status}


@router.post("/api/owner/{restaurant_id}/wallet/credit")
def credit_wallet(restaurant_id: int, data: WalletCredit, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(restaurant_id, current_user.id, db)
    wallet = db.scalar(select(Wallet).where(Wallet.restaurant_id == restaurant_id, Wallet.user_id == data.customer_id))
    if wallet is None:
        wallet = Wallet(restaurant_id=restaurant_id, user_id=data.customer_id, balance=0)
        db.add(wallet)
        db.flush()
    wallet.balance += data.amount
    db.add(WalletTransaction(wallet_id=wallet.id, amount=data.amount, kind="credit", description=data.description))
    db.commit()
    return {"customer_id": data.customer_id, "balance": wallet.balance}
