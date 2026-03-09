from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date
import qrcode
from io import BytesIO
from base64 import b64encode
import json
import math

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
    BiometricAttendanceRequest,
    BiometricAttendanceResponse,
)
from app.services.face_service import encode_face, verify_face

router = APIRouter(prefix="/attendance", tags=["Attendance Management"])


@router.post("/sessions", response_model=AttendanceSessionResponse)
async def create_attendance_session(
    session_data: AttendanceSessionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
):
    
    # Get the late deadline datetime
    late_until = session_data.get_late_until_datetime()
    
    session = AttendanceSession(
        session_name=session_data.session_name,
        created_by=current_user.get("uid"),
        location=session_data.location,
        radius_meters=session_data.radius_meters,
        late_until=late_until,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    
    # Include late timing in QR data for better frontend handling
    qr_data = {
        "session_id": session.id,
        "session_name": session_data.session_name,
        "location": session_data.location or "",
        "late_until": late_until.isoformat() if late_until else None
    }
    
    return {
        "session_id": session.id,
        "session_name": session_data.session_name,
        "qr_data": json.dumps(qr_data),
        "created_at": session.created_at,
        "late_until": late_until,
        "location": session_data.location
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
            "late_until": session.late_until.isoformat() if session.late_until else None,
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
        "late_until": session.late_until.isoformat() if session.late_until else None,
        "total_records": total_records,
    }


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance between two points on earth.
    
    Args:
        lat1, lon1: Latitude and longitude of point 1
        lat2, lon2: Latitude and longitude of point 2
    
    Returns:
        Distance in meters
    """
    R = 6371000  # Earth's radius in meters
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = (math.sin(delta_lat / 2) ** 2 + 
         math.cos(lat1_rad) * math.cos(lat2_rad) * 
         math.sin(delta_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c


@router.post("/verify-biometric", response_model=BiometricAttendanceResponse)
async def verify_biometric_attendance(
    request: BiometricAttendanceRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Step 1: Validate QR token and find session
        try:
            qr_data = json.loads(request.qr_token)
            session_id = qr_data.get("session_id")
        except:
            raise HTTPException(status_code=400, detail="Invalid QR token format")
        
        if not session_id:
            raise HTTPException(status_code=400, detail="Session ID not found in QR token")
        
        session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
        if not session:
            raise HTTPException(status_code=404, detail="Attendance session not found")
        
        # Step 2: Validate session active
        if session.is_closed:
            raise HTTPException(status_code=400, detail="This attendance session has been closed")
        
        # Step 3: Check current time against late_until
        now = datetime.now()
        if session.late_until and now > session.late_until:
            raise HTTPException(status_code=400, detail="Attendance marking deadline has passed")
        
        # Step 4: Get user
        user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Step 5: Check if already marked
        existing = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session_id,
            AttendanceRecord.student_id == user.id
        ).first()
        
        if existing:
            raise HTTPException(status_code=400, detail="Attendance already marked for this session")
        
        # Step 6: Validate location radius if session has location and radius
        if session.location and session.radius_meters:
            try:
                # Parse session location (expected format: "latitude,longitude")
                session_lat, session_lon = map(float, session.location.split(','))
                distance = haversine_distance(
                    session_lat, session_lon, 
                    request.latitude, request.longitude
                )
                
                if distance > session.radius_meters:
                    raise HTTPException(
                        status_code=400, 
                        detail=f"Location validation failed. You are {distance:.0f}m away from the session location"
                    )
            except Exception as e:
                if "Location validation failed" in str(e):
                    raise e
                print(f"Location validation error: {e}")
                # Continue if location parsing fails
        
        # Step 7: Generate face embedding from uploaded image
        face_embedding = encode_face(request.image_base64)
        if face_embedding is None:
            raise HTTPException(status_code=400, detail="No face detected or multiple faces detected in image")
        
        # Step 8: Verify face with stored user embedding
        if not user.face_embedding:
            raise HTTPException(status_code=400, detail="No face registered for this user. Please register your face first.")
        
        if not verify_face(user.face_embedding, face_embedding):
            raise HTTPException(status_code=400, detail="Face verification failed. Face does not match registered face.")
        
        # Step 9: Mark attendance
        check_in_time = now.strftime("%H:%M:%S")
        today_date = now.date()
        
        # Determine status based on time
        is_late = False
        if session.late_until:
            is_late = now > session.late_until
        else:
            # Default logic: late after 9 AM
            is_late = now.hour >= 9 and now.minute > 0
        
        status = "LATE" if is_late else "PRESENT"
        
        attendance = AttendanceRecord(
            session_id=session_id,
            student_id=user.id,
            date=today_date,
            status=status,
            check_in_time=check_in_time,
            latitude=str(request.latitude),
            longitude=str(request.longitude),
            face_verified=True,
        )
        
        db.add(attendance)
        db.commit()
        db.refresh(attendance)
        
        return {
            "success": True,
            "message": f"Biometric attendance marked as {status}",
            "attendance_id": attendance.id,
            "status": status,
            "check_in_time": check_in_time
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Biometric attendance error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error during biometric verification")

