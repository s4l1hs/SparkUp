import os
import json
import random
from typing import List, Optional, Dict
from datetime import date

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
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
    id: Optional[int] = Field(default=None, primary_key=True); quiz_count: int = Field(default=0); challenge_count: int = Field(default=0); last_reset: date = Field(default_factory=date.today)
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
    # ### DÜZELTME: Limit sıfırlanma sorununu çözen kısım ###
    # Limit verisini, her zaman doğrudan veritabanından SORGULAYARAK alıyoruz.
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not limits:
        limits = DailyLimits(user_id=db_user.id); session.add(limits); session.commit(); session.refresh(limits)
    sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    if not sub:
        sub = UserSubscription(user_id=db_user.id); session.add(sub); session.commit(); session.refresh(sub)
    if sub.expires_at and sub.expires_at < today:
        sub.level, sub.expires_at = "free", None; session.add(sub); session.commit()
    if limits.last_reset < today:
        limits.quiz_count, limits.challenge_count, limits.last_reset = 0, 0, today; session.add(limits); session.commit()
    level = sub.level
    return {"level": level, "quiz_count": limits.quiz_count, "challenge_count": limits.challenge_count, "quiz_limit": SUBSCRIPTION_LIMITS[level]["quiz_limit"], "challenge_limit": SUBSCRIPTION_LIMITS[level]["challenge_limit"], "daily_limits_obj": limits}

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
    return {
        "firebase_uid": db_user.firebase_uid, "email": db_user.email,
        "score": score, "rank_name": _get_rank_name(score),
        "current_streak": streak_obj.streak_count if streak_obj else 0,
        "subscription_level": sub_obj.level if sub_obj else "free",
        "subscription_expires": sub_obj.expires_at.isoformat() if sub_obj and sub_obj.expires_at else None,
        "language_code": db_user.language_code,
        "notifications_enabled": True, "topic_preferences": []
    }

@app.get("/quiz/", response_model=List[Dict])
def get_quiz_questions(limit: int = 3, lang: Optional[str] = Query(None), preview: bool = Query(False), db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    access = _get_user_access_level(db_user, session)
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")

    if not preview:
        if access["quiz_count"] >= access["quiz_limit"] and access["level"] != "ultra":
             tpl = TRANSLATIONS.get("daily_quiz_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_quiz_limit_reached"]["en"]
             raise HTTPException(status_code=429, detail=tpl.format(limit=access["quiz_limit"]))

    answered_ids = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
    unanswered = session.exec(select(QuizQuestion).where(QuizQuestion.id.notin_(answered_ids))).all()

    chosen = []
    if len(unanswered) >= limit:
        chosen = random.sample(unanswered, limit)
    else:
        # if not enough unanswered:
        if not preview:
            # original behavior: reset answered and take from all
            session.exec(delete(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id))
            session.commit()
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < limit:
                raise HTTPException(status_code=404, detail="Not enough new questions.")
            chosen = random.sample(all_qs, limit)
            # consume one quiz count
            access["daily_limits_obj"].quiz_count += 1
            session.add(access["daily_limits_obj"]); session.commit()
        else:
            # preview: do NOT mutate DB; sample from all questions if possible
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < limit:
                raise HTTPException(status_code=404, detail="Not enough questions for preview.")
            chosen = random.sample(all_qs, limit)

    def _get_text(obj_field, q):
        try:
            data = json.loads(getattr(q, obj_field) or "{}")
            return data.get(effective_lang) or data.get("en") or ""
        except Exception:
            return ""

    result = []
    for q in chosen:
        question_text = _get_text("question_texts", q)
        options = _get_text("options_texts", q)
        if isinstance(options, str):
            try:
                options_parsed = json.loads(options)
            except Exception:
                options_parsed = [options]
        else:
            options_parsed = options or []
        result.append({
            "id": q.id,
            "question_text": question_text,
            "options": options_parsed,
            "correct_answer_index": q.correct_answer_index
        })

    # If we reached here and we chose from unanswered sample AND NOT preview, ensure we increment quiz_count
    # Note: we already incremented when resetting answered; handle normal branch too:
    if not preview and (len(unanswered) >= limit):
        access["daily_limits_obj"].quiz_count += 1
        session.add(access["daily_limits_obj"]); session.commit()

    return result

@app.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question: raise HTTPException(status_code=404, detail="Question not found.")
    user_score = session.exec(select(UserScore).where(UserScore.user_id==db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id==db_user.id)).first()
    if not user_score or not user_streak: raise HTTPException(status_code=500, detail="User data missing.")
    already_answered = session.exec(select(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id, UserAnsweredQuestion.quizquestion_id == payload.question_id)).first()
    is_correct = (question.correct_answer_index == payload.answer_index)
    score_awarded = 0
    if not already_answered:
        if is_correct:
            base_score = 10; streak_bonus = min(user_streak.streak_count, 5) * 2
            score_awarded = base_score + streak_bonus
            user_score.score += score_awarded
            user_streak.streak_count += 1
        else: user_streak.streak_count = 0
        session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
        session.commit()
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
def get_random_challenge(lang: Optional[str] = Query(None), preview: bool = Query(False), db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    access = _get_user_access_level(db_user, session)
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")

    if not preview:
        if access["challenge_count"] >= access["challenge_limit"] and access["level"] != "ultra":
             tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
             raise HTTPException(status_code=429, detail=tpl.format(limit=access["challenge_limit"]))

    completed_ids = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
    unanswered = session.exec(select(Challenge).where(Challenge.id.notin_(completed_ids))).all()

    if not unanswered:
        if not preview:
            session.exec(delete(UserCompletedChallenge).where(UserCompletedChallenge.user_id == db_user.id)); session.commit()
            unanswered = session.exec(select(Challenge)).all()
            if not unanswered: raise HTTPException(status_code=404, detail="No challenges available.")
        else:
            all_ch = session.exec(select(Challenge)).all()
            if not all_ch: raise HTTPException(status_code=404, detail="No challenges available.")
            chosen_challenge = random.choice(all_ch)
            texts = {}
            try:
                texts = json.loads(chosen_challenge.challenge_texts or "{}")
            except Exception:
                texts = {}
            challenge_text = texts.get(effective_lang) or texts.get("en") or ""
            return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

    chosen_challenge = random.choice(unanswered)

    if not preview:
        session.add(UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen_challenge.id))
        access["daily_limits_obj"].challenge_count += 1
        session.add(access["daily_limits_obj"]); session.commit()

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