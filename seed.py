# seed.py

import os
import json
import asyncio
from typing import List, Dict, Optional, Any
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

# echo=False production için daha iyidir, logları temiz tutar.
engine = create_engine(DATABASE_URL, echo=False)
genai.configure(api_key=GEMINI_API_KEY)

# Gemini Pro modelini seçiyoruz
ai_model = genai.GenerativeModel('models/gemini-pro-latest')

LANGUAGES = ["en", "tr", "fr", "de", "it", "es", "ru", "zh", "ja", "hi", "ar"]
TOPICS = {
    "history": "History",
    "science": "Science",
    "art": "Art",
    "sports": "Sports",
    "technology": "Technology",
    "general_culture": "General Knowledge"
}

# --- 2. VERİ MODELLERİ (Python 3.9 UYUMLU) ---
class DailyInfo(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    info_texts: str  # JSON string: {"en": "...", "tr": "..."}
    category: str = Field(index=True)
    source: Optional[str] = None

class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    question_texts: str  # JSON string: {"en": "...", "tr": "..."}
    options_texts: str   # JSON string: {"en": ["A", "B"], "tr": ["X", "Y"]}
    correct_answer_index: int
    category: str = Field(index=True)

class Challenge(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    challenge_texts: str  # JSON string: {"en": "...", "tr": "..."}
    category: str = Field(default="fun", index=True)

class UserScore(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    score: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None
    language_code: str = Field(default="en")
    notifications_enabled: bool = Field(default=True)

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

# --- 3. YARDIMCI FONKSİYONLAR ---
async def make_api_call(prompt: str) -> Optional[str]:
    """API'ye istek yapar, rate limit ve genel hataları yönetir."""
    while True:
        try:
            # Proaktif olarak rate limit'e takılmamak için bekleme.
            await asyncio.sleep(2)
            response = await ai_model.generate_content_async(prompt)
            return response.text
        except ResourceExhausted:
            print("...RATE LIMIT'e takıldı. 61 saniye bekleniyor...")
            await asyncio.sleep(61)
        except Exception as e:
            print(f"Bilinmeyen API hatası: {e}, 15 saniye sonra yeniden denenecek.")
            await asyncio.sleep(15)

def clean_json_response(text: str) -> Optional[Dict[str, Any]]:
    """API'den gelen yanıtı temizler ve JSON'a çevirir."""
    if not text:
        return None
    try:
        cleaned_text = text.strip().replace("```json", "").replace("```", "")
        return json.loads(cleaned_text)
    except json.JSONDecodeError:
        print(f"Hata: Yanıt geçerli bir JSON formatında değil. Yanıt: {text[:200]}")
        return None

async def translate_text_async(text: str) -> Dict[str, str]:
    """Tek bir metni hedeflenen tüm dillere çevirir."""
    lang_list = ", ".join(LANGUAGES)
    prompt = f'Translate the following English text into these languages: {lang_list}. Provide your response as a single JSON object where keys are language codes (e.g., "en", "tr") and values are the translated strings.\n\nText: "{text}"'
    
    response_text = await make_api_call(prompt)
    translated_data = clean_json_response(response_text)
    
    if isinstance(translated_data, dict):
        # Başarı durumunda eksik dilleri İngilizce ile doldur
        for lang in LANGUAGES:
            if lang not in translated_data:
                translated_data[lang] = text
        return translated_data
    
    # Hata durumunda tüm diller için İngilizce metni döndür
    print(f"  - Çeviri hatası (fallback kullanılıyor): '{text}'")
    return {lang: text for lang in LANGUAGES}

### YENİ VE VERİMLİ ###
async def translate_batch_async(texts: List[str]) -> Dict[str, List[str]]:
    """Birden fazla metni (örneğin soru şıklarını) TEK BİR API çağrısında çevirir."""
    lang_list = ", ".join(LANGUAGES)
    numbered_texts = "\n".join([f'{i+1}. "{text}"' for i, text in enumerate(texts)])

    prompt = (
        f'Translate each of the following English texts into these languages: {lang_list}. '
        'Provide your response as a single JSON object where the top-level keys are language codes (e.g., "en", "tr"). '
        'The value for each language code should be an array of the translated strings, in the exact original order.\n\n'
        f'Texts to translate:\n{numbered_texts}'
    )
    
    response_text = await make_api_call(prompt)
    translated_data = clean_json_response(response_text)

    if isinstance(translated_data, dict) and all(isinstance(v, list) for v in translated_data.values()):
         # Başarı durumunda eksik dilleri İngilizce ile doldur
        for lang in LANGUAGES:
            if lang not in translated_data or len(translated_data[lang]) != len(texts):
                translated_data[lang] = texts # Eğer format bozuksa orijinaliyle değiştir
        return translated_data

    # Hata durumunda tüm diller için İngilizce listeyi döndür
    print(f"  - Toplu çeviri hatası (fallback kullanılıyor): {texts}")
    return {lang: texts for lang in LANGUAGES}


# --- 4. GARANTİLİ VERİ ÜRETME ---
async def seed_database():
    create_db_and_tables()
    print("Veritabanı tabloları kontrol edildi/oluşturuldu.")

    with Session(engine) as session:
        # --- Challenges ---
        if not session.exec(select(Challenge)).first():
            print("\n💪 10 adet geçerli Challenge toplanıyor...")
            valid_challenges_en = []
            while len(valid_challenges_en) < 10:
                prompt = 'Create one short, simple, fun, SFW (safe-for-work) challenge for a mobile app. Example: "Take a photo of something yellow." Respond with only a single JSON string. Example: "Find something taller than you."'
                response_text = await make_api_call(prompt)
                challenge_text = clean_json_response(response_text)
                
                if isinstance(challenge_text, str) and challenge_text:
                    valid_challenges_en.append(challenge_text)
                    print(f"  - Geçerli {len(valid_challenges_en)}/10 challenge toplandı...")
                else:
                    print("  - Geçersiz formatta challenge, yeniden isteniyor...")
            
            print("\n💪 Challenge'lar çevriliyor...")
            for text_en in valid_challenges_en:
                print(f"  - Çevriliyor: '{text_en}'")
                translated = await translate_text_async(text_en)
                session.add(Challenge(challenge_texts=json.dumps(translated, ensure_ascii=False)))
            session.commit()
            print("✅ Challenge'lar eklendi.")
        else:
            print("☑️ Challenge'lar zaten mevcut, geçiliyor.")

        # --- Infos and Quizzes ---
        for topic_key, topic_name in TOPICS.items():
            # TODO: DailyInfo üretme ve çevirme mantığı buraya eklenebilir.
            if not session.exec(select(DailyInfo).where(DailyInfo.category == topic_key)).first():
                 print(f"ℹ️ '{topic_name}' için bilgi üretimi atlanıyor (kod eklenmemiş).")
            else:
                 print(f"☑️ '{topic_name}' bilgileri zaten mevcut, geçiliyor.")

            if not session.exec(select(QuizQuestion).where(QuizQuestion.category == topic_key)).first():
                print(f"\n❓ '{topic_name}' için 10 adet geçerli soru toplanıyor...")
                valid_quizzes_en = []
                while len(valid_quizzes_en) < 10:
                    prompt = f'Create one multiple-choice question about "{topic_name}". Provide exactly 4 options. Indicate the correct answer index (from 0 to 3). Respond ONLY in this JSON format: {{"question": "...", "options": ["...", "...", "...", "..."], "correct_answer_index": ...}}'
                    response_text = await make_api_call(prompt)
                    data = clean_json_response(response_text)
                    
                    if data and isinstance(data, dict):
                        q_text = data.get("question")
                        opts = data.get("options")
                        idx = data.get("correct_answer_index")
                        
                        if all([q_text, opts, isinstance(opts, list), len(opts) == 4, idx is not None, isinstance(idx, int), 0 <= idx <= 3]):
                            valid_quizzes_en.append(data)
                            print(f"  - Geçerli {len(valid_quizzes_en)}/10 soru toplandı: '{q_text[:40]}...'")
                        else:
                            print(f"  - Geçersiz formatta soru (içerik eksik/yanlış), yeniden isteniyor...")
                    else:
                        print("  - JSON formatında olmayan soru, yeniden isteniyor...")
                
                print(f"\n❓ '{topic_name}' soruları çevriliyor ve veritabanına ekleniyor...")
                for quiz_data in valid_quizzes_en:
                    q_text_en = quiz_data["question"]
                    opts_en = quiz_data["options"]
                    correct_idx = quiz_data["correct_answer_index"]

                    print(f"  -> Çevriliyor: {q_text_en[:40]}...")
                    
                    # Soruyu çevir (1 API çağrısı)
                    translated_question = await translate_text_async(q_text_en)
                    
                    # Şıkları toplu olarak çevir (1 API çağrısı)
                    translated_options = await translate_batch_async(opts_en)
                    
                    new_quiz = QuizQuestion(
                        question_texts=json.dumps(translated_question, ensure_ascii=False),
                        options_texts=json.dumps(translated_options, ensure_ascii=False),
                        correct_answer_index=correct_idx,
                        category=topic_key
                    )
                    session.add(new_quiz)
                
                # ### DEĞİŞİKLİK ###
                # Tüm sorular eklendikten sonra tek seferde commit yap.
                session.commit()
                print(f"✅ '{topic_name}' için {len(valid_quizzes_en)} adet soru eklendi.")
            else:
                print(f"☑️ '{topic_name}' soruları zaten mevcut, geçiliyor.")

    print("\n🎉 Tüm verilerin doldurma işlemi tamamlandı!")

if __name__ == "__main__":
    asyncio.run(seed_database())