from sqlalchemy import Column, Integer, String, DateTime, Date, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.base import Base


class User(Base):
    """User model with role information"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String(128), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    name = Column(String(255), nullable=False)
    role = Column(String(50), default="STUDENT")  # STUDENT, TEACHER, ADMIN
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    leave_requests = relationship("LeaveRequest", back_populates="student")
    fcm_tokens = relationship("FCMToken", back_populates="user")


class LeaveRequest(Base):
    """Leave request model"""
    __tablename__ = "leave_requests"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    from_date = Column(Date, nullable=False)
    to_date = Column(Date, nullable=False)
    reason = Column(Text, nullable=False)
    status = Column(String(50), default="PENDING")  # PENDING, APPROVED, REJECTED
    reviewed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    student = relationship("User", back_populates="leave_requests", foreign_keys=[student_id])
    reviewer = relationship("User", foreign_keys=[reviewed_by])


class FCMToken(Base):
    """FCM token storage for push notifications"""
    __tablename__ = "fcm_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    token = Column(String(512), nullable=False)
    device_type = Column(String(50), default="android")  # android, ios, web
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="fcm_tokens")

