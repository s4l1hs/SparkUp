import os
import json
import random
from typing import List, Optional, Dict

# Gerekli kütüphaneleri import ediyoruz
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
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

# Firebase ve Gemini servislerini başlatma
try:
    cred = credentials.Certificate(GOOGLE_APPLICATION_CREDENTIALS)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK başarıyla başlatıldı.")
except Exception as e:
    print(f"KRİTİK HATA: Firebase Admin SDK başlatılamadı. Hata: {e}")

try:
    genai.configure(api_key=GEMINI_API_KEY)
    ai_model = genai.GenerativeModel('gemini-pro')
    print("✅ Google Gemini AI modeli başarıyla yapılandırıldı.")
except Exception as e:
    print(f"KRİTİK HATA: Gemini API anahtarı yapılandırılamadı. Hata: {e}")
    ai_model = None

# Konu başlıkları
TOPICS = { "history": "History", "science": "Science", "art": "Art", "sports": "Sports", "technology": "Technology", "cinema_tv": "Cinema & TV", "music": "Music", "nature_animals": "Nature & Animals", "gastronomy": "Gastronomy & Cuisine", "geography_travel": "Geography & Travel", "mythology": "Mythology", "philosophy": "Philosophy", "literature": "Literature", "space_astronomy": "Space & Astronomy", "health_fitness": "Health & Fitness", "economics_finance": "Economics & Finance", "automotive": "Automotive", "architecture": "Architecture", "video_games": "Video Games", "general_culture": "General Knowledge", "fun_facts": "Fun Facts" }

# --- 2. VERİ MODELLERİ ---
# (Modellerde değişiklik yok, aynı kalıyor)
class User(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); firebase_uid: str = Field(unique=True, index=True); email: Optional[str] = None
class DailyInfo(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); info_text: str = Field(unique=True); category: str = Field(index=True); source: Optional[str] = None
class QuizQuestion(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); question_text: str = Field(unique=True); options: str; correct_answer_index: int; category: str = Field(index=True)
class Challenge(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); challenge_text: str = Field(unique=True); category: str = Field(default="fun", index=True)
class UserTopicPreference(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); topic_key: str = Field(primary_key=True)
class UserSeenInfo(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); dailyinfo_id: int = Field(foreign_key="dailyinfo.id", primary_key=True)
class UserAnsweredQuestion(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)
class UserCompletedChallenge(SQLModel, table=True): user_id: int = Field(foreign_key="user.id", primary_key=True); challenge_id: int = Field(foreign_key="challenge.id", primary_key=True)


# --- 3. YAPAY ZEKA FONKSİYONLARI ---
# (Bu fonksiyonlarda değişiklik yok, aynı kalıyor)
def generate_new_info(topic_key: str) -> Optional[DailyInfo]:
    if not ai_model or topic_key not in TOPICS: return None
    topic_name = TOPICS[topic_key]
    print(f"API CALL: Generating NEW INFO for topic '{topic_name}'...")
    prompt = f"Briefly write a surprising and interesting fact about '{topic_name}' that is not widely known. Also, state the source of the fact. Only provide the fact and the source, no other explanation. Example:\nFact: An octopus has three hearts.\nSource: National Geographic"
    try:
        response = ai_model.generate_content(prompt)
        lines = response.text.strip().split('\n')
        info_text = lines[0].replace('Fact:', '').strip()
        source = lines[1].replace('Source:', '').strip()
        return DailyInfo(info_text=info_text, category=topic_key, source=source)
    except Exception as e:
        print(f"Error: AI failed to generate info: {e}")
        return None

def generate_new_quiz_questions(topic_key: str, count: int = 10) -> List[QuizQuestion]:
    if not ai_model or topic_key not in TOPICS: return []
    topic_name = TOPICS[topic_key]
    print(f"API CALL: Generating {count} NEW QUIZ QUESTIONS for topic '{topic_name}'...")
    prompt = f'Create {count} different multiple-choice questions at a general knowledge level about \'{topic_name}\'. Provide 4 options for each question. Only one option should be correct. Indicate the index of the correct answer (starting from 0). Provide your response in a single JSON format with a "questions" key containing a list. Each element in the list must contain these keys: "question_text", "options", "correct_answer_index"'
    try:
        response = ai_model.generate_content(prompt)
        cleaned_response = response.text.strip().replace("```json", "").replace("```", "")
        data = json.loads(cleaned_response)
        new_questions = [QuizQuestion(question_text=q["question_text"], options=json.dumps(q["options"], ensure_ascii=False), correct_answer_index=q["correct_answer_index"], category=topic_key) for q in data.get("questions", [])]
        return new_questions
    except Exception as e:
        print(f"Error: AI failed to generate quiz: {e}")
        return []

def generate_new_challenges(category: str = "fun", count: int = 5) -> List[Challenge]:
    if not ai_model: return []
    print(f"API CALL: Generating {count} NEW CHALLENGES for category '{category}'...")
    prompt = f"Create a list of {count} short, simple, and fun challenges that a user can do instantly. Examples: 'Do a plank for 30 seconds', 'Stare at the camera for 1 minute without blinking', 'Hum your favorite song'. Provide your response as a JSON list of strings."
    try:
        response = ai_model.generate_content(prompt)
        cleaned_response = response.text.strip().replace("```json", "").replace("```", "")
        challenge_texts = json.loads(cleaned_response)
        return [Challenge(challenge_text=text, category=category) for text in challenge_texts]
    except Exception as e:
        print(f"Error: AI failed to generate challenge: {e}")
        return []

# --- 4. GÜVENLİK ---
# (Bu fonksiyon test sonrası tekrar aktif edilecek)
token_auth_scheme = HTTPBearer()
def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session: Session = Depends(lambda: Session(engine))) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
        if not db_user:
            db_user = User(firebase_uid=uid, email=decoded_token.get('email'))
            session.add(db_user)
            session.commit()
            session.refresh(db_user)
        return db_user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication credentials: {e}")


# --- 5. UYGULAMA BAŞLANGIÇ ---
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")

# CORS AYARLARI EKLENDİ
origins = ["*"] # Test için her şeye izin ver
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    create_db_and_tables()


# --- 6. API ENDPOINT'LERİ (TEST MODU) ---

@app.get("/")
def read_root():
    return {"message": "Welcome to the SparkUp Backend!"}

@app.get("/topics/", response_model=Dict[str, str])
def get_topics():
    return TOPICS

# KULLANICI GEREKTİRMEYEN VERSİYON
@app.get("/info/random/", response_model=DailyInfo)
def get_random_info(category: str = "general_culture"):
    print("⚠️ UYARI: /info/random/ test modunda çalışıyor.")
    with Session(engine) as session:
        # Kullanıcıya özel filtreleme geçici olarak devre dışı
        statement = select(DailyInfo).where(DailyInfo.category == category)
        all_info = session.exec(statement).all()
        
        if not all_info:
            new_info = generate_new_info(topic_key=category)
            if new_info:
                session.add(new_info)
                session.commit()
                session.refresh(new_info)
                return new_info
            else:
                raise HTTPException(status_code=503, detail="AI service unavailable.")
        
        # Görüldü takibi yapmadan rastgele birini döndür
        return random.choice(all_info)

# KULLANICI GEREKTİRMEYEN VERSİYON
@app.get("/quiz/", response_model=List[QuizQuestion])
def get_quiz_questions(limit: int = 3, category: Optional[str] = None):
    print("⚠️ UYARI: /quiz/ test modunda çalışıyor.")
    with Session(engine) as session:
        # Test için, kategori belirtilmemişse rastgele bir konu seç
        if not category:
            category = random.choice(list(TOPICS.keys()))
        
        statement = select(QuizQuestion).where(QuizQuestion.category == category)
        questions = session.exec(statement).all()
        
        if len(questions) < limit:
            new_questions = generate_new_quiz_questions(topic_key=category)
            if new_questions:
                for q in new_questions:
                    existing = session.exec(select(QuizQuestion).where(QuizQuestion.question_text == q.question_text)).first()
                    if not existing:
                        session.add(q)
                session.commit()
                questions = session.exec(statement).all()

        if len(questions) < limit:
            raise HTTPException(status_code=404, detail=f"'{category}' için yeterli soru üretilemedi.")
        
        # Cevaplandı takibi yapmadan rastgele örnek döndür
        return random.sample(questions, limit)

# KULLANICI GEREKTİRMEYEN VERSİYON
@app.get("/challenges/random/", response_model=Challenge)
def get_random_challenge(category: str = "fun"):
    print("⚠️ UYARI: /challenges/random/ test modunda çalışıyor.")
    with Session(engine) as session:
        statement = select(Challenge).where(Challenge.category == category)
        all_challenges = session.exec(statement).all()

        if len(all_challenges) < 2:
            new_challenges = generate_new_challenges(category=category, count=10)
            if new_challenges:
                for c in new_challenges:
                    existing = session.exec(select(Challenge).where(Challenge.challenge_text == c.challenge_text)).first()
                    if not existing:
                        session.add(c)
                session.commit()
                all_challenges = session.exec(statement).all()

        if not all_challenges:
            raise HTTPException(status_code=404, detail="No challenges available.")
        
        # Tamamlandı takibi yapmadan rastgele birini döndür
        return random.choice(all_challenges)

# KULLANICIYA ÖZEL ENDPOINT'LER - TEST İÇİN GEÇİCİ OLARAK PASİF HALE GETİRİLDİ
@app.get("/user/topics/", response_model=List[str])
def get_user_topics():
    print("⚠️ UYARI: /user/topics/ test modunda boş liste döndürüyor.")
    return ["history", "science"] # Test için birkaç varsayılan konu

@app.put("/user/topics/")
def set_user_topics(topics: List[str]):
    print(f"⚠️ UYARI: /user/topics/ test modunda. Gelen konular: {topics}")
    return {"status": "success", "message": "User topics updated in test mode."}