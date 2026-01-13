from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.security import get_current_user
from app.schemas.leave import FCMTokenCreate, FCMTokenResponse, APIResponse
from app.db.models import FCMToken, User

router = APIRouter(prefix="/notifications", tags=["Push Notifications"])


@router.post("/fcm-token", response_model=APIResponse)
async def save_fcm_token(
    token_data: FCMTokenCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Save FCM token for the current user.
    
    This token is used to send push notifications to the user's device.
    """
    # Get or create user in database
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        user = User(
            firebase_uid=current_user["uid"],
            email=current_user.get("email", ""),
            name=current_user.get("name", "User"),
            role="STUDENT"
        )
        db.add(user)
        db.flush()
        db.refresh(user)

    # Check if token already exists for this user
    existing_token = db.query(FCMToken).filter(
        FCMToken.user_id == user.id,
        FCMToken.token == token_data.token
    ).first()

    if existing_token:
        # Update device type and timestamp
        existing_token.device_type = token_data.device_type
        db.commit()
        return APIResponse(
            success=True,
            message="FCM token updated successfully"
        )

    # Create new FCM token entry
    fcm_token = FCMToken(
        user_id=user.id,
        token=token_data.token,
        device_type=token_data.device_type
    )

    db.add(fcm_token)
    db.commit()

    return APIResponse(
        success=True,
        message="FCM token saved successfully"
    )


@router.delete("/fcm-token", response_model=APIResponse)
async def delete_fcm_token(
    token: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete FCM token for the current user.
    
    Called when user logs out or uninstalls the app.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    token_entry = db.query(FCMToken).filter(
        FCMToken.user_id == user.id,
        FCMToken.token == token
    ).first()

    if not token_entry:
        raise HTTPException(status_code=404, detail="Token not found")

    db.delete(token_entry)
    db.commit()

    return APIResponse(
        success=True,
        message="FCM token deleted successfully"
    )


@router.get("/tokens", response_model=list)
async def get_my_tokens(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all FCM tokens for the current user.
    
    Useful for debugging or account management.
    """
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        return []

    tokens = db.query(FCMToken).filter(FCMToken.user_id == user.id).all()
    return [
        {
            "id": t.id,
            "token": t.token,
            "device_type": t.device_type,
            "created_at": t.created_at
        }
        for t in tokens
    ]

