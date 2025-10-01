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

# Firebase Admin SDK'sını başlatıyoruz
try:
    cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK başarıyla başlatıldı.")
except Exception as e:
    print(f"KRİTİK HATA: Firebase Admin SDK başlatılamadı. 'firebase-credentials.json' dosyanızı kontrol edin. Hata: {e}")

# Google Gemini AI modelini yapılandırıyoruz
try:
    genai.configure(api_key=GEMINI_API_KEY)
    ai_model = genai.GenerativeModel('gemini-pro')
except Exception as e:
    print(f"KRİTİK HATA: Gemini API anahtarı yapılandırılamadı. .env dosyanızı kontrol edin. Hata: {e}")
    ai_model = None

# --- 2. VERİ MODELLERİ (KULLANICI MODELİ EKLENDİ) ---

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None
    # Diğer kullanıcı bilgilerini buraya ekleyebilirsiniz

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

# ... (Yapay Zeka Fonksiyonları - Değişiklik yok) ...
# --- 3. YAPAY ZEKA İLE İÇERİK ÜRETME FONKSİYONLARI ---
def generate_new_info(topic: str): pass
def generate_new_quiz_questions(topic: str, count: int = 10): pass
# (Bu fonksiyonlar önceki mesajdaki gibi aynı kalacak, yer kaplamaması için kısalttım)


# --- 4. GÜVENLİK VE KİMLİK DOĞRULAMA ---

# Gelen isteklerdeki "Bearer Token"ı okumak için bir şema
token_auth_scheme = HTTPBearer()

def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme)):
    """
    Flutter'dan gelen Firebase ID Token'ını doğrular ve kullanıcı bilgilerini döndürür.
    Bu fonksiyonu endpoint'lere 'Depends' ile ekleyerek o endpoint'i korumalı hale getiririz.
    """
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
        # İsteğe bağlı: Kullanıcıyı kendi veritabanımızda da oluşturabiliriz.
        # Bu, kullanıcıya özel verileri (skor gibi) PostgreSQL'de saklamamızı sağlar.
        with Session(engine) as session:
            user = session.exec(select(User).where(User.firebase_uid == uid)).first()
            if not user:
                user = User(firebase_uid=uid, email=decoded_token.get('email'))
                session.add(user)
                session.commit()
                session.refresh(user)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication credentials: {e}")


# --- 5. UYGULAMA BAŞLANGIÇ OLAYLARI ---
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()

# --- 6. API ENDPOINT'LERİ (ARTIK GÜVENLİ) ---

@app.get("/")
def read_root():
    return {"message": "SparkUp Backend'e Hoş Geldiniz!"}

# Örnek: Bu endpoint artık geçerli bir kullanıcı girişi gerektirir.
@app.get("/info/random/", response_model=DailyInfo)
def get_random_info(category: Optional[str] = "genel kültür", user: dict = Depends(get_current_user)):
    print(f"Authenticated user UID: {user['uid']}") # Hangi kullanıcının istek yaptığını görebiliriz
    # ... (geri kalan mantık aynı) ...
    with Session(engine) as session:
        statement = select(DailyInfo).where(DailyInfo.category == category)
        all_info = session.exec(statement).all()
        if not all_info:
            raise HTTPException(status_code=404, detail="No info found.")
        return random.choice(all_info)

# (Quiz endpoint'ini de benzer şekilde `user: dict = Depends(get_current_user)` ekleyerek güvenli hale getirebiliriz)
@app.get("/quiz/", response_model=List[QuizQuestion])
def get_quiz_questions(category: str, limit: int = 3): # Şimdilik bunu korumasız bırakalım
    # ... (geri kalan mantık aynı) ...
    with Session(engine) as session:
        statement = select(QuizQuestion).where(QuizQuestion.category == category)
        questions = session.exec(statement).all()
        if len(questions) < limit:
            raise HTTPException(status_code=404, detail="Not enough questions.")
        return random.sample(questions, limit)