from sqlmodel import create_engine, Session, SQLModel
from .config import DATABASE_URL

engine = create_engine(DATABASE_URL, echo=False)

def get_session():
    with Session(engine) as session:
        yield session

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

def _ensure_schema_compat():
    # lightweight compat helper retained from monolith
    from sqlalchemy import text
    with engine.connect() as conn:
        try:
            res = conn.execute(text("PRAGMA table_info('user')")).fetchall()
            cols = [r[1] for r in res]
            if 'notifications_enabled' not in cols:
                conn.execute(text("ALTER TABLE user ADD COLUMN notifications_enabled BOOLEAN DEFAULT 1"))
        except Exception:
            try:
                conn.execute(text("ALTER TABLE user ADD COLUMN notifications_enabled BOOLEAN DEFAULT 1"))
            except Exception:
                pass

        try:
            res = conn.execute(text("PRAGMA table_info('dailylimits')")).fetchall()
            cols = [r[1] for r in res]
            if 'notifications_sent' not in cols:
                conn.execute(text("ALTER TABLE dailylimits ADD COLUMN notifications_sent INTEGER DEFAULT 0"))
        except Exception:
            try:
                conn.execute(text("ALTER TABLE dailylimits ADD COLUMN notifications_sent INTEGER DEFAULT 0"))
            except Exception:
                pass

        # Ensure DeviceToken has last_seen column (older DBs may not have it)
        try:
            res = conn.execute(text("PRAGMA table_info('devicetoken')")).fetchall()
            cols = [r[1] for r in res]
            if 'last_seen' not in cols:
                # SQLite supports ADD COLUMN; add as DATE/NULL default
                conn.execute(text("ALTER TABLE devicetoken ADD COLUMN last_seen DATE DEFAULT NULL"))
        except Exception:
            try:
                conn.execute(text("ALTER TABLE devicetoken ADD COLUMN last_seen DATE DEFAULT NULL"))
            except Exception:
                pass
