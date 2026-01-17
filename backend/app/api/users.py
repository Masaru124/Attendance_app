from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.database import get_db
from app.db.models import User
from app.core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

def _get_user_role_from_db(firebase_uid: str, db: Session) -> str:
  
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if user:
        return user.role
    return "STUDENT"

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

@router.get("/users/me", response_model=UserResponse)
async def get_current_user_profile(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
 
    firebase_uid = current_user.get("uid", "")
    
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    
    if not user:
        user = User(
            firebase_uid=firebase_uid,
            email=current_user.get("email", ""),
            name=current_user.get("name", "User"),
            role="STUDENT"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    return user

@router.get("/users", response_model=List[UserResponse])
async def get_all_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
    if user_role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin access required")

    users = db.query(User).all()
    return users

@router.put("/users/{user_id}/role", response_model=UserResponse)
async def update_user_role(
    user_id: int,
    request: UpdateRoleRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
   
    user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
    if user_role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin access required")

    if request.role.upper() not in ["STUDENT", "TEACHER", "ADMIN"]:
        raise HTTPException(status_code=400, detail="Invalid role")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.role = request.role.upper()
    db.commit()
    db.refresh(user)
    return user
