from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.category import Category
from app.models.platform import Order, OrderItem
from app.models.product import Product

router = APIRouter(tags=["Recommendations"])


@router.get("/api/customer/{restaurant_id}/recommendations")
def recommendations(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    frequent = db.execute(
        select(OrderItem.product_id, func.sum(OrderItem.quantity).label("qty"))
        .join(Order, Order.id == OrderItem.order_id)
        .where(Order.restaurant_id == restaurant_id, Order.customer_id == current_user.id, Order.status == "completed")
        .group_by(OrderItem.product_id)
        .order_by(func.sum(OrderItem.quantity).desc())
        .limit(6)
    ).all()
    if frequent:
        ids = [row.product_id for row in frequent]
        products = db.scalars(select(Product).where(Product.id.in_(ids), Product.available)).all()
        by_id = {p.id: p for p in products}
        ordered = [by_id[i] for i in ids if i in by_id]
    else:
        ordered = db.scalars(
            select(Product).join(Category, Product.category_id == Category.id)
            .where(Category.restaurant_id == restaurant_id, Product.available)
            .order_by(Product.sort_order, Product.id)
            .limit(6)
        ).all()
    return [{"id": p.id, "name": p.name, "description": p.description, "price": p.price, "image": p.image} for p in ordered]
