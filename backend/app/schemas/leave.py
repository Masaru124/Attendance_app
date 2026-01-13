from pydantic import BaseModel, Field
from datetime import date, datetime
from typing import Optional, List


# ============== User Schemas ==============

class UserBase(BaseModel):
    email: str
    name: str


class UserCreate(UserBase):
    firebase_uid: str
    role: str = "STUDENT"


class UserResponse(UserBase):
    id: int
    firebase_uid: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


# ============== Leave Request Schemas ==============

class LeaveRequestCreate(BaseModel):
    """Schema for creating a leave request"""
    from_date: date = Field(..., description="Leave start date")
    to_date: date = Field(..., description="Leave end date")
    reason: str = Field(..., min_length=5, max_length=1000, description="Reason for leave")


class LeaveRequestResponse(BaseModel):
    """Schema for leave request response"""
    id: int
    student_id: int
    student_name: Optional[str] = None
    from_date: date
    to_date: date
    reason: str
    status: str
    reviewed_by: Optional[int] = None
    reviewer_name: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class LeaveRequestDetail(LeaveRequestResponse):
    """Detailed leave request with user info"""
    student: Optional[UserResponse] = None
    reviewer: Optional[UserResponse] = None


class LeaveActionRequest(BaseModel):
    """Schema for approve/reject action"""
    action: str = Field(..., pattern="^(APPROVE|REJECT)$", description="Action to take")


class LeaveActionResponse(BaseModel):
    """Response after leave action"""
    success: bool
    message: str
    leave_request: LeaveRequestResponse


# ============== FCM Token Schemas ==============

class FCMTokenCreate(BaseModel):
    """Schema for saving FCM token"""
    token: str = Field(..., description="Firebase Cloud Messaging token")
    device_type: str = Field(default="android", description="Device type")


class FCMTokenResponse(BaseModel):
    """FCM token response"""
    id: int
    user_id: int
    token: str
    device_type: str
    created_at: datetime

    class Config:
        from_attributes = True


# ============== API Response Schemas ==============

class APIResponse(BaseModel):
    """Generic API response"""
    success: bool
    message: str
    data: Optional[dict] = None


class LeaveStats(BaseModel):
    """Leave statistics"""
    total: int
    pending: int
    approved: int
    rejected: int

