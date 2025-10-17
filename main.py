import os
import json
import random
from typing import List, Optional, Dict
from datetime import date

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import PlainTextResponse  # <--- added
from sqlmodel import Field, SQLModel, Session, create_engine, select, Relationship, delete, func
from sqlalchemy.exc import IntegrityError

import firebase_admin
from firebase_admin import credentials, auth

# --- 1. KONFİGÜRASYON ---
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
engine = create_engine(DATABASE_URL, echo=False)
try:
    cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"KRİTİK HATA: Firebase Admin SDK başlatılamadı. Hata: {e}")

# --- SABİTLER ---
SUBSCRIPTION_LIMITS = {
    "free": {"quiz_limit": 3, "challenge_limit": 3},
    "pro": {"quiz_limit": 5, "challenge_limit": 5},
    "ultra": {"quiz_limit": float('inf'), "challenge_limit": float('inf')},
}

# Yeni: çeviri sözlüğü — günlük quiz ve challenge limiti için birçok dil
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

# --- 2. VERİ MODELLERİ ---
class UserSubscription(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); level: str = Field(default="free"); expires_at: Optional[date] = Field(default=None)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="subscription")
class DailyLimits(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    quiz_count: int = Field(default=0)
    challenge_count: int = Field(default=0)
    questions_answered: int = Field(default=0)   # added: today's answered count
    last_reset: date = Field(default_factory=date.today)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="daily_limits")
class UserStreak(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); streak_count: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="streak")
class UserScore(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); score: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="score")
# Added history table so leaderboard can aggregate historical points if present
class UserScoreHistory(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); user_id: int = Field(foreign_key="user.id", index=True); points: int = Field(default=0); timestamp: Optional[date] = Field(default_factory=date.today)
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); firebase_uid: str = Field(unique=True, index=True); email: Optional[str] = None; language_code: str = Field(default="en")
    score: Optional[UserScore] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    streak: Optional[UserStreak] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    subscription: Optional[UserSubscription] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    daily_limits: Optional[DailyLimits] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); question_texts: str; options_texts: str; correct_answer_index: int; category: str = Field(index=True)
class Challenge(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True); challenge_texts: str; category: str = Field(default="fun", index=True)
class UserAnsweredQuestion(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True); quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)
class UserCompletedChallenge(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True); challenge_id: int = Field(foreign_key="challenge.id", primary_key=True)
class AnswerPayload(SQLModel): question_id: int; answer_index: int
class AnswerResponse(SQLModel): correct: bool; correct_index: int; score_awarded: int; new_score: int
class ChallengeResponse(SQLModel): id: int; challenge_text: str; category: str

# --- 3. GÜVENLİK, OTURUMLAR VE YARDIMCI FONKSİYONLAR ---
token_auth_scheme = HTTPBearer()
def get_session():
    with Session(engine) as session: yield session

def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session: Session = Depends(get_session)) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid Firebase token: {e}")
    db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
    if db_user:
        return db_user
    else:
        try:
            new_user = User(
                firebase_uid=uid, email=decoded_token.get('email'),
                score=UserScore(), streak=UserStreak(),
                subscription=UserSubscription(), daily_limits=DailyLimits()
            )
            session.add(new_user); session.commit(); session.refresh(new_user)
            return new_user
        except IntegrityError:
            session.rollback()
            db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
            if not db_user: raise HTTPException(status_code=500, detail="Could not retrieve user after race condition.")
            return db_user
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create new user: {e}")

def _get_user_access_level(db_user: User, session: Session) -> Dict:
    today = date.today()
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not limits:
        limits = DailyLimits(user_id=db_user.id)
        session.add(limits); session.commit(); session.refresh(limits)
    sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    if not sub:
        sub = UserSubscription(user_id=db_user.id)
        session.add(sub); session.commit(); session.refresh(sub)
    if sub.expires_at and sub.expires_at < today:
        sub.level, sub.expires_at = "free", None
        session.add(sub); session.commit()
    # reset daily counters at day boundary
    if limits.last_reset < today:
        limits.quiz_count = 0
        limits.challenge_count = 0
        limits.questions_answered = 0
        limits.last_reset = today
        session.add(limits); session.commit()
    level = sub.level
    return {
        "level": level,
        "quiz_count": limits.quiz_count,
        "challenge_count": limits.challenge_count,
        "questions_answered": limits.questions_answered,
        "quiz_limit": SUBSCRIPTION_LIMITS[level]["quiz_limit"],
        "challenge_limit": SUBSCRIPTION_LIMITS[level]["challenge_limit"],
        "daily_limits_obj": limits
    }

def _get_rank_name(score: int) -> str:
    if score >= 10000: return 'Üstad'
    if score >= 5000: return 'Elmas'
    if score >= 2000: return 'Altın'
    if score >= 1000: return 'Gümüş'
    if score >= 500: return 'Bronz'
    return 'Demir'

# --- 4. UYGULAMA BAŞLANGIÇ OLAYLARI ---
def create_db_and_tables(): SQLModel.metadata.create_all(engine)
app = FastAPI(title="SparkUp Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
@app.on_event("startup")
def on_startup(): create_db_and_tables()

# --- 5. API ENDPOINT'LERİ ---
@app.get("/user/profile/")
def get_user_profile(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    score_obj = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    streak_obj = session.exec(select(UserStreak).where(UserStreak.user_id == db_user.id)).first()
    sub_obj = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    score = score_obj.score if score_obj else 0

    access = _get_user_access_level(db_user, session)
    quiz_limit = access["quiz_limit"]
    used = access["questions_answered"]

    # today's points total
    today = date.today()
    sum_points = session.exec(select(func.sum(UserScoreHistory.points)).where(UserScoreHistory.user_id == db_user.id, UserScoreHistory.timestamp == today)).one()
    try:
        daily_points = int(sum_points) if sum_points else 0
    except Exception:
        # SQLAlchemy may return tuple
        daily_points = int(sum_points[0]) if isinstance(sum_points, (list, tuple)) and sum_points[0] else 0

    remaining = None
    if quiz_limit != float('inf'):
        remaining = max(0, int(quiz_limit) - int(used))

    return {
        "firebase_uid": db_user.firebase_uid,
        "email": db_user.email,
        "score": score,
        "rank_name": _get_rank_name(score),
        "current_streak": streak_obj.streak_count if streak_obj else 0,
        "subscription_level": sub_obj.level if sub_obj else "free",
        "subscription_expires": sub_obj.expires_at.isoformat() if sub_obj and sub_obj.expires_at else None,
        "language_code": db_user.language_code,
        "notifications_enabled": True,
        "topic_preferences": [],
        # daily info
        "daily_quiz_limit": None if quiz_limit == float('inf') else int(quiz_limit),
        "daily_quiz_used": int(used),
        "remaining_quizzes": remaining,
        "daily_points": int(daily_points),
    }

@app.get("/quiz/", response_model=List[Dict])
def get_quiz_questions(limit: int = 3, lang: Optional[str] = Query(None), preview: bool = Query(False), db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    access = _get_user_access_level(db_user, session)
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")

    # compute remaining allowed answers by questions_answered (not quiz_count)
    if access["quiz_limit"] != float('inf'):
        remaining = int(access["quiz_limit"]) - int(access["questions_answered"])
    else:
        remaining = None

    # Block non-preview requests when no remaining questions
    if not preview and remaining is not None and remaining <= 0 and access["level"] != "ultra":
        tpl = TRANSLATIONS.get("daily_quiz_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_quiz_limit_reached"]["en"]
        return PlainTextResponse(tpl.format(limit=access["quiz_limit"]), status_code=429)

    # build unanswered question list for the user
    answered_ids_raw = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
    # normalize results: could be list of scalars or list of one-item tuples
    answered_ids = []
    for item in answered_ids_raw:
        if isinstance(item, (list, tuple)):
            if item:
                answered_ids.append(item[0])
        else:
            answered_ids.append(item)

    if not answered_ids:
        unanswered = session.exec(select(QuizQuestion)).all()
    else:
        unanswered = session.exec(select(QuizQuestion).where(QuizQuestion.id.notin_(answered_ids))).all()

    # cap questions returned to remaining if applicable
    actual_limit = limit
    if remaining is not None and remaining < limit:
        actual_limit = max(0, remaining)

    chosen = []
    if actual_limit == 0:
        chosen = []
    elif len(unanswered) >= actual_limit:
        chosen = random.sample(unanswered, actual_limit)
    else:
        # not enough unanswered
        if not preview:
            # reset answered list then pick from all; do NOT increment quiz_count here
            session.exec(delete(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id))
            session.commit()
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < actual_limit:
                raise HTTPException(status_code=404, detail="Not enough new questions.")
            chosen = random.sample(all_qs, actual_limit)
        else:
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < actual_limit:
                raise HTTPException(status_code=404, detail="Not enough questions for preview.")
            chosen = random.sample(all_qs, actual_limit)

    def _get_text(obj_field, q):
        try:
            data = json.loads(getattr(q, obj_field) or "{}")
            return data.get(effective_lang) or data.get("en") or ""
        except Exception:
            return ""

    result = []
    for q in chosen:
        question_text = _get_text("question_texts", q)
        options_raw = _get_text("options_texts", q)
        if isinstance(options_raw, str):
            try:
                options_parsed = json.loads(options_raw)
            except Exception:
                options_parsed = [options_raw]
        else:
            options_parsed = options_raw or []
        result.append({
            "id": q.id,
            "question_text": question_text,
            "options": options_parsed,
            "correct_answer_index": q.correct_answer_index
        })

    return result

@app.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found.")
    user_score = session.exec(select(UserScore).where(UserScore.user_id==db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id==db_user.id)).first()
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not user_score or not user_streak or not limits:
        raise HTTPException(status_code=500, detail="User data missing.")

    access = _get_user_access_level(db_user, session)
    # enforce daily cap
    if access["quiz_limit"] != float('inf') and access["questions_answered"] >= access["quiz_limit"] and access["level"] != "ultra":
        tpl = TRANSLATIONS.get("daily_quiz_limit_reached", {}).get(db_user.language_code or "en") or TRANSLATIONS["daily_quiz_limit_reached"]["en"]
        return PlainTextResponse(tpl.format(limit=access["quiz_limit"]), status_code=429)

    already_answered = session.exec(select(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id, UserAnsweredQuestion.quizquestion_id == payload.question_id)).first()
    is_correct = (question.correct_answer_index == payload.answer_index)
    score_awarded = 0
    if not already_answered:
        if is_correct:
            base_score = 10
            streak_bonus = min(user_streak.streak_count, 5) * 2
            score_awarded = base_score + streak_bonus
            user_score.score += score_awarded
            user_streak.streak_count += 1
            # save history for daily points
            try:
                session.add(UserScoreHistory(user_id=db_user.id, points=score_awarded))
            except Exception:
                pass
        else:
            user_streak.streak_count = 0

        session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
        # increment today's answered count
        limits.questions_answered = (limits.questions_answered or 0) + 1

        session.add(user_score); session.add(user_streak); session.add(limits)
        session.commit()
        session.refresh(user_score); session.refresh(user_streak); session.refresh(limits)

    return AnswerResponse(correct=is_correct, correct_index=question.correct_answer_index, score_awarded=score_awarded, new_score=user_score.score)

@app.put("/user/language/")
def set_user_language(language_code: str = Query(...), db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    try:
        db_user.language_code = language_code
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
        return {"language_code": db_user.language_code}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update language: {e}")
    
@app.get("/challenges/random/", response_model=ChallengeResponse)
def get_random_challenge(
    lang: Optional[str] = Query(None),
    preview: bool = Query(False),
    consume: bool = Query(True),   # <-- yeni parametre
    db_user: User = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")
    access = _get_user_access_level(db_user, session)

    # Fast pre-check: if user already exhausted -> return limit message (no DB mutation)
    if not preview:
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

    # preview mode: do not touch DB at all
    if preview:
        all_ch = session.exec(select(Challenge)).all()
        if not all_ch:
            raise HTTPException(status_code=404, detail="No challenges available.")
        chosen_challenge = random.choice(all_ch)
        texts = {}
        try:
            texts = json.loads(chosen_challenge.challenge_texts or "{}")
        except Exception:
            texts = {}
        challenge_text = texts.get(effective_lang) or texts.get("en") or ""
        return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

    # From here: non-preview. If consume==False -> check limits and return candidate WITHOUT mutating DB.
    # Build answered/unanswered lists
    completed_ids_raw = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
    completed_ids = []
    for item in completed_ids_raw:
        if isinstance(item, (list, tuple)):
            if item:
                completed_ids.append(item[0])
        else:
            completed_ids.append(item)

    unanswered = session.exec(select(Challenge).where(Challenge.id.notin_(completed_ids))).all()

    # If no unanswered: either reset (only if consuming) or pick random (non-consuming)
    if not unanswered:
        # re-check limits before any reset/consume
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

        if consume:
            # safe reset and then pick
            session.exec(delete(UserCompletedChallenge).where(UserCompletedChallenge.user_id == db_user.id))
            session.commit()
            unanswered = session.exec(select(Challenge)).all()
            if not unanswered:
                raise HTTPException(status_code=404, detail="No challenges available.")
        else:
            # not consuming: just return any random challenge (do not mutate DB)
            all_ch = session.exec(select(Challenge)).all()
            if not all_ch:
                raise HTTPException(status_code=404, detail="No challenges available.")
            chosen_challenge = random.choice(all_ch)
            texts = {}
            try:
                texts = json.loads(chosen_challenge.challenge_texts or "{}")
            except Exception:
                texts = {}
            challenge_text = texts.get(effective_lang) or texts.get("en") or ""
            return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

    # choose a challenge
    chosen_challenge = random.choice(unanswered)

    # If consuming, persist completion and increment counter
    if consume:
        # re-read fresh limits and guard (to reduce race window)
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

        session.add(UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen_challenge.id))
        if fresh_limits:
            fresh_limits.challenge_count = (fresh_limits.challenge_count or 0) + 1
            session.add(fresh_limits)
        else:
            new_limits = DailyLimits(user_id=db_user.id, challenge_count=1)
            session.add(new_limits)
        session.commit()

    texts = {}
    try:
        texts = json.loads(chosen_challenge.challenge_texts or "{}")
    except Exception:
        texts = {}
    challenge_text = texts.get(effective_lang) or texts.get("en") or ""
    return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

@app.get("/leaderboard/")
def get_leaderboard(limit: int = 100, session: Session = Depends(get_session)):
    """
    Return top users sorted by score. Each item: {rank, email, username, score}
    """
    rows = session.exec(
        select(User, UserScore)
        .join(UserScore, User.id == UserScore.user_id, isouter=True)
        .order_by(UserScore.score.desc().nullslast())
        .limit(limit)
    ).all()

    result = []
    rank = 1
    for pair in rows:
        user = pair[0]
        score_obj = pair[1] if len(pair) > 1 else None
        score = score_obj.score if score_obj else 0
        # try username fields, fallback to display_name or email local-part
        username = getattr(user, "username", None) or getattr(user, "display_name", None)
        if not username and getattr(user, "email", None):
            username = user.email.split("@", 1)[0]
        result.append({"rank": rank, "email": user.email, "username": username, "score": score})
        rank += 1
    return result

@app.get("/user/rank/")
def get_user_rank(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    """
    Return current user's rank entry {rank, email, username, score}.
    """
    user_score_obj = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    user_score = user_score_obj.score if user_score_obj else 0

    higher_count = session.exec(
        select(func.count()).select_from(UserScore).where(UserScore.score > user_score)
    ).one()
    try:
        higher_count_val = int(higher_count)
    except Exception:
        higher_count_val = int(higher_count[0]) if isinstance(higher_count, (list, tuple)) else 0

    rank = higher_count_val + 1
    username = getattr(db_user, "username", None) or getattr(db_user, "display_name", None)
    if not username and getattr(db_user, "email", None):
        username = db_user.email.split("@", 1)[0]
    return {"rank": rank, "email": db_user.email, "username": username, "score": user_score}

@app.get("/quiz/localize/")
def localize_quiz(ids: str = Query(..., description="Comma separated quiz ids"), lang: Optional[str] = Query(None), session: Session = Depends(get_session)):
    """
    Return the same quiz questions by id but with localized texts.
    Does NOT consume user limits or mutate DB.
    """
    effective_lang = lang or "en"
    # Safely parse comma separated ids
    try:
        id_list = []
        for s in ids.split(","):
            s2 = s.strip()
            if not s2:
                continue
            id_list.append(int(s2))
        if not id_list:
            raise ValueError("no ids")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid ids parameter")

    qs = session.exec(select(QuizQuestion).where(QuizQuestion.id.in_(id_list))).all()

    def _get_text(obj_field, q):
        try:
            data = json.loads(getattr(q, obj_field) or "{}")
            return data.get(effective_lang) or data.get("en") or ""
        except Exception:
            return ""

    result = []
    for q in qs:
        question_text = _get_text("question_texts", q)
        options_raw = _get_text("options_texts", q)
        options_parsed = []
        if isinstance(options_raw, str):
            try:
                options_parsed = json.loads(options_raw)
            except Exception:
                options_parsed = [options_raw]
        else:
            options_parsed = options_raw or []
        result.append({
            "id": q.id,
            "question_text": question_text,
            "options": options_parsed,
            "correct_answer_index": q.correct_answer_index
        })
    return result

@app.get("/challenges/{challenge_id}/localize/", response_model=ChallengeResponse)
def localize_challenge(challenge_id: int, lang: Optional[str] = Query(None), session: Session = Depends(get_session)):
    """
    Return the same challenge by id but with localized text.
    Does NOT consume user limits or mutate DB.
    """
    effective_lang = lang or "en"
    ch = session.get(Challenge, challenge_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Challenge not found.")
    texts = {}
    try:
        texts = json.loads(ch.challenge_texts or "{}")
    except Exception:
        texts = {}
    challenge_text = texts.get(effective_lang) or texts.get("en") or ""
    return ChallengeResponse(id=ch.id, challenge_text=challenge_text, category=ch.category)