import os
import json
from typing import List, Dict
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

# Subscription limits
SUBSCRIPTION_LIMITS = {
    "free": {"quiz_limit": 3, "challenge_limit": 3},
    "pro": {"quiz_limit": 5, "challenge_limit": 5},
    "ultra": {"quiz_limit": float('inf'), "challenge_limit": float('inf')},
}

# New subscription access model: energy per day and session length in seconds
SUBSCRIPTION_ACCESS = {
    "free": {"energy_per_day": 3, "session_seconds": 60},
    "pro": {"energy_per_day": 5, "session_seconds": 60},
    "ultra": {"energy_per_day": 5, "session_seconds": 90},
}

TRANSLATIONS = {
    "daily_quiz_limit_reached": {
        "en": "Daily quiz limit reached ({limit}).",
        "tr": "Günlük quiz limiti doldu ({limit}).",
        "de": "Tägliches Quiz‑Limit erreicht ({limit}).",
        "fr": "Limite quotidienne de quiz atteinte ({limit}).",
        "it": "Limite giornaliera dei quiz raggiunta ({limit}).",
        "es": "Límite diario de cuestionarios alcanzado ({limit}).",
        "zh": "每日测验次数已达上限（{limit}）。",
        "ja": "1日のクイズ上限に達しました（{limit}）。",
        "hi": "दैनिक क्विज़ सीमा पहुँच गई ({limit}).",
        "ar": "تم الوصول إلى الحد اليومي للاختبارات ({limit}).",
        "ru": "Достигнут суточный лимит викторин ({limit})."
    },
    "daily_challenge_limit_reached": {
        "en": "Daily challenge limit reached ({limit}).",
        "tr": "Günlük challenge limiti doldu ({limit}).",
        "de": "Tägliches Challenge‑Limit erreicht ({limit}).",
        "fr": "Limite quotidienne de challenge atteinte ({limit}).",
        "it": "Limite giornaliera delle challenge raggiunta ({limit}).",
        "es": "Límite diario de challenge alcanzado ({limit}).",
        "zh": "每日挑战次数已达上限（{limit}）。",
        "ja": "1日のチャレンジ上限に達しました（{limit}）。",
        "hi": "दैनिक चैलेंज सीमा पहुँच गई ({limit}).",
        "ar": "تم الوصول إلى الحد اليومي للتحديات ({limit}).",
        "ru": "Достигнут суточный лимит челленджей ({limit})."
    }
}

NOTIFICATION_FREQUENCY = {"free": 1, "pro": 2, "ultra": 3}

# runtime-loaded manual infos
MANUAL_INFOS: List[Dict] = []
# runtime-loaded manual true/false questions
MANUAL_TRUEFALSE: List[Dict] = []

def load_manual_infos(path: str = "data/manual_info.json"):
    global MANUAL_INFOS
    try:
        with open(path, "r", encoding="utf-8") as f:
            MANUAL_INFOS = json.load(f)
            if not isinstance(MANUAL_INFOS, list):
                MANUAL_INFOS = []
    except Exception as e:
        print(f"Failed to load {path}: {e}")
        MANUAL_INFOS = []


def load_manual_truefalse(path: str = "data/manual_truefalse.json"):
    """Load the manual true/false JSON from disk for runtime use.
    The file is expected to be located at the repository root `data/` directory.
    """
    global MANUAL_TRUEFALSE
    # Allow override via environment variable for debugging or deployed setups
    env_path = os.getenv('MANUAL_TRUEFALSE_PATH')
    candidates = [
        path,
        os.path.abspath(path),
        os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'manual_truefalse.json'),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'manual_truefalse.json'),
        os.path.join(os.getcwd(), 'data', 'manual_truefalse.json'),
    ]
    if env_path:
        candidates.insert(0, env_path)
    loaded = False
    for p in candidates:
        try:
            if not os.path.exists(p):
                continue
            with open(p, "r", encoding="utf-8") as f:
                loaded_list = json.load(f)
                if not isinstance(loaded_list, list):
                    continue
                # mutate existing list object so other modules that imported it see updates
                MANUAL_TRUEFALSE.clear()
                MANUAL_TRUEFALSE.extend(loaded_list)
                loaded = True
                break
        except Exception:
            # intentionally silent to avoid noisy logs in normal operation
            continue
    if not loaded:
        MANUAL_TRUEFALSE.clear()


# Try initializing Firebase Admin if credentials path provided
try:
    if GOOGLE_APPLICATION_CREDENTIALS:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"Warning: Firebase Admin initialization failed: {e}")
