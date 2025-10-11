import os
import json
import random
from typing import List, Optional, Dict
from datetime import datetime, date, timedelta # datetime ve date eklendi

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Field, SQLModel, Session, create_engine, select, Relationship, delete

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

LANGUAGES = ["en", "tr", "fr", "de", "it", "es", "ru", "zh", "ja", "hi", "ar"]
TOPICS = { "history": "History", "science": "Science", "art": "Art", "sports": "Sports", "technology": "Technology", "cinema_tv": "Cinema & TV", "music": "Music", "nature_animals": "Nature & Animals", "geography_travel": "Geography & Travel", "mythology": "Mythology", "philosophy": "Philosophy", "literature": "Literature", "space_astronomy": "Space & Astronomy", "health_fitness": "Health & Fitness", "economics_finance": "Economics & Finance", "architecture": "Architecture", "video_games": "Video Games", "general_culture": "General Culture", "fun_facts": "Fun Facts" }

# --- IAP ABONELİK LİMİTLERİ ---
SUBSCRIPTION_LIMITS = {
    "free": {"quiz_limit": 3, "challenge_limit": 3, "info_notifications": 1},
    "pro": {"quiz_limit": 5, "challenge_limit": 5, "info_notifications": 2}, # Pro limiti 5 olarak belirlendi
    "ultra": {"quiz_limit": float('inf'), "challenge_limit": float('inf'), "info_notifications": 3},
}

# --- 2. VERİ MODELLERİ (YENİ MODELLER EKLENDİ) ---

class UserSubscription(SQLModel, table=True): # YENİ ABONELİK MODELİ
    id: Optional[int] = Field(default=None, primary_key=True)
    level: str = Field(default="free") # free, pro, ultra
    expires_at: Optional[date] = Field(default=None) # Aboneliğin sona erme tarihi
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="subscription")

class DailyLimits(SQLModel, table=True): # YENİ GÜNLÜK LİMİT MODELİ
    id: Optional[int] = Field(default=None, primary_key=True)
    quiz_count: int = Field(default=0)
    challenge_count: int = Field(default=0)
    last_reset: date = Field(default_factory=date.today)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="daily_limits")


class UserStreak(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    streak_count: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="streak")

class UserScore(SQLModel, table=True): 
    id: Optional[int] = Field(default=None, primary_key=True)
    score: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="score")

class User(SQLModel, table=True): 
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None
    language_code: str = Field(default="en")
    notifications_enabled: bool = Field(default=True)
    score: Optional[UserScore] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    streak: Optional[UserStreak] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    subscription: Optional[UserSubscription] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}) # YENİ ABONELİK İLİŞKİSİ
    daily_limits: Optional[DailyLimits] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"}) # YENİ GÜNLÜK LİMİT İLİŞKİSİ

# ... diğer modeller (DailyInfo, QuizQuestion, Challenge vb.) aynı kalır.

class DailyInfo(SQLModel, table=True): 
    id: Optional[int] = Field(default=None, primary_key=True)
    info_texts: str
    category: str = Field(index=True)
    source: Optional[str] = None

class QuizQuestion(SQLModel, table=True): 
    id: Optional[int] = Field(default=None, primary_key=True)
    question_texts: str
    options_texts: str
    correct_answer_index: int
    category: str = Field(index=True)

class Challenge(SQLModel, table=True): 
    id: Optional[int] = Field(default=None, primary_key=True)
    challenge_texts: str
    category: str = Field(default="fun", index=True)

class UserTopicPreference(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); topic_key: str = Field(primary_key=True)
class UserSeenInfo(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); dailyinfo_id: int = Field(foreign_key="dailyinfo.id", primary_key=True)
class UserAnsweredQuestion(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)
class UserCompletedChallenge(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); challenge_id: int = Field(foreign_key="challenge.id", primary_key=True)
class NotificationSettings(SQLModel): enabled: bool
class DailyInfoResponse(SQLModel): id: int; info_text: str; category: str; source: Optional[str] = None
class QuizQuestionResponse(SQLModel): id: int; question_text: str; options: List[str]; category: str
class ChallengeResponse(SQLModel): id: int; challenge_text: str; category: str
class LeaderboardEntry(SQLModel): rank: int; email: Optional[str]; score: int; rank_name: str
class AnswerPayload(SQLModel): question_id: int; answer_index: int
class AnswerResponse(SQLModel): correct: bool; correct_index: int; score_awarded: int; new_score: Optional[int] = None
class SubscriptionUpdate(SQLModel): level: str; duration_days: int # IAP'tan sonra frontend'den gelecek veri


# --- 3. GÜVENLİK, OTURUMLAR VE KİMLİK DOĞRULAMA ---
token_auth_scheme = HTTPBearer()
def get_session():
    with Session(engine) as session:
        yield session

# --- RÜTBE HESAPLAMA YARDIMCI METODU ---
def _get_rank_name(score: int) -> str:
    if score >= 10000: return 'Üstad'
    elif score >= 5000: return 'Elmas'
    elif score >= 2000: return 'Altın'
    elif score >= 1000: return 'Gümüş'
    elif score >= 500: return 'Bronz'
    else: return 'Demir'

# --- YENİ: KULLANICI ERİŞİM SEVİYESİNİ VE LİMİTLERİNİ KONTROL EDEN METOT ---
def _get_user_access_level(db_user: User, session: Session) -> Dict:
    today = date.today()
    
    # 1. Abonelik seviyesini çek/oluştur
    sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    if not sub:
        sub = UserSubscription(user_id=db_user.id, level="free", expires_at=None)
        session.add(sub); session.commit(); session.refresh(sub)

    # Abonelik süresi dolmuşsa Free'ye düşür
    if sub.expires_at and sub.expires_at < today:
        sub.level = "free"
        sub.expires_at = None
        session.add(sub); session.commit()
    
    # 2. Günlük limitleri çek/sıfırla
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not limits:
        limits = DailyLimits(user_id=db_user.id, quiz_count=0, challenge_count=0, last_reset=today)
        session.add(limits); session.commit(); session.refresh(limits)
    
    # Gün sonunda limitleri sıfırla
    if limits.last_reset < today:
        limits.quiz_count = 0
        limits.challenge_count = 0
        limits.last_reset = today
        session.add(limits); session.commit()

    # 3. Limitleri uygula
    level = sub.level
    max_quiz = SUBSCRIPTION_LIMITS[level]["quiz_limit"]
    max_challenge = SUBSCRIPTION_LIMITS[level]["challenge_limit"]
    
    return {
        "level": level,
        "quiz_count": limits.quiz_count,
        "challenge_count": limits.challenge_count,
        "quiz_limit": max_quiz,
        "challenge_limit": max_challenge,
        "daily_limits_obj": limits # Güncelleme için obje döndürülüyor
    }


def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session: Session = Depends(get_session)) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
        
        if not db_user:
            # Yeni kullanıcı oluştur
            db_user = User(firebase_uid=uid, email=decoded_token.get('email'))
            session.add(db_user)
            session.commit(); session.refresh(db_user)
            
            # Puan, Streak, Abonelik ve Günlük Limit kayıtlarını oluştur
            session.add(UserScore(user_id=db_user.id, score=0))
            session.add(UserStreak(user_id=db_user.id, streak_count=0))
            session.add(UserSubscription(user_id=db_user.id, level="free", expires_at=None)) # YENİ
            session.add(DailyLimits(user_id=db_user.id)) # YENİ
            
            # Varsayılan konu tercihlerini ekle
            for topic_key in TOPICS.keys():
                preference = UserTopicPreference(user_id=db_user.id, topic_key=topic_key)
                session.add(preference)
            session.commit()
            
        return db_user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication credentials: {e}")

# --- 4. UYGULAMA BAŞLANGIÇ OLAYLARI (Değişiklik yok) ---
def create_db_and_tables(): SQLModel.metadata.create_all(engine)
app = FastAPI(title="SparkUp Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
@app.on_event("startup")
def on_startup(): create_db_and_tables()

# --- 5. API ENDPOINT'LERİ (LİMİT KONTROLÜ EKLENDİ) ---
@app.get("/")
def read_root(): return {"message": "Welcome to the SparkUp Backend!"}

@app.get("/topics/", response_model=Dict[str, str])
def get_topics(): return TOPICS

# KULLANICI İLE İLGİLİ
@app.put("/user/language/")
def set_user_language(language_code: str, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    if language_code not in LANGUAGES: raise HTTPException(status_code=400, detail="Unsupported language code.")
    db_user.language_code = language_code
    session.add(db_user); session.commit()
    return {"status": "success"}

@app.get("/user/profile/")
def get_user_profile(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    user_score = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id == db_user.id)).first()
    user_topics = session.exec(select(UserTopicPreference.topic_key).where(UserTopicPreference.user_id == db_user.id)).all()
    user_sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first() # YENİ ABONELİK

    score = user_score.score if user_score else 0
    rank_name = _get_rank_name(score)
    
    return {
        "firebase_uid": db_user.firebase_uid,
        "email": db_user.email,
        "score": score,
        "rank_name": rank_name,
        "topic_preferences": user_topics,
        "language_code": db_user.language_code,
        "notifications_enabled": db_user.notifications_enabled,
        "current_streak": user_streak.streak_count if user_streak else 0,
        "subscription_level": user_sub.level if user_sub else "free", # YENİ
        "subscription_expires": user_sub.expires_at.isoformat() if user_sub and user_sub.expires_at else None # YENİ
    }

@app.post("/subscription/update/") # YENİ ENDPOINT: Abonelik güncellemesi (IAP'tan sonra)
def update_subscription(sub_update: SubscriptionUpdate, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    if sub_update.level not in SUBSCRIPTION_LIMITS or sub_update.level == "free":
        raise HTTPException(status_code=400, detail="Invalid subscription level for purchase.")
    
    sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    
    # Süre hesaplaması: Mevcut abonelik süresi varsa üzerine ekle, yoksa bugünden başlat
    today = date.today()
    start_date = sub.expires_at if sub and sub.expires_at and sub.expires_at > today else today
    new_expiry_date = start_date + timedelta(days=sub_update.duration_days)
    
    sub.level = sub_update.level
    sub.expires_at = new_expiry_date
    
    session.add(sub)
    session.commit()
    return {"status": "success", "level": sub.level, "expires_at": sub.expires_at.isoformat()}


# ... (Diğer kullanıcı endpoint'leri aynı kalır)


# İÇERİK İLE İLGİLİ (LİMİT KONTROLÜ EKLENDİ)
@app.get("/info/random/")
def get_random_info(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    # YENİ: Günlük Limit Kontrolü
    access = _get_user_access_level(db_user, session)
    if access["level"] != "ultra":
        # Bilgi kartı için ayrı bir sayaç tutmadığımız için, bu kontrolü şimdilik atlıyoruz.
        # Bu, bildirimler (notifications) için geçerli bir limit. API çağrısı için değil.
        pass

    seen_ids = session.exec(select(UserSeenInfo.dailyinfo_id).where(UserSeenInfo.user_id == db_user.id)).all()
    unseen_info = session.exec(select(DailyInfo).where(DailyInfo.id.notin_(seen_ids))).all()

    if not unseen_info:
        # ... (Mantık aynı kalır)
        session.exec(delete(UserSeenInfo).where(UserSeenInfo.user_id == db_user.id))
        session.commit()
        unseen_info = session.exec(select(DailyInfo)).all()
        if not unseen_info: raise HTTPException(status_code=404, detail="No info available in the database.")

    chosen = random.choice(unseen_info)
    session.add(UserSeenInfo(user_id=db_user.id, dailyinfo_id=chosen.id)); session.commit()
    
    texts = json.loads(chosen.info_texts)
    lang = db_user.language_code
    return DailyInfoResponse(id=chosen.id, info_text=texts.get(lang, texts.get("en")), category=chosen.category, source=chosen.source)

@app.get("/quiz/", response_model=List[QuizQuestionResponse])
def get_quiz_questions(limit: int = 3, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    # YENİ: Günlük Limit Kontrolü
    access = _get_user_access_level(db_user, session)
    if access["quiz_count"] >= access["quiz_limit"]:
        if access["level"] != "ultra":
             raise HTTPException(status_code=429, detail=f"Daily quiz limit reached ({access['quiz_limit']} per day). Upgrade to Pro or Ultra.")
    
    # ... (Geri kalan mantık aynı kalır)
    answered_ids = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
    unanswered = session.exec(select(QuizQuestion).where(QuizQuestion.id.notin_(answered_ids))).all()

    if len(unanswered) < limit:
        # ... (Sıfırlama mantığı aynı kalır)
        session.exec(delete(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id))
        session.commit()
        unanswered = session.exec(select(QuizQuestion)).all()
        if len(unanswered) < limit:
             raise HTTPException(status_code=404, detail="Not enough questions in the database to meet the limit, even after reset.")

    chosen = random.sample(unanswered, limit)
    
    # YENİ: Limit sayacını artır
    access["daily_limits_obj"].quiz_count += 1
    session.add(access["daily_limits_obj"])
    session.commit()
    
    response_list = []
    lang = db_user.language_code
    for q in chosen:
        q_texts = json.loads(q.question_texts); o_texts = json.loads(q.options_texts)
        response_list.append(QuizQuestionResponse(id=q.id, question_text=q_texts.get(lang, q_texts.get("en")), options=o_texts.get(lang, o_texts.get("en")), category=q.category))
    return response_list


@app.get("/challenges/random/", response_model=ChallengeResponse)
def get_random_challenge(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    # YENİ: Günlük Limit Kontrolü
    access = _get_user_access_level(db_user, session)
    if access["challenge_count"] >= access["challenge_limit"]:
        if access["level"] != "ultra":
             raise HTTPException(status_code=429, detail=f"Daily challenge limit reached ({access['challenge_limit']} per day). Upgrade to Pro or Ultra.")
             
    # ... (Geri kalan mantık aynı kalır)
    completed_ids = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
    uncompleted = session.exec(select(Challenge).where(Challenge.id.notin_(completed_ids))).all()
    
    if not uncompleted:
        # ... (Sıfırlama mantığı aynı kalır)
        session.exec(delete(UserCompletedChallenge).where(UserCompletedChallenge.user_id == db_user.id))
        session.commit()
        uncompleted = session.exec(select(Challenge)).all()
        if not uncompleted: raise HTTPException(status_code=404, detail="No challenges available in the database.")
        
    chosen = random.choice(uncompleted)
    session.add(UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen.id)); session.commit()
    
    # YENİ: Limit sayacını artır
    access["daily_limits_obj"].challenge_count += 1
    session.add(access["daily_limits_obj"])
    session.commit()
    
    texts = json.loads(chosen.challenge_texts)
    lang = db_user.language_code
    return ChallengeResponse(id=chosen.id, challenge_text=texts.get(lang, texts.get("en")), category=chosen.category)


@app.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question: raise HTTPException(status_code=404, detail="Question not found.")

    user_score = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id == db_user.id)).first()

    if not user_score or not user_streak:
        raise HTTPException(status_code=500, detail="User score or streak data missing.")

    is_correct = question.correct_answer_index == payload.answer_index
    score_awarded = 0
    new_score = None
    
    # 1. CEVAP KAYIT KONTROLÜ
    already_answered = session.exec(select(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id, UserAnsweredQuestion.quizquestion_id == payload.question_id)).first()

    # Eğer daha önce cevaplanmamış bir soruysa (Limit tüketimi burada yapılır):
    if not already_answered:
        
        # --- Günlük Limit Kontrolü ve Tüketimi (CRITICAL) ---
        access = _get_user_access_level(db_user, session)
        max_questions = access["quiz_limit"]
        
        if access["quiz_count"] >= max_questions and access["level"] != "ultra":
             raise HTTPException(status_code=429, detail=f"Daily quiz question limit reached ({max_questions} questions answered). Cannot process answer.")

        # Limit tüketimi burada yapılır (SORU CEVAPLANDIĞI AN)
        access["daily_limits_obj"].quiz_count += 1
        session.add(access["daily_limits_obj"])
        # ------------------------------------------------------
        
        # Puan hesaplaması ve Streak Mantığı
        if is_correct:
            # SADECE DOĞRU BİLİNİRSE KAYDEDİLİR VE TEKRAR GÖSTERİLMEZ
            base_score = 10
            streak_bonus = min(user_streak.streak_count, 5) * 2
            score_awarded = base_score + streak_bonus
            
            user_score.score += score_awarded
            user_streak.streak_count += 1
            
            # Doğru bilindiği için UserAnsweredQuestion tablosuna eklenir
            session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
            session.add(user_score)
            session.add(user_streak)
            session.commit(); session.refresh(user_score)
            new_score = user_score.score
        
        else: 
            user_streak.streak_count = 0
            session.add(user_streak)
            
            session.commit() 
    
    return AnswerResponse(correct=is_correct, correct_index=question.correct_answer_index, score_awarded=score_awarded, new_score=new_score)