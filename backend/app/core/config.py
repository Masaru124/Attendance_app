import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    DATABASE_URL = os.getenv("DATABASE_URL")
    FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")

settings = Settings()
