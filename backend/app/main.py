from fastapi import FastAPI
from app.api.health import router as health_router

app = FastAPI(
    title="Smart Attendance System",
    version="1.0.0"
)

app.include_router(health_router)

@app.get("/")
def root():
    return {"message": "Smart Attendance Backend Running"}
