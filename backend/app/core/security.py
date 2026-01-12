import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Header, HTTPException

cred = credentials.Certificate("firebase_key.json")
firebase_admin.initialize_app(cred)

def get_current_user(authorization: str = Header(...)):
    try:
        token = authorization.split(" ")[1]
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or missing token")
