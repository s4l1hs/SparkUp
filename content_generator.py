import os
import json
import google.generativeai as genai
from dotenv import load_dotenv
from sqlmodel import Session, select

# Veritabanı modellerimizi ve motorumuzu ana uygulamamızdan import ediyoruz
from main import DailyInfo, QuizQuestion, engine

# .env dosyasındaki değişkenleri, özellikle API anahtarımızı yüklüyoruz
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Gemini API'ını yapılandırıyoruz
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash') # Hızlı ve verimli bir model seçiyoruz

def generate_daily_info(topic: str) -> dict:
    """
    Belirtilen konuda kısa, ilginç bir bilgi üretir.
    """
    print(f"'{topic}' konusunda ilginç bir bilgi üretiliyor...")
    
    # Yapay zekaya gönderdiğimiz talimat (prompt)
    prompt = f"""
    '{topic}' konusuyla ilgili, daha önce pek duyulmamış, şaşırtıcı ve ilginç bir bilgiyi kısaca yaz. 
    Bilginin kaynağını da belirt. Sadece bilgiyi ve kaynağını ver, başka bir açıklama yapma.
    Örnek:
    Bilgi: Bir ahtapotun üç kalbi vardır.
    Kaynak: National Geographic
    """
    
    response = model.generate_content(prompt)
    
    # Gelen cevabı işleyerek sözlük formatına getiriyoruz
    try:
        lines = response.text.strip().split('\n')
        info_text = lines[0].replace('Bilgi:', '').strip()
        source = lines[1].replace('Kaynak:', '').strip()
        
        return {
            "info_text": info_text,
            "category": topic,
            "source": source
        }
    except (IndexError, AttributeError) as e:
        print(f"Hata: Bilgi formatı anlaşılamadı. Gelen cevap: {response.text}")
        return None


def generate_quiz_question(topic: str) -> dict:
    """
    Belirtilen konuda, JSON formatında bir quiz sorusu üretir.
    """
    print(f"'{topic}' konusunda bir quiz sorusu üretiliyor...")
    
    # Yapay zekaya JSON formatında cevap vermesini söyleyen özel bir talimat (prompt)
    prompt = f"""
    '{topic}' konusuyla ilgili, genel kültür seviyesinde bir soru oluştur. 
    Soruya 4 adet şıklı cevap (options) sun. Bu şıklardan sadece biri doğru olmalı. 
    Doğru cevabın hangi indekste (0'dan başlayarak) olduğunu belirt.
    Cevabını, aşağıdaki anahtarları içeren bir JSON formatında ver:
    "question_text": "Sorunun metni buraya gelecek",
    "options": ["A şıkkı", "B şıkkı", "C şıkkı", "D şıkkı"],
    "correct_answer_index": 2 
    """
    
    response = model.generate_content(prompt)
    
    # Gelen cevabı temizleyip JSON'a çeviriyoruz
    try:
        # Bazen AI, cevabı ```json ... ``` bloğu içinde verir, bu bloğu temizliyoruz
        cleaned_response = response.text.strip().replace("```json", "").replace("```", "")
        quiz_data = json.loads(cleaned_response)
        
        # Seçenekleri veritabanına kaydetmek için tekrar JSON string'e çeviriyoruz
        quiz_data['options'] = json.dumps(quiz_data['options'], ensure_ascii=False)
        quiz_data['category'] = topic
        return quiz_data
        
    except (json.JSONDecodeError, AttributeError, KeyError) as e:
        print(f"Hata: Quiz formatı anlaşılamadı. Gelen cevap: {response.text}")
        return None

# Bu script doğrudan çalıştırıldığında aşağıdaki kodlar çalışır
if __name__ == "__main__":
    # Hangi konuda içerik üretmek istediğimizi seçiyoruz
    TOPIC = "uzay" 

    # --- Yeni bir DailyInfo üretip veritabanına kaydedelim ---
    info_data = generate_daily_info(topic=TOPIC)
    
    if info_data:
        with Session(engine) as session:
            # Bu bilginin veritabanında olup olmadığını kontrol et
            existing = session.exec(select(DailyInfo).where(DailyInfo.info_text == info_data["info_text"])).first()
            if not existing:
                db_info = DailyInfo.model_validate(info_data)
                session.add(db_info)
                session.commit()
                print("\n✅ Yeni bilgi veritabanına eklendi:")
                print(db_info.info_text)
            else:
                print("\n⚠️ Bu bilgi zaten veritabanında mevcut, eklenmedi.")

    # --- Yeni bir QuizQuestion üretip veritabanına kaydedelim ---
    quiz_data = generate_quiz_question(topic=TOPIC)
    
    if quiz_data:
        with Session(engine) as session:
            existing = session.exec(select(QuizQuestion).where(QuizQuestion.question_text == quiz_data["question_text"])).first()
            if not existing:
                db_quiz = QuizQuestion.model_validate(quiz_data)
                session.add(db_quiz)
                session.commit()
                print("\n✅ Yeni quiz sorusu veritabanına eklendi:")
                print(db_quiz.question_text)
            else:
                print("\n⚠️ Bu quiz sorusu zaten veritabanında mevcut, eklenmedi.")