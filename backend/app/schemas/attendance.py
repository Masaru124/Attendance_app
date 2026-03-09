from pydantic import BaseModel, Field
from datetime import datetime, time, date
from typing import Optional, Union


class AttendanceSessionCreate(BaseModel):
    session_name: str = Field(..., min_length=1, max_length=255, description="Name of the attendance session")
    location: Optional[str] = Field(None, max_length=255, description="Location of the session")
    radius_meters: Optional[int] = Field(None, ge=1, le=10000, description="GPS validation radius in meters")
    late_until_time: Optional[time] = Field(None, description="Late deadline time (e.g., 09:00:00)")
    late_until_datetime: Optional[datetime] = Field(None, description="Complete late deadline datetime")
    
    def get_late_until_datetime(self, session_date: date = None) -> Optional[datetime]:
        """Get the late deadline datetime based on provided time or datetime"""
        if self.late_until_datetime:
            return self.late_until_datetime
        elif self.late_until_time:
            # If only time is provided, use it with today's date or provided date
            target_date = session_date or date.today()
            return datetime.combine(target_date, self.late_until_time)
        return None


class AttendanceSessionResponse(BaseModel):
    session_id: int
    session_name: str
    qr_data: str
    created_at: datetime
    late_until: Optional[datetime] = None
    location: Optional[str] = None

    class Config:
        from_attributes = True


class AttendanceSessionDetail(BaseModel):
    id: int
    session_name: str
    location: Optional[str]
    created_by: str
    created_at: datetime
    is_closed: bool
    late_until: Optional[datetime] = None
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


class BiometricAttendanceRequest(BaseModel):
    qr_token: str = Field(..., description="QR code token containing session information")
    image_base64: str = Field(..., description="Base64 encoded face image")
    latitude: float = Field(..., ge=-90, le=90, description="GPS latitude")
    longitude: float = Field(..., ge=-180, le=180, description="GPS longitude")


class BiometricAttendanceResponse(BaseModel):
    success: bool
    message: str
    attendance_id: Optional[int] = None
    status: Optional[str] = None
    check_in_time: Optional[str] = None


class RegisterFaceRequest(BaseModel):
    image_base64: str = Field(..., description="Base64 encoded face image")


class RegisterFaceResponse(BaseModel):
    success: bool
    message: str

