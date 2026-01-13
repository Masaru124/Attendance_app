from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.database import get_db
from app.db.models import User
from app.core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class UserResponse(BaseModel):
    id: int
    firebase_uid: str
    email: str
    name: str
    role: str

    class Config:
        from_attributes = True

class UpdateRoleRequest(BaseModel):
    role: str

@router.get("/users", response_model=List[UserResponse])
async def get_all_users(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all users - Admin only"""
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin access required")

    users = db.query(User).all()
    return users

@router.put("/users/{user_id}/role", response_model=UserResponse)
async def update_user_role(
    user_id: int,
    request: UpdateRoleRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update user role - Admin only"""
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin access required")

    # Validate role
    if request.role.upper() not in ["STUDENT", "TEACHER", "ADMIN"]:
        raise HTTPException(status_code=400, detail="Invalid role")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.role = request.role.upper()
    db.commit()
    db.refresh(user)
    return user
