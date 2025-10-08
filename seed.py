# seed.py (Ollama ve Googletrans Hibrit Versiyonu - SON VE STABİL KOD)

import os
import json
import requests
import time
from typing import List, Dict, Optional, Any
from dotenv import load_dotenv
from sqlmodel import Field, SQLModel, Session, create_engine, select
# YENİ İÇE AKTARMA: Ücretsiz çeviri için googletrans
from googletrans import Translator, LANGUAGES as GT_LANGUAGES

# --- 1. KONFİGÜRASYON ---
print("🌱 Garantili veri doldurma script'i başlatılıyor... (OLLAMA & GOOGLETRANS HİBRİT MODU - STABİL SÜRÜM)")
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL .env dosyasında tanımlanmalıdır!")

engine = create_engine(DATABASE_URL, echo=False)
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "llama3"

# DİLLER: zh-CN (Basitleştirilmiş Çince) en stabil kod olarak kullanılıyor.
# Çeviri hatalarını azaltmak için bekleme süresi (throttle) eklenmiştir.
LANGUAGES = ["en", "tr", "fr", "de", "it", "es", "ru", "zh-CN", "ja", "hi", "ar"]

# Googletrans'tan bir Translator nesnesi oluşturuluyor
try:
    translator = Translator()
except Exception as e:
    print(f"HATA: Googletrans Translator nesnesi başlatılamadı: {e}")
    # Eğer başlatılamazsa, fallback mekanizması çalışacaktır.

TOPICS = {
    "history": "History", "science": "Science", "art": "Art", "sports": "Sports", "technology": "Technology", 
    "cinema_tv": "Cinema & TV", "music": "Music", "nature_animals": "Nature & Animals", 
    "geography_travel": "Geography & Travel", "mythology": "Mythology", "philosophy": "Philosophy", "literature": "Literature", 
    "space_astronomy": "Space & Astronomy", "health_fitness": "Health & Fitness", "economics_finance": "Economics & Finance", 
    "architecture": "Architecture", "video_games": "Video Games", "general_culture": "General Knowledge", "fun_facts": "Fun Facts"
}

# --- 2. VERİ MODELLERİ ---
class DailyInfo(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); info_texts: str; category: str = Field(index=True); source: Optional[str] = None
class QuizQuestion(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); question_texts: str; options_texts: str; correct_answer_index: int; category: str = Field(index=True)
class Challenge(SQLModel, table=True): id: Optional[int] = Field(default=None, primary_key=True); challenge_texts: str; category: str = Field(default="fun", index=True)

def create_db_and_tables(): SQLModel.metadata.create_all(engine)

# --- 3. YARDIMCI FONKSİYONLAR ---

def make_ollama_api_call(prompt: str) -> Optional[str]:
    """Ollama'ya (kendi bilgisayarımıza) istek yapar."""
    try:
        # Cevabın yarıda kesilmemesi için 'num_predict' parametresi eklendi.
        payload = {"model": MODEL_NAME, "prompt": prompt, "stream": False, "options": {"temperature": 0.7, "num_predict": 2048}}
        response = requests.post(OLLAMA_URL, json=payload, timeout=180)
        response.raise_for_status()
        response_json = response.json()
        return response_json.get('response', '').strip()
    except requests.exceptions.ConnectionError:
        print("\nHATA: Ollama sunucusuna bağlanılamadı. Lütfen 'ollama run llama3' komutunun çalıştığından emin olun."); raise
    except requests.exceptions.ReadTimeout:
        print("HATA: Modelden cevap çok uzun sürdü. Yeniden deneniyor..."); return None
    except Exception as e:
        print(f"Bilinmeyen Ollama hatası: {e}"); time.sleep(5); return None

def clean_json_response(text: str) -> Optional[Any]:
    """API'den gelen kirli metnin içinden JSON'ı akıllıca ayıklar."""
    if not text: return None
    try:
        start_index = text.find('{')
        end_index = text.rfind('}')
        if start_index != -1 and end_index != -1:
            json_text = text[start_index : end_index + 1]
            return json.loads(json_text)
    except (json.JSONDecodeError, IndexError):
        pass
    try:
        if '```json' in text:
            cleaned_text = text.split('```json')[1].split('```')[0].strip()
            return json.loads(cleaned_text)
    except (json.JSONDecodeError, IndexError, AttributeError):
        pass
    print(f"Hata: Yanıtın içinden geçerli bir JSON ayıklanamadı. Yanıt: {text[:200]}")
    return None

# --- YENİ ÇEVİRİ FONKSİYONLARI (GOOGLETRANS KULLANILARAK) ---

def translate_text(text_en: str) -> Dict[str, str]:
    """Tek bir metni Googletrans kütüphanesi kullanarak çevirir (Hız azaltıcı bekleme eklendi)."""
    print(f"  - Googletrans ile çevriliyor: '{text_en[:40]}...'")
    translated_data = {"en": text_en}
    
    for lang in LANGUAGES:
        if lang == 'en':
            continue
            
        try:
            # Hız sınırını aşmamak için bekleme eklendi
            time.sleep(1)
            
            translation = translator.translate(text_en, dest=lang) 
            translated_data[lang] = translation.text
        except Exception as e:
            # Hata durumunda İngilizce metni kullanır (fallback)
            print(f"  - UYARI: {lang} çevirisi başarısız oldu ({e}). İngilizce metin kullanılıyor.")
            translated_data[lang] = text_en 

    return translated_data

def translate_quiz(quiz_en: Dict) -> Dict:
    """Tek bir quiz objesini Googletrans kütüphanesi kullanarak çevirir (Hız azaltıcı bekleme eklendi)."""
    print(f"  - Googletrans ile çevriliyor: '{quiz_en['question'][:40]}...'")
    translated_item = {"en": {"question": quiz_en["question"], "options": quiz_en["options"]}}
    
    for lang in LANGUAGES:
        if lang == 'en':
            continue
            
        try:
            # 1. Soruyu çevir
            time.sleep(1) # Soruyu çevirmeden önce bekle
            q_translation = translator.translate(quiz_en["question"], dest=lang).text
            
            # 2. Seçenekleri çevir
            options_translated = []
            for opt in quiz_en["options"]:
                # Her seçeneği çevirmeden önce bekle
                time.sleep(1) 
                opt_translation = translator.translate(opt, dest=lang).text
                options_translated.append(opt_translation)
                
            translated_item[lang] = {
                "question": q_translation, 
                "options": options_translated
            }
            
        except Exception as e:
            # Hata durumunda İngilizce metni kullanır (fallback)
            print(f"  - UYARI: {lang} çevirisi başarısız oldu ({e}). İngilizce metin kullanılıyor.")
            translated_item[lang] = {"question": quiz_en["question"], "options": quiz_en["options"]}

    return translated_item

# --- 4. VERİ ÜRETME ANA FONKSİYONU ---
def seed_database():
    create_db_and_tables()
    print("Veritabanı tabloları kontrol edildi/oluşturuldu.")
    with Session(engine) as session:
        # --- Challenges ---
        if not session.exec(select(Challenge)).first():
            print("\n💪 10 adet geçerli Challenge toplanıyor...")
            valid_challenges_en = []
            
            # YENİ PROMPT: Malzeme gerektirmeyen, ekransız görevler istenecek.
            challenge_prompt = (
                'Create one short, simple, fun, SFW challenge for a mobile app. '
                'The challenge MUST NOT require any external materials, tools, or physical objects (e.g., no "find a spoon"). '
                'It should only involve simple body movements or looking at the screen (e.g., "Do 10 jumping jacks" or "Stare without blinking"). '
                'Respond with only the challenge text, nothing else.'
            )
            
            while len(valid_challenges_en) < 10:
                response = make_ollama_api_call(challenge_prompt)
                if response and len(response) > 5:
                    valid_challenges_en.append(response.strip().strip('"'))
                    print(f"  - Geçerli {len(valid_challenges_en)}/10 challenge toplandı.")
            
            print("\n💪 Challenge'lar çevriliyor...")
            for text_en in valid_challenges_en:
                translated_data = translate_text(text_en)
                session.add(Challenge(challenge_texts=json.dumps(translated_data, ensure_ascii=False)))
            session.commit()
            print("✅ Challenge'lar eklendi.")
        else:
            print("☑️ Challenge'lar zaten mevcut, geçiliyor.")
            
        # --- Topics Döngüsü ---
        for topic_key, topic_name in TOPICS.items():
            # DailyInfo
            if not session.exec(select(DailyInfo).where(DailyInfo.category == topic_key)).first():
                print(f"\nℹ️ '{topic_name}' için 5 adet geçerli bilgi toplanıyor...")
                valid_infos_en = []
                while len(valid_infos_en) < 5:
                    prompt = f'Create one interesting, little-known fun fact about "{topic_name}". Respond with only the fact as a clean string, nothing else.'
                    response = make_ollama_api_call(prompt)
                    if response and len(response) > 10:
                        valid_infos_en.append(response.strip().strip('"'))
                        print(f"  - Geçerli {len(valid_infos_en)}/5 bilgi toplandı.")

                print(f"ℹ️ '{topic_name}' bilgileri çevriliyor...")
                for info_en in valid_infos_en:
                    translated_data = translate_text(info_en)
                    session.add(DailyInfo(info_texts=json.dumps(translated_data, ensure_ascii=False), category=topic_key))
                session.commit()
                print(f"✅ '{topic_name}' için bilgiler eklendi.")
            else:
                print(f"☑️ '{topic_name}' bilgileri zaten mevcut, geçiliyor.")

            # QuizQuestion
            if not session.exec(select(QuizQuestion).where(QuizQuestion.category == topic_key)).first():
                print(f"\n❓ '{topic_name}' için 10 adet geçerli soru toplanıyor...")
                valid_quizzes_en = []
                while len(valid_quizzes_en) < 10:
                    prompt = f'Create one multiple-choice question about "{topic_name}". Provide 4 options. Indicate the correct answer index (from 0 to 3). Respond ONLY in this JSON format: {{"question": "...", "options": ["...", "...", "...", "..."], "correct_answer_index": ...}}'
                    response_text = make_ollama_api_call(prompt)
                    data = clean_json_response(response_text)
                    if data and all([data.get("question"), data.get("options"), isinstance(data.get("options"), list), len(data.get("options")) == 4, data.get("correct_answer_index") is not None]):
                        valid_quizzes_en.append(data)
                        print(f"  - Geçerli {len(valid_quizzes_en)}/10 soru toplandı.")
                
                print(f"\n❓ '{topic_name}' soruları çevriliyor...")
                for quiz_en in valid_quizzes_en:
                    translated_item = translate_quiz(quiz_en)
                    
                    all_items_valid = True
                    for lang, data in translated_item.items():
                        # Çeviri kütüphanesinden gelen verinin yapısını kontrol et
                        if not isinstance(data, dict) or "options" not in data or "question" not in data:
                            print(f"  - UYARI: '{lang}' dilinde çeviri eksik geldi, bu soru atlanıyor.")
                            all_items_valid = False
                            break
                    
                    if not all_items_valid:
                        continue

                    question_texts_for_db = {lang: data["question"] for lang, data in translated_item.items()}
                    options_texts_for_db = {lang: data["options"] for lang, data in translated_item.items()}
                    new_quiz = QuizQuestion(
                        question_texts=json.dumps(question_texts_for_db, ensure_ascii=False),
                        options_texts=json.dumps(options_texts_for_db, ensure_ascii=False),
                        correct_answer_index=quiz_en["correct_answer_index"],
                        category=topic_key
                    )
                    session.add(new_quiz)
                session.commit()
                print(f"✅ '{topic_name}' için sorular eklendi.")
            else:
                print(f"☑️ '{topic_name}' soruları zaten mevcut, geçiliyor.")

    print("\n🎉 Tüm verilerin doldurma işlemi tamamlandı!")

if __name__ == "__main__":
    seed_database()