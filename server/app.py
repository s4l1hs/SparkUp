import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import load_manual_infos, load_manual_truefalse
from .db import create_db_and_tables, _ensure_schema_compat
from .routes import router

app = FastAPI(title="SparkUp Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def on_startup():
    create_db_and_tables()
    load_manual_infos()
    # Ensure manual_truefalse.json is loaded from the repository-root `data/` directory.
    try:
        repo_root = os.path.dirname(os.path.dirname(__file__))
        tf_path = os.path.join(repo_root, 'data', 'manual_truefalse.json')
        print(f"[startup] Loading manual_truefalse from: {tf_path}")
        load_manual_truefalse(tf_path)
    except Exception as e:
        print(f"[startup] Failed to call load_manual_truefalse with explicit path: {e}")
    try:
        _ensure_schema_compat()
    except Exception as e:
        print(f"Schema compatibility check failed: {e}")


app.include_router(router)
