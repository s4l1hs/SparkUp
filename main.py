import os
import json
import random
from typing import List, Optional

# Gerekli kütüphaneleri import ediyoruz
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Field, SQLModel, Session, create_engine, select
import google.generativeai as genai

# Firebase Admin SDK'sını import ediyoruz
import firebase_admin
from firebase_admin import credentials, auth

# --- 1. KONFİGÜRASYON ---
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

engine = create_engine(DATABASE_URL, echo=False)

# Firebase ve Gemini servislerini başlatma...
# (Bu kısımlar önceki kodla aynı)
try:
    cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK başarıyla başlatıldı.")
except Exception as e:
    print(f"KRİTİK HATA: Firebase Admin SDK başlatılamadı. Hata: {e}")

try:
    genai.configure(api_key=GEMINI_API_KEY)
    ai_model = genai.GenerativeModel('gemini-pro')
except Exception as e:
    print(f"KRİTİK HATA: Gemini API anahtarı yapılandırılamadı. Hata: {e}")
    ai_model = None

# --- 2. VERİ MODELLERİ (TAKİP TABLOLARI EKLENDİ) ---

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None

# ... DailyInfo, QuizQuestion, Challenge modelleri aynı kalacak ...
class DailyInfo(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    info_text: str = Field(unique=True)
    category: str = Field(default="general", index=True)
    source: Optional[str] = None

class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    question_text: str = Field(unique=True)
    options: str
    correct_answer_index: int
    category: Optional[str] = Field(default="general", index=True)

class Challenge(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    challenge_text: str = Field(unique=True)
    category: str = Field(default="fun", index=True)

# YENİ EKLENDİ: Hangi kullanıcının hangi bilgiyi gördüğünü takip eden tablo
class UserSeenInfo(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    dailyinfo_id: int = Field(foreign_key="dailyinfo.id", primary_key=True)

# YENİ EKLENDİ: Hangi kullanıcının hangi soruyu gördüğünü/cevapladığını takip eden tablo
class UserAnsweredQuestion(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)

# --- 3. YAPAY ZEKA FONKSİYONLARI ---
# ... (Bu fonksiyonlar önceki kodla aynı, değişiklik yok) ...
def generate_new_info(topic: str) -> Optional[DailyInfo]: pass
def generate_new_quiz_questions(topic: str, count: int = 10) -> List[QuizQuestion]: pass
def generate_new_challenge(category: str = "eğlence") -> Optional[Challenge]: pass

# --- 4. GÜVENLİK VE KİMLİK DOĞRULAMA ---
token_auth_scheme = HTTPBearer()
def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme)):
    # ... (Bu fonksiyon önceki kodla aynı, değişiklik yok) ...
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid auth credentials: {e}")

# --- 5. UYGULAMA BAŞLANGIÇ OLAYLARI ---
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()

# --- 6. API ENDPOINT'LERİ (KULLANICI TAKİP MANTIĞI EKLENDİ) ---

@app.get("/")
def read_root():
    return {"message": "SparkUp Backend'e Hoş Geldiniz!"}

@app.get("/info/random/", response_model=DailyInfo)
def get_random_info(category: Optional[str] = "genel kültür", user: dict = Depends(get_current_user)):
    with Session(engine) as session:
        # 1. İstek yapan kullanıcının kimliğini al
        firebase_uid = user['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == firebase_uid)).first()
        if not db_user:
            # Normalde get_current_user fonksiyonu kullanıcıyı oluşturur, bu bir güvenlik kontrolü
            raise HTTPException(status_code=404, detail="User not found in DB.")

        # 2. Bu kullanıcının daha önce gördüğü tüm bilgilerin ID'lerini al
        seen_info_ids = session.exec(select(UserSeenInfo.dailyinfo_id).where(UserSeenInfo.user_id == db_user.id)).all()

        # 3. Veritabanından, kullanıcının GÖRMEDİĞİ bilgileri sorgula
        statement = select(DailyInfo).where(DailyInfo.category == category).where(DailyInfo.id.notin_(seen_info_ids))
        unseen_info = session.exec(statement).all()
        
        # 4. Eğer kullanıcıya gösterecek yeni bilgi kalmadıysa, AI ile yenisini üret
        if not unseen_info:
            new_info = generate_new_info(topic=category)
            if new_info:
                session.add(new_info)
                session.commit()
                session.refresh(new_info)
                unseen_info = [new_info] # Listeye yeni bilgiyi ekle
            else:
                raise HTTPException(status_code=503, detail="AI service unavailable.")

        # 5. Kullanıcının görmediği bilgiler arasından rastgele birini seç
        chosen_info = random.choice(unseen_info)

        # 6. Bu bilgiyi kullanıcıya göndermeden önce, "görüldü" olarak işaretle
        seen_record = UserSeenInfo(user_id=db_user.id, dailyinfo_id=chosen_info.id)
        session.add(seen_record)
        session.commit()
        
        return chosen_info

@app.get("/quiz/", response_model=List[QuizQuestion])
def get_quiz_questions(category: str, limit: int = 3, user: dict = Depends(get_current_user)):
    with Session(engine) as session:
        # 1. Kullanıcıyı bul
        firebase_uid = user['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == firebase_uid)).first()
        if not db_user:
            raise HTTPException(status_code=404, detail="User not found.")

        # 2. Kullanıcının daha önce cevapladığı soruların ID'lerini al
        answered_question_ids = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()

        # 3. Kullanıcının CEVAPLAMADIĞI soruları sorgula
        statement = select(QuizQuestion).where(QuizQuestion.category == category).where(QuizQuestion.id.notin_(answered_question_ids))
        unanswered_questions = session.exec(statement).all()
        
        # 4. Eğer yeterli sayıda cevaplanmamış soru yoksa, AI ile yenilerini üret
        if len(unanswered_questions) < limit:
            new_questions = generate_new_quiz_questions(topic=category)
            if not new_questions:
                raise HTTPException(status_code=503, detail="AI service unavailable.")
            
            for q in new_questions:
                existing = session.exec(select(QuizQuestion).where(QuizQuestion.question_text == q.question_text)).first()
                if not existing:
                    session.add(q)
            session.commit()
            
            unanswered_questions = session.exec(statement).all()

        if len(unanswered_questions) < limit:
            raise HTTPException(status_code=404, detail="Not enough questions.")
        
        # 5. Cevaplanmamış sorulardan rastgele bir örnek seç
        chosen_questions = random.sample(unanswered_questions, limit)
        
        # 6. Bu soruları "görüldü/cevaplandı" olarak işaretle
        for q in chosen_questions:
            answered_record = UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=q.id)
            session.add(answered_record)
        session.commit()

        return chosen_questions

# (Challenge endpoint'i de benzer bir mantıkla güncellenebilir)