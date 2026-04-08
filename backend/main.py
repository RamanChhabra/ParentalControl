"""
Parental Control Backend - FastAPI + Firebase Admin.
Setup: Place Firebase service account JSON as backend/serviceAccount.json
Run: python3 -m uvicorn main:app --reload
      (or: ./run.sh)
"""
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Firebase Admin is initialized in lifespan so we can use async startup.
firebase_app = None
firestore_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global firebase_app, firestore_client
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        from google.cloud.firestore_v1 import Query
        cred_path = os.path.join(os.path.dirname(__file__), "file/service-key.json")
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_app = firebase_admin.initialize_app(cred)
            firestore_client = firestore.client()
        else:
            firestore_client = None  # Run without Firebase for local dev
    except Exception:
        firestore_client = None
    yield
    if firebase_app is not None:
        try:
            import firebase_admin
            firebase_admin.delete_app(firebase_app)
        except Exception:
            pass


app = FastAPI(title="Parental Control API", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db():
    if firestore_client is None:
        raise HTTPException(status_code=503, detail="Firebase not configured")
    return firestore_client


@app.get("/health")
def health():
    return {"status": "ok", "firebase": firestore_client is not None}


@app.get("/device/{device_id}/usage")
def get_device_usage(device_id: str, limit: int = 100):
    """Get app usage for a device (e.g. for parent dashboard or reports)."""
    db = get_db()
    col = db.collection("app_usage")
    query = col.where("device_id", "==", device_id).order_by("timestamp", direction=Query.DESCENDING).limit(limit)
    docs = list(query.stream())
    out = []
    for d in docs:
        data = d.to_dict()
        ts = data.get("timestamp")
        if hasattr(ts, "isoformat"):
            data["timestamp"] = ts.isoformat()
        out.append({"id": d.id, **data})
    return out


@app.get("/device/{device_id}/location")
def get_device_location(device_id: str, limit: int = 50):
    """Get location history for a device."""
    db = get_db()
    col = db.collection("location_logs")
    query = col.where("device_id", "==", device_id).order_by("timestamp", direction=Query.DESCENDING).limit(limit)
    docs = list(query.stream())
    out = []
    for d in docs:
        data = d.to_dict()
        ts = data.get("timestamp")
        if hasattr(ts, "isoformat"):
            data["timestamp"] = ts.isoformat()
        out.append({"id": d.id, **data})
    return out


@app.get("/device/{device_id}/rules")
def get_device_rules(device_id: str):
    """Get parental rules for a device."""
    db = get_db()
    col = db.collection("rules")
    query = col.where("device_id", "==", device_id).limit(1)
    docs = list(query.stream())
    if not docs:
        return {"device_id": device_id, "blocked_packages": [], "screen_time_limit_minutes": None}
    data = docs[0].to_dict()
    ts = data.get("updated_at")
    if hasattr(ts, "isoformat"):
        data["updated_at"] = ts.isoformat()
    return data
