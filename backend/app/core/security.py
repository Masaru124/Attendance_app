from functools import wraps
from fastapi import Header, HTTPException, Depends, status
from typing import List


def get_current_user(authorization: str = Header(...)):
    """
    Get current authenticated user from Firebase token.
    
    Returns decoded Firebase token with user information.
    """
    from firebase_admin import auth
    try:
        token = authorization.split(" ")[1]
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or missing token: {str(e)}"
        )


def verify_role(allowed_roles: List[str]):
    """
    Dependency factory for role-based access control.
    
    Usage:
        @router.get("/admin-only")
        async def admin_endpoint(
            user: dict = Depends(verify_role(["ADMIN"]))
        ):
            pass
            
        @router.get("/protected")
        async def protected_endpoint(
            user: dict = Depends(verify_role(["STUDENT", "TEACHER", "ADMIN"]))
        ):
            pass
    """
    def role_verifier(user: dict = Depends(get_current_user)) -> dict:
        """
        Verify that the current user has one of the allowed roles.
        
        Note: For STUDENT role, we check if no specific role is set (defaults to student)
        or explicitly set role is STUDENT.
        """
        user_role = user.get("role", "STUDENT")
        
        # If no role in token, default to STUDENT
        if user_role is None or user_role == "":
            user_role = "STUDENT"
        
        # Super admin check - any admin can access
        if "ADMIN" in allowed_roles and user_role == "ADMIN":
            return user
        
        # Check if user's role is in allowed roles
        if user_role in allowed_roles:
            return user
        
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied. Required roles: {', '.join(allowed_roles)}. Your role: {user_role}"
        )
    
    return role_verifier


def require_admin(user: dict = Depends(get_current_user)) -> dict:
    """
    Dependency that requires ADMIN role.
    """
    user_role = user.get("role", "STUDENT")
    if user_role != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return user


def require_teacher(user: dict = Depends(get_current_user)) -> dict:
    """
    Dependency that requires TEACHER or ADMIN role.
    """
    user_role = user.get("role", "STUDENT")
    if user_role not in ["TEACHER", "ADMIN"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher or Admin access required"
        )
    return user


def require_student(user: dict = Depends(get_current_user)) -> dict:
    """
    Dependency that requires STUDENT role.
    """
    user_role = user.get("role", "STUDENT")
    if user_role != "STUDENT":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required"
        )
    return user

