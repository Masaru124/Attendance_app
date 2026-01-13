from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import date

from app.db.database import get_db
from app.core.security import get_current_user, verify_role
from app.schemas.leave import (
    LeaveRequestCreate,
    LeaveRequestResponse,
    LeaveActionRequest,
    LeaveActionResponse,
    APIResponse,
)
from app.services.notification_service import notification_service
from app.db.models import User, LeaveRequest

router = APIRouter(prefix="/leave", tags=["Leave Management"])


@router.post("/apply", response_model=LeaveRequestResponse, status_code=status.HTTP_201_CREATED)
async def apply_leave(
    leave_data: LeaveRequestCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Student applies for leave.
    
    Creates a new leave request with PENDING status.
    """
    # Verify user is a student
    if current_user.get("role") not in ["STUDENT", None]:
        raise HTTPException(
            status_code=403,
            detail="Only students can apply for leave"
        )

    # Validate dates
    if leave_data.to_date < leave_data.from_date:
        raise HTTPException(
            status_code=400,
            detail="End date must be after start date"
        )

    # Get or create user in database
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

    # Create leave request
    leave_request = LeaveRequest(
        student_id=user.id,
        from_date=leave_data.from_date,
        to_date=leave_data.to_date,
        reason=leave_data.reason,
        status="PENDING"
    )

    db.add(leave_request)
    db.commit()
    db.refresh(leave_request)

    return leave_request


@router.get("/pending", response_model=List[LeaveRequestResponse])
async def get_pending_leaves(
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
    db: Session = Depends(get_db)
):
    """
    Teacher/Admin views all pending leave requests.
    
    Returns list of leave requests with PENDING status.
    """
    pending_leaves = db.query(LeaveRequest).filter(
        LeaveRequest.status == "PENDING"
    ).order_by(LeaveRequest.created_at.desc()).all()

    # Add student name to each leave request
    result = []
    for leave in pending_leaves:
        student = db.query(User).filter(User.id == leave.student_id).first()
        leave_data = {
            "id": leave.id,
            "student_id": leave.student_id,
            "student_name": student.name if student else "Unknown",
            "from_date": leave.from_date,
            "to_date": leave.to_date,
            "reason": leave.reason,
            "status": leave.status,
            "reviewed_by": leave.reviewed_by,
            "reviewer_name": None,
            "reviewed_at": leave.reviewed_at,
            "created_at": leave.created_at
        }
        result.append(LeaveRequestResponse(**leave_data))

    return result


@router.get("/my", response_model=List[LeaveRequestResponse])
async def my_leaves(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Student views their own leave history.
    
    Returns list of all leave requests for the authenticated student.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        return []

    leaves = db.query(LeaveRequest).filter(
        LeaveRequest.student_id == user.id
    ).order_by(LeaveRequest.created_at.desc()).all()

    result = []
    for leave in leaves:
        reviewer = db.query(User).filter(User.id == leave.reviewed_by).first()
        leave_data = {
            "id": leave.id,
            "student_id": leave.student_id,
            "student_name": user.name,
            "from_date": leave.from_date,
            "to_date": leave.to_date,
            "reason": leave.reason,
            "status": leave.status,
            "reviewed_by": leave.reviewed_by,
            "reviewer_name": reviewer.name if reviewer else None,
            "reviewed_at": leave.reviewed_at,
            "created_at": leave.created_at
        }
        result.append(LeaveRequestResponse(**leave_data))

    return result


@router.get("/all", response_model=List[LeaveRequestResponse])
async def get_all_leaves(
    status_filter: str = None,
    current_user: dict = Depends(verify_role(["ADMIN"])),
    db: Session = Depends(get_db)
):
    """
    Admin views all leave requests with optional status filter.
    """
    query = db.query(LeaveRequest)
    
    if status_filter:
        query = query.filter(LeaveRequest.status == status_filter.upper())
    
    leaves = query.order_by(LeaveRequest.created_at.desc()).all()

    result = []
    for leave in leaves:
        student = db.query(User).filter(User.id == leave.student_id).first()
        reviewer = db.query(User).filter(User.id == leave.reviewed_by).first()
        leave_data = {
            "id": leave.id,
            "student_id": leave.student_id,
            "student_name": student.name if student else "Unknown",
            "from_date": leave.from_date,
            "to_date": leave.to_date,
            "reason": leave.reason,
            "status": leave.status,
            "reviewed_by": leave.reviewed_by,
            "reviewer_name": reviewer.name if reviewer else None,
            "reviewed_at": leave.reviewed_at,
            "created_at": leave.created_at
        }
        result.append(LeaveRequestResponse(**leave_data))

    return result


@router.post("/{leave_id}/action", response_model=LeaveActionResponse)
async def leave_action(
    leave_id: int,
    action: LeaveActionRequest,
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
    db: Session = Depends(get_db)
):
    """
    Teacher/Admin approves or rejects a leave request.
    
    Sends push notification to student upon status change.
    """
    # Get the leave request
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")

    if leave.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=f"Leave request has already been {leave.status.lower()}"
        )

    # Get the reviewer (current user)
    reviewer = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not reviewer:
        reviewer = User(
            firebase_uid=current_user["uid"],
            email=current_user.get("email", ""),
            name=current_user.get("name", "Teacher"),
            role=current_user.get("role", "TEACHER")
        )
        db.add(reviewer)
        db.flush()
        db.refresh(reviewer)

    # Update leave status
    leave.status = action.action
    leave.reviewed_by = reviewer.id

    # Get student info for notification
    student = db.query(User).filter(User.id == leave.student_id).first()
    date_range = f"{leave.from_date} to {leave.to_date}"

    # Send push notification
    notification_sent = notification_service.send_leave_status_notification(
        db=db,
        student_id=leave.student_id,
        status=action.action,
        leave_id=leave.id,
        date_range=date_range
    )

    db.commit()
    db.refresh(leave)

    return LeaveActionResponse(
        success=True,
        message=f"Leave request {action.action.lower()}ed successfully"
                + (" (Notification sent)" if notification_sent else ""),
        leave_request=LeaveRequestResponse(
            id=leave.id,
            student_id=leave.student_id,
            student_name=student.name if student else "Unknown",
            from_date=leave.from_date,
            to_date=leave.to_date,
            reason=leave.reason,
            status=leave.status,
            reviewed_by=leave.reviewed_by,
            reviewer_name=reviewer.name,
            reviewed_at=leave.reviewed_at,
            created_at=leave.created_at
        )
    )


@router.get("/{leave_id}", response_model=dict)
async def get_leave_detail(
    leave_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get detailed information about a specific leave request."""
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")

    student = db.query(User).filter(User.id == leave.student_id).first()
    reviewer = None
    if leave.reviewed_by:
        reviewer = db.query(User).filter(User.id == leave.reviewed_by).first()

    return {
        "id": leave.id,
        "student_id": leave.student_id,
        "student_name": student.name if student else "Unknown",
        "student_email": student.email if student else None,
        "from_date": leave.from_date,
        "to_date": leave.to_date,
        "reason": leave.reason,
        "status": leave.status,
        "reviewed_by": leave.reviewed_by,
        "reviewer_name": reviewer.name if reviewer else None,
        "reviewed_at": leave.reviewed_at,
        "created_at": leave.created_at
    }

