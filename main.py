# main.py

import os
import json
import random
import asyncio
from typing import List, Optional, Dict

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Field, SQLModel, Session, create_engine, select, Relationship, delete
import google.generativeai as genai

import firebase_admin
from firebase_admin import credentials, auth

# --- 1. KONFİGÜRASYON ---
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
HUGGINGFACE_API_KEY = os.getenv("GEMINI_API_KEY")
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

engine = create_engine(DATABASE_URL, echo=False)

try:
    cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"KRİTİK HATA: Firebase Admin SDK başlatılamadı. Hata: {e}")

try:
    genai.configure(api_key=HUGGINGFACE_API_KEY)
    ai_model = genai.GenerativeModel('models/gemini-pro-latest')
except Exception as e:
    ai_model = None

LANGUAGES = ["en", "tr", "fr", "de", "it", "es", "ru", "zh", "ja", "hi", "ar"]
TOPICS = { "history": "History", "science": "Science", "art": "Art", "sports": "Sports", "technology": "Technology", "cinema_tv": "Cinema & TV", "music": "Music", "nature_animals": "Nature & Animals", "gastronomy": "Gastronomy & Cuisine", "geography_travel": "Geography & Travel", "mythology": "Mythology", "philosophy": "Philosophy", "literature": "Literature", "space_astronomy": "Space & Astronomy", "health_fitness": "Health & Fitness", "economics_finance": "Economics & Finance", "automotive": "Automotive", "architecture": "Architecture", "video_games": "Video Games", "general_culture": "General Culture", "fun_facts": "Fun Facts" }

# --- 2. VERİ MODELLERİ (ÇOK DİLLİ VE TUTARLI) ---
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
class UserProfile(SQLModel): firebase_uid: str; email: Optional[str]; score: int; topic_preferences: List[str]; language_code: str; notifications_enabled: bool
class LeaderboardEntry(SQLModel): rank: int; email: Optional[str]; score: int
class AnswerPayload(SQLModel): question_id: int; answer_index: int
class AnswerResponse(SQLModel): correct: bool; correct_index: int; new_score: Optional[int] = None

# --- 3. GÜVENLİK, OTURUMLAR VE KİMLİK DOĞRULAMA (TUTARLI) ---
token_auth_scheme = HTTPBearer()
def get_session():
    with Session(engine) as session:
        yield session

def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session: Session = Depends(get_session)) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
        if not db_user:
            db_user = User(firebase_uid=uid, email=decoded_token.get('email'))
            session.add(db_user)
            session.commit(); session.refresh(db_user)
            user_score = UserScore(user_id=db_user.id, score=0)
            session.add(user_score)

            print(f"Setting default topics for new user {uid}")
            for topic_key in TOPICS.keys():
                preference = UserTopicPreference(user_id=db_user.id, topic_key=topic_key)
                session.add(preference)

            session.commit()
        return db_user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication credentials: {e}")

# ... (Arka plan görevleri ve AI fonksiyonları buraya eklenebilir, şimdilik basit tutalım)

# --- 4. UYGULAMA BAŞLANGIÇ OLAYLARI ---
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
def on_startup():
    create_db_and_tables()

# --- 5. API ENDPOINT'LERİ (TÜMÜ OTURUM YÖNETİMİ İLE GÜNCELLENDİ) ---
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

@app.get("/user/topics/", response_model=List[str])
def get_user_topics(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    return session.exec(select(UserTopicPreference.topic_key).where(UserTopicPreference.user_id == db_user.id)).all()

@app.put("/user/topics/")
def set_user_topics(topics: List[str], db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    session.exec(delete(UserTopicPreference).where(UserTopicPreference.user_id == db_user.id));
    for topic_key in set(topics):
        if topic_key in TOPICS: session.add(UserTopicPreference(user_id=db_user.id, topic_key=topic_key))
    session.commit()
    return {"status": "success"}

@app.put("/user/notifications/")
def update_notification_settings(settings: NotificationSettings, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    db_user.notifications_enabled = settings.enabled
    session.add(db_user)
    session.commit()
    return {"status": "success", "message": f"Notification settings updated to {settings.enabled}."}

@app.get("/user/profile/", response_model=UserProfile)
def get_user_profile(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    user_score = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    user_topics = session.exec(select(UserTopicPreference.topic_key).where(UserTopicPreference.user_id == db_user.id)).all()
    return UserProfile(
        firebase_uid=db_user.firebase_uid, 
        email=db_user.email, 
        score=user_score.score if user_score else 0, 
        topic_preferences=user_topics, 
        language_code=db_user.language_code,
        notifications_enabled=db_user.notifications_enabled 
    )

@app.delete("/user/me/", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_account(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    user_uid_to_delete = db_user.firebase_uid
    session.delete(db_user); session.commit()
    try:
        auth.delete_user(user_uid_to_delete)
    except Exception as e:
        print(f"Firebase user deletion failed, but DB user was deleted. UID: {user_uid_to_delete}, Error: {e}")
    return

@app.get("/leaderboard/", response_model=List[LeaderboardEntry])
def get_leaderboard(session: Session = Depends(get_session)):
    top_scores = session.exec(select(User, UserScore).join(UserScore).order_by(UserScore.score.desc()).limit(10)).all()
    return [LeaderboardEntry(rank=i+1, email=user.email, score=score.score) for i, (user, score) in enumerate(top_scores)]

# İÇERİK İLE İLGİLİ
@app.get("/info/random/", response_model=DailyInfoResponse)
def get_random_info(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    user_topics = session.exec(select(UserTopicPreference.topic_key).where(UserTopicPreference.user_id == db_user.id)).all() or list(TOPICS.keys())
    seen_ids = session.exec(select(UserSeenInfo.dailyinfo_id).where(UserSeenInfo.user_id == db_user.id)).all()
    unseen_info = session.exec(select(DailyInfo).where(DailyInfo.category.in_(user_topics)).where(DailyInfo.id.notin_(seen_ids))).all()

    if len(unseen_info) <= 3: # Basit arka plan görevi mantığı
        print("INFO CONTENT LOW. TRIGGERING AI (simulation)...")

    if not unseen_info: raise HTTPException(status_code=404, detail="No new info available.")
    
    chosen = random.choice(unseen_info)
    session.add(UserSeenInfo(user_id=db_user.id, dailyinfo_id=chosen.id)); session.commit()
    
    texts = json.loads(chosen.info_texts)
    lang = db_user.language_code
    return DailyInfoResponse(id=chosen.id, info_text=texts.get(lang, texts.get("en")), category=chosen.category, source=chosen.source)

@app.get("/quiz/", response_model=List[QuizQuestionResponse])
def get_quiz_questions(limit: int = 3, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    user_topics = session.exec(select(UserTopicPreference.topic_key).where(UserTopicPreference.user_id == db_user.id)).all() or list(TOPICS.keys())
    answered_ids = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
    unanswered = session.exec(select(QuizQuestion).where(QuizQuestion.category.in_(user_topics)).where(QuizQuestion.id.notin_(answered_ids))).all()

    if len(unanswered) <= limit + 3:
        print("QUIZ CONTENT LOW. TRIGGERING AI (simulation)...")

    if len(unanswered) < limit: raise HTTPException(status_code=404, detail="Not enough new questions available.")
    
    chosen = random.sample(unanswered, limit)
    
    response_list = []
    lang = db_user.language_code
    for q in chosen:
        q_texts = json.loads(q.question_texts); o_texts = json.loads(q.options_texts)
        response_list.append(QuizQuestionResponse(id=q.id, question_text=q_texts.get(lang, q_texts.get("en")), options=o_texts.get(lang, o_texts.get("en")), category=q.category, correct_answer_index=q.correct_answer_index))
    return response_list

@app.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question: raise HTTPException(status_code=404, detail="Question not found.")

    is_correct = question.correct_answer_index == payload.answer_index
    new_score = None
    if is_correct:
        already_answered = session.exec(select(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id, UserAnsweredQuestion.quizquestion_id == payload.question_id)).first()
        if not already_answered:
            session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
            user_score = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
            user_score.score += 10
            session.add(user_score); session.commit(); session.refresh(user_score)
            new_score = user_score.score
            
    return AnswerResponse(correct=is_correct, correct_index=question.correct_answer_index, new_score=new_score)

@app.get("/challenges/random/", response_model=ChallengeResponse)
def get_random_challenge(db_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    completed_ids = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
    uncompleted = session.exec(select(Challenge).where(Challenge.id.notin_(completed_ids))).all()
    
    if len(uncompleted) <= 3:
        print("CHALLENGE CONTENT LOW. TRIGGERING AI (simulation)...")

    if not uncompleted: raise HTTPException(status_code=404, detail="No new challenges available.")
        
    chosen = random.choice(uncompleted)
    session.add(UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen.id)); session.commit()
    
    texts = json.loads(chosen.challenge_texts)
    lang = db_user.language_code
    return ChallengeResponse(id=chosen.id, challenge_text=texts.get(lang, texts.get("en")), category=chosen.category)