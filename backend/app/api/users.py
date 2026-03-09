from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional, List
from pydantic import BaseModel
import json

from app.db.database import get_db
from app.core.security import get_current_user
from app.db.models import User
from app.services.face_service import encode_face, embedding_to_string

router = APIRouter(tags=["User Management"])


class UserResponse(BaseModel):
    id: int
    firebase_uid: str
    email: str
    name: str
    role: str
    face_registered: bool

    class Config:
        from_attributes = True


class RegisterFaceRequest(BaseModel):
    image_base64: str


class RegisterFaceResponse(BaseModel):
    success: bool
    message: str


class UserProfileResponse(BaseModel):
    id: int
    firebase_uid: str
    email: str
    name: str
    role: str
    face_registered: bool


@router.get("/", response_model=List[UserResponse])
async def get_all_users(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Verify user is admin or teacher
        user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        if user.role not in ["ADMIN", "TEACHER"]:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get all users
        users = db.query(User).all()
        return [
            UserResponse(
                id=user.id,
                firebase_uid=user.firebase_uid,
                email=user.email,
                name=user.name,
                role=user.role,
                face_registered=bool(user.face_embedding)
            )
            for user in users
        ]
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching users: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/info")
async def users_root():
    """Root users endpoint - provides available endpoints"""
    return {
        "message": "User Management API",
        "available_endpoints": {
            "GET /users/": "Get all users (admin/teacher only)",
            "GET /users/me": "Get current user profile",
            "POST /users/register-face": "Register face for biometric attendance"
        }
    }


@router.get("/me", response_model=UserProfileResponse)
async def get_current_user_profile(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Find user by Firebase UID
        user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        return {
            "id": user.id,
            "firebase_uid": user.firebase_uid,
            "email": user.email,
            "name": user.name,
            "role": user.role,
            "face_registered": bool(user.face_embedding)
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching user profile: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/register-face", response_model=RegisterFaceResponse)
async def register_face(
    request: RegisterFaceRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Find user by Firebase UID
        user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Generate face embedding from uploaded image
        face_embedding = encode_face(request.image_base64)
        if face_embedding is None:
            raise HTTPException(status_code=400, detail="No face detected or multiple faces detected in image")
        
        # Store face embedding as JSON string
        user.face_embedding = embedding_to_string(face_embedding)
        db.commit()
        db.refresh(user)
        
        return {
            "success": True,
            "message": "Face registered successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Face registration error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error during face registration")
