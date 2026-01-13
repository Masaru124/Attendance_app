import logging
from typing import Optional
from sqlalchemy.orm import Session
from firebase_admin import messaging, credentials
from app.db.models import FCMToken, User

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for sending push notifications via Firebase Cloud Messaging"""

    def __init__(self):
        self.initialized = True

    def send_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[dict] = None
    ) -> bool:
        """
        Send a push notification to a single device.

        Args:
            token: FCM token of the target device
            title: Notification title
            body: Notification body
            data: Optional additional data payload

        Returns:
            bool: True if notification was sent successfully
        """
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                token=token,
                data=data or {},
            )

            response = messaging.send(message)
            logger.info(f"Successfully sent notification: {response}")
            return True

        except Exception as e:
            logger.error(f"Error sending notification: {e}")
            return False

    def send_leave_status_notification(
        self,
        db: Session,
        student_id: int,
        status: str,
        leave_id: int,
        date_range: str
    ) -> bool:
        """
        Send notification to student about their leave status.

        Args:
            db: Database session
            student_id: ID of the student
            status: APPROVED or REJECTED
            leave_id: ID of the leave request
            date_range: Formatted date range string

        Returns:
            bool: True if notification was sent successfully
        """
        # Get student's FCM tokens
        fcm_tokens = db.query(FCMToken).filter(
            FCMToken.user_id == student_id
        ).all()

        if not fcm_tokens:
            logger.warning(f"No FCM tokens found for student {student_id}")
            return False

        # Create notification content
        if status == "APPROVED":
            title = "Leave Approved ✅"
            body = f"Your leave request for {date_range} has been approved."
        else:
            title = "Leave Rejected ❌"
            body = f"Your leave request for {date_range} has been rejected."

        # Send to all student's devices
        success_count = 0
        for fcm_token in fcm_tokens:
            if self.send_notification(
                token=fcm_token.token,
                title=title,
                body=body,
                data={
                    "type": "LEAVE_STATUS",
                    "leave_id": str(leave_id),
                    "status": status,
                }
            ):
                success_count += 1

        logger.info(
            f"Sent leave notification to {success_count}/{len(fcm_tokens)} devices "
            f"for student {student_id}"
        )

        return success_count > 0

    def send_bulk_notification(
        self,
        tokens: list,
        title: str,
        body: str,
        data: Optional[dict] = None
    ) -> int:
        """
        Send notification to multiple devices.

        Args:
            tokens: List of FCM tokens
            title: Notification title
            body: Notification body
            data: Optional additional data payload

        Returns:
            int: Number of successful deliveries
        """
        if not tokens:
            return 0

        try:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                tokens=tokens,
                data=data or {},
            )

            response = messaging.send_each_for_multicast(message)
            logger.info(
                f"Sent {response.success_count} notifications, "
                f"{response.failure_count} failed"
            )
            return response.success_count

        except Exception as e:
            logger.error(f"Error sending bulk notification: {e}")
            return 0

    def get_user_tokens(self, db: Session, user_id: int) -> list:
        """Get all FCM tokens for a user"""
        tokens = db.query(FCMToken).filter(
            FCMToken.user_id == user_id
        ).all()
        return [t.token for t in tokens if t.token]


# Singleton instance
notification_service = NotificationService()

