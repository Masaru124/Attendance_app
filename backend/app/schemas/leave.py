from pydantic import BaseModel, Field
from datetime import date, datetime
from typing import Optional, List



class LeaveStats(BaseModel):
    total: int
    pending: int
    approved: int
    rejected: int



class BatchActionRequest(BaseModel):
    leave_ids: List[int] = Field(..., description="List of leave IDs to process")
    action: str = Field(..., pattern="^(APPROVE|REJECT)$", description="Action to take")


class FailedLeave(BaseModel):
    id: int
    error: str


class BatchActionResponse(BaseModel):
    success: bool
    message: str
    action: str
    processed_ids: List[int]
    failed_ids: List[FailedLeave]
    total_count: int
    success_count: int



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



class LeaveRequestCreate(BaseModel):
    """Schema for creating a leave request"""
    from_date: date = Field(..., description="Leave start date")
    to_date: date = Field(..., description="Leave end date")
    reason: str = Field(..., min_length=5, max_length=1000, description="Reason for leave")


class LeaveRequestResponse(BaseModel):
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
    student: Optional[UserResponse] = None
    reviewer: Optional[UserResponse] = None


class LeaveActionRequest(BaseModel):
    action: str = Field(..., pattern="^(APPROVE|REJECT)$", description="Action to take")


class LeaveActionResponse(BaseModel):
    success: bool
    message: str
    leave_request: LeaveRequestResponse



class FCMTokenCreate(BaseModel):
    token: str = Field(..., description="Firebase Cloud Messaging token")
    device_type: str = Field(default="android", description="Device type")


class FCMTokenResponse(BaseModel):
    id: int
    user_id: int
    token: str
    device_type: str
    created_at: datetime

    class Config:
        from_attributes = True



class APIResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None


class LeaveStats(BaseModel):
    total: int
    pending: int
    approved: int
    rejected: int

