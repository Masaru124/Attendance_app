from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import date, datetime

from app.db.database import get_db
from app.core.security import get_current_user, verify_role
from app.schemas.leave import (
    LeaveRequestCreate,
    LeaveRequestResponse,
    LeaveActionRequest,
    LeaveActionResponse,
    APIResponse,
    LeaveStats,
    BatchActionRequest,
    BatchActionResponse,
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


# ============== NEW ENDPOINTS FOR DAY 3 ==============

@router.get("/stats", response_model=LeaveStats)
async def get_leave_stats(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get leave statistics for the current user.
    
    Students see their own stats, teachers/admins see system-wide stats.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    
    # Base query
    if user and current_user.get("role") == "STUDENT":
        # Students see their own stats
        base_query = db.query(LeaveRequest).filter(LeaveRequest.student_id == user.id)
    else:
        # Teachers/Admins see all stats
        base_query = db.query(LeaveRequest)
    
    total = base_query.count()
    pending = base_query.filter(LeaveRequest.status == "PENDING").count()
    approved = base_query.filter(LeaveRequest.status == "APPROVED").count()
    rejected = base_query.filter(LeaveRequest.status == "REJECTED").count()
    
    return LeaveStats(
        total=total,
        pending=pending,
        approved=approved,
        rejected=rejected
    )


@router.get("/history", response_model=List[LeaveRequestResponse])
async def get_leave_history(
    status_filter: Optional[str] = Query(None, description="Filter by status: PENDING, APPROVED, REJECTED"),
    start_date: Optional[date] = Query(None, description="Filter from start date"),
    end_date: Optional[date] = Query(None, description="Filter until end date"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get leave history with filtering and pagination.
    
    Students see their own history, teachers/admins see all.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    
    # Base query
    if user and current_user.get("role") == "STUDENT":
        base_query = db.query(LeaveRequest).filter(LeaveRequest.student_id == user.id)
    else:
        base_query = db.query(LeaveRequest)
    
    # Apply filters
    if status_filter:
        base_query = base_query.filter(LeaveRequest.status == status_filter.upper())
    
    if start_date:
        base_query = base_query.filter(LeaveRequest.from_date >= start_date)
    
    if end_date:
        base_query = base_query.filter(LeaveRequest.to_date <= end_date)
    
    # Get total count for pagination
    total_count = base_query.count()
    
    # Apply pagination
    leaves = base_query.order_by(LeaveRequest.created_at.desc()).offset(
        (page - 1) * page_size
    ).limit(page_size).all()
    
    # Build response
    result = []
    for leave in leaves:
        student = db.query(User).filter(User.id == leave.student_id).first()
        reviewer = None
        if leave.reviewed_by:
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
    
    # Add pagination info to response headers
    from fastapi import Response
    response = Response(content=result.__repr__())
    response.headers["X-Total-Count"] = str(total_count)
    response.headers["X-Page"] = str(page)
    response.headers["X-Page-Size"] = str(page_size)
    
    return result


@router.post("/batch/action", response_model=BatchActionResponse)
async def batch_leave_action(
    action: BatchActionRequest,
    current_user: dict = Depends(verify_role(["TEACHER", "ADMIN"])),
    db: Session = Depends(get_db)
):
    """
    Approve or reject multiple leave requests at once.
    
    Useful for bulk operations.
    """
    if not action.leave_ids:
        raise HTTPException(status_code=400, detail="No leave IDs provided")
    
    if len(action.leave_ids) > 50:
        raise HTTPException(status_code=400, detail="Maximum 50 leaves per batch")
    
    # Get all pending leaves with given IDs
    leaves = db.query(LeaveRequest).filter(
        LeaveRequest.id.in_(action.leave_ids),
        LeaveRequest.status == "PENDING"
    ).all()
    
    processed_ids = []
    failed_ids = []
    success_count = 0
    
    for leave in leaves:
        try:
            leave.status = action.action
            leave.reviewed_at = datetime.utcnow()
            
            # Get reviewer
            reviewer = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
            if reviewer:
                leave.reviewer_id = reviewer.id
            
            success_count += 1
            processed_ids.append(leave.id)
            
            # Send notification
            student = db.query(User).filter(User.id == leave.student_id).first()
            if student:
                notification_service.send_leave_status_notification(
                    db=db,
                    student_id=leave.student_id,
                    status=action.action,
                    leave_id=leave.id,
                    date_range=f"{leave.from_date} to {leave.to_date}"
                )
        except Exception as e:
            failed_ids.append({"id": leave.id, "error": str(e)})
    
    db.commit()
    
    return BatchActionResponse(
        success=True,
        message=f"Processed {success_count} leave requests",
        action=action.action,
        processed_ids=processed_ids,
        failed_ids=failed_ids,
        total_count=len(action.leave_ids),
        success_count=success_count
    )


@router.delete("/{leave_id}", response_model=APIResponse)
async def cancel_leave(
    leave_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Cancel a pending leave request.
    
    Only the student who created the leave can cancel it.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    leave = db.query(LeaveRequest).filter(
        LeaveRequest.id == leave_id,
        LeaveRequest.student_id == user.id
    ).first()
    
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found or unauthorized")
    
    if leave.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel leave with status: {leave.status}"
        )
    
    db.delete(leave)
    db.commit()
    
    return APIResponse(
        success=True,
        message="Leave request cancelled successfully"
    )

