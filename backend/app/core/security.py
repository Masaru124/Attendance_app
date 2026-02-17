from functools import wraps
from fastapi import Header, HTTPException, Depends, status
from typing import List
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import User


def get_current_user(authorization: str = Header(None)):
   
    from firebase_admin import auth
    try:
        if authorization is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing authorization header"
            )
        
        # Handle both "Bearer <token>" and raw token formats
        parts = authorization.split(" ")
        if len(parts) == 2:
            token = parts[1]
        else:
            token = authorization
            
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or missing token: {str(e)}"
        )


def _get_user_role_from_db(firebase_uid: str, db: Session) -> str:
  
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if user:
        return user.role
    return "STUDENT"


def verify_role(allowed_roles: List[str]):
   
    def role_verifier(
        current_user: dict = Depends(get_current_user),
        db: Session = Depends(get_db)
    ) -> dict:
        
        user_role = current_user.get("role")
        
        if user_role is None or user_role == "":
            user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
        
        if user_role is None or user_role == "":
            user_role = "STUDENT"
        
        if "ADMIN" in allowed_roles and user_role == "ADMIN":
            return current_user
        
        if user_role in allowed_roles:
            return current_user
        
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied. Required roles: {', '.join(allowed_roles)}. Your role: {user_role}"
        )
    
    return role_verifier


def require_admin(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    
    user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
    if user_role != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user


def require_teacher(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
   
    user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
    if user_role not in ["TEACHER", "ADMIN"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher or Admin access required"
        )
    return current_user


def require_student(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    
    user_role = _get_user_role_from_db(current_user.get("uid", ""), db)
    if user_role != "STUDENT":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required"
        )
    return current_user

