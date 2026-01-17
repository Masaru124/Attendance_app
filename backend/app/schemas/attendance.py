from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional



class AttendanceSessionCreate(BaseModel):
    session_name: str = Field(..., min_length=1, max_length=255, description="Name of the attendance session")
    location: Optional[str] = Field(None, max_length=255, description="Location of the session")


class AttendanceSessionResponse(BaseModel):
    session_id: int
    session_name: str
    qr_data: str
    created_at: datetime

    class Config:
        from_attributes = True


class AttendanceSessionDetail(BaseModel):
    id: int
    session_name: str
    location: Optional[str]
    created_by: str
    created_at: datetime
    is_closed: bool
    total_records: int

    class Config:
        from_attributes = True



class MarkAttendanceRequest(BaseModel):
    session_id: int = Field(..., description="ID of the attendance session")


class MarkAttendanceResponse(BaseModel):
    success: bool
    message: str
    attendance_id: int
    status: str
    check_in_time: str

    class Config:
        from_attributes = True


class AttendanceRecordResponse(BaseModel):
    id: int
    session_id: int
    session_name: str
    date: str
    status: str
    location: Optional[str]
    check_in_time: Optional[str]
    check_out_time: Optional[str]

    class Config:
        from_attributes = True


class SessionAttendanceRecord(BaseModel):
    id: int
    student_id: int
    student_name: str
    student_email: Optional[str]
    status: str
    check_in_time: Optional[str]
    check_out_time: Optional[str]

    class Config:
        from_attributes = True


class SessionAttendanceResponse(BaseModel):
    session: AttendanceSessionDetail
    records: list[SessionAttendanceRecord]
    total_present: int
    total_absent: int
    total_late: int



class QRCodeResponse(BaseModel):
    session_id: int
    session_name: str
    qr_image_base64: str
    qr_data: str



class CloseSessionResponse(BaseModel):
    success: bool
    message: str

