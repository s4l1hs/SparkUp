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

# --- 2. VERİ MODELLERİ ---
class DailyInfo(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); info_texts: str; category: str = Field(index=True); source: Optional[str] = None
class QuizQuestion(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); question_texts: str; options_texts: str; correct_answer_index: int; category: str = Field(index=True)
class Challenge(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); challenge_texts: str; category: str = Field(default="fun", index=True)
class UserScore(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); score: int = Field(default=0); user_id: int = Field(foreign_key="user.id", unique=True)
class User(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); firebase_uid: str = Field(unique=True, index=True); email: Optional[str] = None; language_code: str = Field(default="en")

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

# --- 3. YARDIMCI FONKSİYONLAR ---
async def make_api_call(prompt: str):
    while True:
        try:
            response = await ai_model.generate_content_async(prompt)
            await asyncio.sleep(31) # Her başarılı çağrı sonrası bekle
            return response
        except ResourceExhausted:
            print("...RATE LIMIT'e takıldı. 35 saniye bekleniyor...")
            await asyncio.sleep(35)
        except Exception as e:
            print(f"Bilinmeyen API hatası: {e}")
            return None

async def translate_text_async(text: str) -> Dict[str, str]:
    lang_list = ", ".join(LANGUAGES)
    prompt = f'Translate the following English text into these languages: {lang_list}. Provide your response as a single JSON object where keys are language codes (like "en", "tr") and values are the translated strings.\n\nText: "{text}"'
    response = await make_api_call(prompt)
    if response and response.text:
        try:
            cleaned_response = response.text.strip().replace("```json", "").replace("```", "")
            return json.loads(cleaned_response)
        except json.JSONDecodeError:
             print(f"Hata: Çeviri JSON formatında değil. Yanıt: {response.text}")
    return {lang: text for lang in LANGUAGES} # Başarısız olursa İngilizce'yi kullan

async def translate_options_async(options: List[str]) -> Dict[str, List[str]]:
    result = {lang: [] for lang in LANGUAGES}
    for option in options:
        translated_dict = await translate_text_async(option)
        for lang in LANGUAGES:
            result[lang].append(translated_dict.get(lang, "Option"))
    return result

# --- 4. GARANTİLİ VERİ ÜRETME VE DOLDURMA ---
async def seed_database():
    create_db_and_tables()
    print("Veritabanı tabloları kontrol edildi/oluşturuldu.")

    with Session(engine) as session:
        # --- Challenges ---
        if not session.exec(select(Challenge)).first():
            print("💪 10 adet geçerli Challenge toplanıyor...")
            valid_challenges_en = []
            while len(valid_challenges_en) < 10:
                prompt_challenges = "Create one short, simple, and fun challenge that a user can do instantly. Respond as a single JSON string."
                response = await make_api_call(prompt_challenges)
                if response and response.text:
                    try:
                        challenge_text = json.loads(response.text.strip().replace("```json", "").replace("```", ""))
                        if isinstance(challenge_text, str) and challenge_text:
                            valid_challenges_en.append(challenge_text)
                            print(f"  - Geçerli {len(valid_challenges_en)}/10 challenge toplandı...")
                        else:
                             print("  - Geçersiz formatta challenge geldi, yeniden isteniyor...")
                    except json.JSONDecodeError:
                        print("  - JSON formatında olmayan challenge geldi, yeniden isteniyor...")

            print("\n💪 Challenge'lar çevriliyor...")
            for text_en in valid_challenges_en:
                translated_texts = await translate_text_async(text_en)
                session.add(Challenge(challenge_texts=json.dumps(translated_texts, ensure_ascii=False)))
            session.commit()
            print("✅ Challenge'lar eklendi.")
        else:
            print("☑️ Challenge'lar zaten mevcut, geçiliyor.")

        # --- Infos and Quizzes per Topic ---
        for topic_key, topic_name in TOPICS.items():
            # Infos
            if not session.exec(select(DailyInfo).where(DailyInfo.category == topic_key)).first():
                print(f"\nℹ️ '{topic_name}' için 5 adet geçerli bilgi toplanıyor...")
                valid_infos_en = []
                while len(valid_infos_en) < 5:
                    prompt_info = f"Generate one surprising and interesting fact about '{topic_name}'. Provide a source. Respond in JSON format: {{\"fact\": \"...\", \"source\": \"...\"}}"
                    response = await make_api_call(prompt_info)
                    if response and response.text:
                        try:
                            info_data = json.loads(response.text.strip().replace("```json", "").replace("```", ""))
                            if info_data.get("fact") and info_data.get("source"):
                                valid_infos_en.append(info_data)
                                print(f"  - Geçerli {len(valid_infos_en)}/5 bilgi toplandı...")
                            else:
                                print("  - Geçersiz formatta bilgi geldi, yeniden isteniyor...")
                        except json.JSONDecodeError:
                            print("  - JSON formatında olmayan bilgi geldi, yeniden isteniyor...")

                print(f"\nℹ️ '{topic_name}' bilgileri çevriliyor...")
                for info_data in valid_infos_en:
                    translated_facts = await translate_text_async(info_data['fact'])
                    session.add(DailyInfo(info_texts=json.dumps(translated_facts, ensure_ascii=False), category=topic_key, source=info_data['source']))
                session.commit()
                print(f"✅ '{topic_name}' bilgileri eklendi.")
            else:
                print(f"☑️ '{topic_name}' bilgileri zaten mevcut, geçiliyor.")

            # Quizzes
            if not session.exec(select(QuizQuestion).where(QuizQuestion.category == topic_key)).first():
                print(f"\n❓ '{topic_name}' için 10 adet geçerli soru toplanıyor...")
                valid_quizzes_en = []
                while len(valid_quizzes_en) < 10:
                    prompt_quiz = f'Create one multiple-choice question about \'{topic_name}\'. Provide 4 options. Indicate correct answer index. Respond in JSON format: {{"question_text": "...", "options": ["...", "..."], "correct_answer_index": 0}}'
                    response = await make_api_call(prompt_quiz)
                    if response and response.text:
                        try:
                            quiz_data = json.loads(response.text.strip().replace("```json", "").replace("```", ""))
                            question_text = quiz_data.get("question_text") or quiz_data.get("question")
                            options = quiz_data.get("options")
                            correct_index = quiz_data.get("correct_answer_index") or quiz_data.get("correctAnswerIndex") or quiz_data.get("answer") or quiz_data.get("answer_index") or quiz_data.get("correct_option_index")
                            if all([question_text, options, isinstance(options, list), len(options) == 4, correct_index is not None]):
                                valid_quizzes_en.append(quiz_data)
                                print(f"  - Geçerli {len(valid_quizzes_en)}/10 soru toplandı...")
                            else:
                                print("  - Geçersiz formatta soru geldi, yeniden isteniyor...")
                        except json.JSONDecodeError:
                            print("  - JSON formatında olmayan soru geldi, yeniden isteniyor...")

                print(f"\n❓ '{topic_name}' soruları çevriliyor...")
                for quiz_data in valid_quizzes_en:
                    question_text = quiz_data.get("question_text") or quiz_data.get("question") # Tekrar alıyoruz
                    options = quiz_data.get("options")
                    correct_index = quiz_data.get("correct_answer_index") or quiz_data.get("correctAnswerIndex") or quiz_data.get("answer") or quiz_data.get("answer_index") or quiz_data.get("correct_option_index")
                    
                    translated_questions = await translate_text_async(question_text)
                    translated_options = await translate_options_async(options)
                    session.add(QuizQuestion(question_texts=json.dumps(translated_questions, ensure_ascii=False), options_texts=json.dumps(translated_options, ensure_ascii=False), correct_answer_index=correct_index, category=topic_key))
                session.commit()
                print(f"✅ '{topic_name}' için 10 adet soru eklendi.")
            else:
                print(f"☑️ '{topic_name}' soruları zaten mevcut, geçiliyor.")

    print("\n🎉 Tüm verilerin doldurma işlemi tamamlandı!")

if __name__ == "__main__":
    asyncio.run(seed_database())