from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date
import qrcode
from io import BytesIO
from base64 import b64encode

from app.db.database import get_db
from app.core.security import get_current_user, verify_role
from app.db.models import User, AttendanceSession, AttendanceRecord
from app.schemas.attendance import (
    AttendanceSessionCreate,
    AttendanceSessionResponse,
    MarkAttendanceRequest,
    AttendanceRecordResponse,
    SessionAttendanceResponse,
    QRCodeResponse,
    CloseSessionResponse,
)

router = APIRouter(prefix="/attendance", tags=["Attendance Management"])


@router.post("/sessions", response_model=AttendanceSessionResponse)
async def create_attendance_session(
    session_data: AttendanceSessionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
    
    session = AttendanceSession(
        session_name=session_data.session_name,
        created_by=current_user.get("uid"),
        location=session_data.location,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    
    return {
        "session_id": session.id,
        "session_name": session_data.session_name,
        "qr_data": f'{{"session_id": {session.id}, "session_name": "{session_data.session_name}", "location": "{session_data.location or ""}"}}',
        "created_at": session.created_at
    }


@router.post("/mark")
async def mark_attendance(
    request: MarkAttendanceRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
   
    session_id = request.session_id
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        user = User(
            firebase_uid=current_user["uid"],
            email=current_user.get("email", ""),
            name=current_user.get("name", "Student"),
            role="STUDENT"
        )
        db.add(user)
        db.flush()
        db.refresh(user)

    # Check if session exists
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Attendance session not found")

    # Check if already marked
    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id,
        AttendanceRecord.student_id == user.id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Attendance already marked for this session")

    if session.is_closed:
        raise HTTPException(status_code=400, detail="This attendance session has been closed")

    now = datetime.now()
    check_in_time = now.strftime("%H:%M:%S")
    today_date = now.date()  # Explicitly set today's date
    
    late_threshold = 9  # 9 AM
    is_late = now.hour >= late_threshold and now.minute > 0
    status = "LATE" if is_late else "PRESENT"

    attendance = AttendanceRecord(
        session_id=session_id,
        student_id=user.id,
        date=today_date,  
        status=status,
        check_in_time=check_in_time,
    )
    
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    
    return {
        "success": True,
        "message": f"Attendance marked as {status}",
        "attendance_id": attendance.id,
        "status": status,
        "check_in_time": check_in_time
    }


@router.get("/my")
async def get_my_attendance(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        return []

    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.student_id == user.id
    ).order_by(AttendanceRecord.date.desc()).all()
    
    result = []
    for record in records:
        session = db.query(AttendanceSession).filter(
            AttendanceSession.id == record.session_id
        ).first()
        
        result.append({
            "id": record.id,
            "session_id": record.session_id,
            "session_name": session.session_name if session else "Unknown Session",
            "date": record.date.isoformat() if record.date else datetime.now().date().isoformat(),
            "status": record.status,
            "location": session.location if session else None,
            "check_in_time": record.check_in_time,
            "check_out_time": record.check_out_time,
        })
    
    return result


@router.get("/session/{session_id}")
async def get_session_attendance(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
   
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id
    ).all()
    
    result = []
    for record in records:
        student = db.query(User).filter(User.id == record.student_id).first()
        result.append({
            "id": record.id,
            "student_id": record.student_id,
            "student_name": student.name if student else "Unknown",
            "student_email": student.email if student else None,
            "status": record.status,
            "check_in_time": record.check_in_time,
            "check_out_time": record.check_out_time,
        })
    
    return {
        "session": {
            "id": session.id,
            "session_name": session.session_name,
            "location": session.location,
            "created_at": session.created_at.isoformat(),
            "is_closed": session.is_closed,
        },
        "records": result,
        "total_present": len([r for r in result if r["status"] == "PRESENT"]),
        "total_absent": len([r for r in result if r["status"] == "ABSENT"]),
        "total_late": len([r for r in result if r["status"] == "LATE"]),
    }


@router.post("/sessions/{session_id}/close")
async def close_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):

    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session.is_closed = True
    db.commit()
    
    return {"success": True, "message": "Session closed successfully"}


@router.get("/sessions")
async def get_all_sessions(
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
    
    sessions = db.query(AttendanceSession).order_by(
        AttendanceSession.created_at.desc()
    ).all()
    
    result = []
    for session in sessions:
        total_records = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id
        ).count()
        
        result.append({
            "id": session.id,
            "session_name": session.session_name,
            "location": session.location,
            "created_at": session.created_at.isoformat(),
            "is_closed": session.is_closed,
            "total_records": total_records,
        })
    
    return result


@router.get("/sessions/{session_id}/qr")
async def get_session_qr_code(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
   
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Create QR code data
    qr_data = f'{{"session_id": {session.id}, "session_name": "{session.session_name}", "location": "{session.location or ""}"}}'
    
    # Generate QR code image
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(qr_data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Convert to base64
    buffered = BytesIO()
    img.save(buffered, format="PNG")
    img_str = b64encode(buffered.getvalue()).decode()
    
    return {
        "session_id": session.id,
        "session_name": session.session_name,
        "qr_image_base64": img_str,
        "qr_data": qr_data,
    }


@router.get("/sessions/{session_id}")
async def get_session_details(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
  
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    total_records = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id
    ).count()
    
    return {
        "id": session.id,
        "session_name": session.session_name,
        "location": session.location,
        "created_by": session.created_by,
        "created_at": session.created_at.isoformat(),
        "is_closed": session.is_closed,
        "total_records": total_records,
    }

