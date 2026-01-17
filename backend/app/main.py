from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.health import router as health_router
from app.api.leave import router as leave_router
from app.api.notification import router as notification_router
from app.api.users import router as users_router
from app.api.attendance import router as attendance_router
from app.db.models import User, LeaveRequest, FCMToken, AttendanceSession, AttendanceRecord

import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Header, HTTPException

app = FastAPI(
    title="Smart Attendance System",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(leave_router)
app.include_router(notification_router)
app.include_router(users_router)
app.include_router(attendance_router)

@app.get("/")
def root():
    return {"message": "Smart Attendance Backend Running"}


@app.on_event("startup")
def startup_event():
    from app.db.database import init_db
    init_db()
    print("Database tables created successfully!")




try:
    cred = credentials.Certificate("firebase_key.json")
    firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"Firebase initialization warning: {e}")

def get_current_user(authorization: str = Header(...)):
    try:
        token = authorization.split(" ")[1]
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid or missing token: {str(e)}")

