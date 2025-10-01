import os
import json
import random
from typing import List, Optional, Dict

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

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None

class DailyInfo(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    info_text: str = Field(unique=True)
    category: str = Field(index=True)
    source: Optional[str] = None

class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    question_text: str = Field(unique=True)
    options: str
    correct_answer_index: int
    category: str = Field(index=True)

class Challenge(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    challenge_text: str = Field(unique=True)
    category: str = Field(default="fun", index=True)

class UserSeenInfo(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    dailyinfo_id: int = Field(foreign_key="dailyinfo.id", primary_key=True)

class UserAnsweredQuestion(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)

class UserCompletedChallenge(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    challenge_id: int = Field(foreign_key="challenge.id", primary_key=True)


# --- 3. YAPAY ZEKA İLE İÇERİK ÜRETME FONKSİYONLARI ---

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


# --- 4. GÜVENLİK VE KİMLİK DOĞRULAMA ---

token_auth_scheme = HTTPBearer()

def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session: Session = Depends(lambda: Session(engine))) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
        db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
        if not db_user:
            print(f"New user detected. Creating user with UID: {uid}")
            db_user = User(firebase_uid=uid, email=decoded_token.get('email'))
            session.add(db_user)
            session.commit()
            session.refresh(db_user)
        return db_user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication credentials: {e}")


# --- 5. UYGULAMA BAŞLANGIÇ OLAYLARI ---

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()


# --- 6. API ENDPOINT'LERİ ---

@app.get("/")
def read_root():
    return {"message": "Welcome to the SparkUp Backend!"}

@app.get("/topics/", response_model=Dict[str, str])
def get_topics():
    return TOPICS

@app.get("/info/random/", response_model=DailyInfo)
def get_random_info(category: str = "general_culture", db_user: User = Depends(get_current_user)):
    with Session(engine) as session:
        seen_info_ids = session.exec(select(UserSeenInfo.dailyinfo_id).where(UserSeenInfo.user_id == db_user.id)).all()
        statement = select(DailyInfo).where(DailyInfo.category == category).where(DailyInfo.id.notin_(seen_info_ids))
        unseen_info = session.exec(statement).all()
        
        if not unseen_info:
            new_info = generate_new_info(topic_key=category)
            if new_info:
                session.add(new_info)
                session.commit()
                session.refresh(new_info)
                unseen_info = [new_info]
            else:
                raise HTTPException(status_code=503, detail="AI service unavailable.")
        
        chosen_info = random.choice(unseen_info)
        seen_record = UserSeenInfo(user_id=db_user.id, dailyinfo_id=chosen_info.id)
        session.add(seen_record)
        session.commit()
        return chosen_info

@app.get("/quiz/", response_model=List[QuizQuestion])
def get_quiz_questions(category: str, limit: int = 3, db_user: User = Depends(get_current_user)):
    with Session(engine) as session:
        answered_question_ids = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
        statement = select(QuizQuestion).where(QuizQuestion.category == category).where(QuizQuestion.id.notin_(answered_question_ids))
        unanswered_questions = session.exec(statement).all()
        
        if len(unanswered_questions) < limit:
            new_questions = generate_new_quiz_questions(topic_key=category)
            if new_questions:
                for q in new_questions:
                    existing = session.exec(select(QuizQuestion).where(QuizQuestion.question_text == q.question_text)).first()
                    if not existing:
                        session.add(q)
                session.commit()
                unanswered_questions = session.exec(statement).all()

        if len(unanswered_questions) < limit:
            raise HTTPException(status_code=404, detail=f"Not enough questions for category '{category}'.")
        
        chosen_questions = random.sample(unanswered_questions, limit)
        for q in chosen_questions:
            answered_record = UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=q.id)
            session.add(answered_record)
        session.commit()
        return chosen_questions

@app.get("/challenges/random/", response_model=Challenge)
def get_random_challenge(category: str = "fun", db_user: User = Depends(get_current_user)):
    with Session(engine) as session:
        completed_challenge_ids = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
        statement = select(Challenge).where(Challenge.category == category).where(Challenge.id.notin_(completed_challenge_ids))
        uncompleted_challenges = session.exec(statement).all()

        if len(uncompleted_challenges) < 2:
            new_challenges = generate_new_challenges(category=category, count=10)
            if new_challenges:
                for c in new_challenges:
                    existing = session.exec(select(Challenge).where(Challenge.challenge_text == c.challenge_text)).first()
                    if not existing:
                        session.add(c)
                session.commit()
                uncompleted_challenges = session.exec(statement).all()

        if not uncompleted_challenges:
            raise HTTPException(status_code=404, detail="No challenges available.")
        
        chosen_challenge = random.choice(uncompleted_challenges)
        completed_record = UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen_challenge.id)
        session.add(completed_record)
        session.commit()
        return chosen_challenge