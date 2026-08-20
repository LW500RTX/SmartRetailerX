"""
SmartRetailX Product Catalogue Service SQLAlchemy DB Models & Promotion Schema Migration
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class ProductDB(Base):
    __tablename__ = "products"

    id = Column(String(100), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    sku = Column(String(100), unique=True, index=True, nullable=False)
    category = Column(String(100), default="General")
    original_price = Column(Float, nullable=False, default=0.0)
    discount_price = Column(Float, nullable=True)
    promo_price = Column(Float, nullable=True)
    current_price = Column(Float, nullable=False, default=0.0)
    is_on_sale = Column(Boolean, default=False)
    discount_percentage = Column(Float, default=0.0)
    quantity = Column(Integer, default=50)
    version = Column(Integer, default=1, nullable=False)
    promo_start_time = Column(DateTime, nullable=True)
    promo_end_time = Column(DateTime, nullable=True)
    promotion_code = Column(String(100), nullable=True)
    image_url = Column(String(500), default="https://images.unsplash.com/photo-1542838132-92c53300491e?w=100")
    created_at = Column(DateTime, default=datetime.utcnow)

    def calculate_effective_price(self) -> float:
        """Dynamically evaluate active promotional rules based on current timestamp."""
        now = datetime.utcnow()
        if self.promo_price and self.promo_start_time and self.promo_end_time:
            if self.promo_start_time <= now <= self.promo_end_time:
                return float(self.promo_price)
        return float(self.original_price or self.current_price)
