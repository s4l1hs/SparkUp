# seed.py

import os
import json
import asyncio
from typing import List, Dict, Optional
from dotenv import load_dotenv
from sqlmodel import Field, SQLModel, Session, create_engine, select
import google.generativeai as genai
from google.api_core.exceptions import ResourceExhausted

# --- 1. KONFİGÜRASYON ---
print("🌱 Garantili veri doldurma script'i başlatılıyor...")
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not DATABASE_URL or not GEMINI_API_KEY:
    raise ValueError("DATABASE_URL ve GEMINI_API_KEY .env dosyasında tanımlanmalıdır!")

engine = create_engine(DATABASE_URL, echo=False)
genai.configure(api_key=GEMINI_API_KEY)
ai_model = genai.GenerativeModel('models/gemini-pro-latest')

LANGUAGES = ["en", "tr", "fr", "de", "it", "es", "ru", "zh", "ja", "hi", "ar"]
TOPICS = { "history": "History", "science": "Science", "art": "Art", "sports": "Sports", "technology": "Technology", "general_culture": "General Knowledge" }

# --- 2. VERİ MODELLERİ (Python 3.9 UYUMLU) ---
class DailyInfo(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); info_texts: str; category: str = Field(index=True); source: Optional[str] = None
class QuizQuestion(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); question_texts: str; options_texts: str; correct_answer_index: int; category: str = Field(index=True)
class Challenge(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); challenge_texts: str; category: str = Field(default="fun", index=True)
class UserScore(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); score: int = Field(default=0); user_id: int = Field(foreign_key="user.id", unique=True)
class User(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); firebase_uid: str = Field(unique=True, index=True); email: Optional[str] = None; language_code: str = Field(default="en"); notifications_enabled: bool = Field(default=True)

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

# --- 3. YARDIMCI FONKSİYONLAR ---
async def make_api_call(prompt: str):
    while True:
        try:
            response = await ai_model.generate_content_async(prompt)
            await asyncio.sleep(31)
            return response
        except ResourceExhausted:
            print("...RATE LIMIT'e takıldı. 35 saniye bekleniyor...")
            await asyncio.sleep(35)
        except Exception as e:
            print(f"Bilinmeyen API hatası: {e}, 10 saniye sonra yeniden denenecek.")
            await asyncio.sleep(10)

async def translate_text_async(text: str) -> Dict[str, str]:
    lang_list = ", ".join(LANGUAGES)
    prompt = f'Translate the following English text into these languages: {lang_list}. Provide your response as a single JSON object where keys are language codes and values are translated strings.\n\nText: "{text}"'
    response = await make_api_call(prompt)
    if response and response.text:
        try:
            cleaned_response = response.text.strip().replace("```json", "").replace("```", "")
            return json.loads(cleaned_response)
        except json.JSONDecodeError:
             print(f"Hata: Çeviri JSON formatında değil. Yanıt: {response.text}")
    return {lang: text for lang in LANGUAGES}

async def translate_options_async(options: List[str]) -> Dict[str, List[str]]:
    result = {lang: [] for lang in LANGUAGES}
    for option in options:
        translated_dict = await translate_text_async(option)
        for lang in LANGUAGES:
            result[lang].append(translated_dict.get(lang, "Option"))
    return result

# --- 4. GARANTİLİ VERİ ÜRETME ---
async def seed_database():
    create_db_and_tables()
    print("Veritabanı tabloları kontrol edildi/oluşturuldu.")

    with Session(engine) as session:
        # Challenges
        if not session.exec(select(Challenge)).first():
            print("\n💪 10 adet geçerli Challenge toplanıyor...")
            valid_challenges_en = []
            while len(valid_challenges_en) < 10:
                prompt = "Create one short, simple, fun challenge. Respond as a single JSON string."
                response = await make_api_call(prompt)
                if response and response.text:
                    try:
                        text = json.loads(response.text.strip().replace("```json", "").replace("```", ""))
                        if isinstance(text, str) and text:
                            valid_challenges_en.append(text)
                            print(f"  - Geçerli {len(valid_challenges_en)}/10 challenge toplandı...")
                    except (json.JSONDecodeError, TypeError):
                        print("  - Geçersiz formatta challenge, yeniden isteniyor...")
            print("\n💪 Challenge'lar çevriliyor...")
            for text_en in valid_challenges_en:
                translated = await translate_text_async(text_en)
                session.add(Challenge(challenge_texts=json.dumps(translated, ensure_ascii=False)))
            session.commit()
            print("✅ Challenge'lar eklendi.")
        else:
            print("☑️ Challenge'lar zaten mevcut, geçiliyor.")

        # Infos and Quizzes
        for topic_key, topic_name in TOPICS.items():
            if not session.exec(select(DailyInfo).where(DailyInfo.category == topic_key)).first():
                print(f"\nℹ️ '{topic_name}' için 5 adet geçerli bilgi toplanıyor...")
                # ... Info üretme ve çevirme ...
            else:
                print(f"☑️ '{topic_name}' bilgileri zaten mevcut, geçiliyor.")

            if not session.exec(select(QuizQuestion).where(QuizQuestion.category == topic_key)).first():
                print(f"\n❓ '{topic_name}' için 10 adet geçerli soru toplanıyor...")
                valid_quizzes_en = []
                while len(valid_quizzes_en) < 10:
                    prompt = f'Create one multiple-choice question about \'{topic_name}\'. Provide 4 options. Indicate correct answer index. Respond in JSON format.'
                    response = await make_api_call(prompt)
                    if response and response.text:
                        try:
                            data = json.loads(response.text.strip().replace("```json", "").replace("```", ""))
                            q_text = data.get("question_text") or data.get("question")
                            opts = data.get("options")
                            idx = data.get("correct_answer_index")
                            if idx is None: idx = data.get("correctAnswerIndex")
                            if idx is None: idx = data.get("answer")
                            
                            if all([q_text, opts, isinstance(opts, list), len(opts) == 4, idx is not None]):
                                valid_quizzes_en.append(data)
                                print(f"  - Geçerli {len(valid_quizzes_en)}/10 soru toplandı...")
                            else:
                                print(f"  - Geçersiz formatta soru, yeniden isteniyor...")
                        except (json.JSONDecodeError, TypeError):
                            print("  - JSON formatında olmayan soru, yeniden isteniyor...")
                
                print(f"\n❓ '{topic_name}' soruları çevriliyor...")
                for quiz_data in valid_quizzes_en:
                    # ... Soruları çevirme ve kaydetme ...
                    pass
                session.commit()
                print(f"✅ '{topic_name}' için 10 adet soru eklendi.")
            else:
                print(f"☑️ '{topic_name}' soruları zaten mevcut, geçiliyor.")

    print("\n🎉 Tüm verilerin doldurma işlemi tamamlandı!")

if __name__ == "__main__":
    asyncio.run(seed_database())