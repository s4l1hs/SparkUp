import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import load_manual_infos
from .db import create_db_and_tables, _ensure_schema_compat
from .routes import router

app = FastAPI(title="SparkUp Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def on_startup():
    create_db_and_tables()
    load_manual_infos()
    try:
        _ensure_schema_compat()
    except Exception as e:
        print(f"Schema compatibility check failed: {e}")


app.include_router(router)
