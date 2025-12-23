import os
import json
from typing import Optional, Any, List, Dict
from dotenv import load_dotenv
from sqlmodel import Field, SQLModel, Session, create_engine, select

print("🌱 Manuel Veri Doldurma Script'i Başlatılıyor...")
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL .env dosyasında tanımlanmalıdır!")

engine = create_engine(DATABASE_URL, echo=False)

INFO_FILE = "data/manual_info.json"
QUIZ_FILE = "data/manual_quiz.json"
# Challenges removed from codebase; do not attempt to seed them.
CHALLENGE_FILE = "data/manual_challenges.json"


# Import required models from server.models. Challenges were removed from the
# codebase — only import DailyInfo and QuizQuestion. If these are missing,
# abort so we don't attempt to redefine models and cause table conflicts.
try:
    from server.models import DailyInfo, QuizQuestion
except ImportError as e:
    raise RuntimeError("server.models must define DailyInfo and QuizQuestion for seeding") from e

def create_db_and_tables(): 
    SQLModel.metadata.create_all(engine)

def load_json_data(file_path: str) -> List[Dict[str, Any]]:
    """Belirtilen JSON dosyasını okur."""
    if not os.path.exists(file_path):
        print(f"HATA: Veri dosyası bulunamadı: {file_path}. Lütfen dosyayı oluşturun.")
        return []
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def seed_database_manual():
    create_db_and_tables()
    print("Veritabanı tabloları kontrol edildi/oluşturuldu.")
    
    # Yeni bir 'data' klasörü oluşturun (Eğer yoksa)
    os.makedirs('data', exist_ok=True)
    
    # NOT: Bu script'i çalıştırmadan önce, 'data' klasörünün içine 
    # manual_info.json, manual_quiz.json ve manual_challenges.json dosyalarını 
    # yukarıdaki şablonlara uygun içerikle doldurmanız gerekir.

    with Session(engine) as session:
        
        # --- 1. Challenge'ları Doldurma ---
        # Challenges have been removed from the app; skip seeding them.
        print("ℹ️ Challenges are deprecated and will not be seeded.")
            
        # --- 2. Bilgileri (DailyInfo) Doldurma ---
        info_data = load_json_data(INFO_FILE)
        if info_data and not session.exec(select(DailyInfo)).first():
            print(f"\nℹ️ {len(info_data)} adet Daily Info yükleniyor...")
            for item in info_data:
                session.add(DailyInfo(
                    info_texts=json.dumps(item["info_texts"], ensure_ascii=False),
                    category=item["category"],
                    source=item.get("source")
                ))
            session.commit()
            print(f"✅ {len(info_data)} Daily Info eklendi.")
        else:
            print("☑️ Daily Info bilgileri zaten mevcut veya dosya boş.")

        # --- 3. Quiz Sorularını Doldurma ---
        quiz_data = load_json_data(QUIZ_FILE)
        if quiz_data and not session.exec(select(QuizQuestion)).first():
            print(f"\n❓ {len(quiz_data)} adet Quiz Sorusu yükleniyor...")
            for item in quiz_data:
                session.add(QuizQuestion(
                    question_texts=json.dumps(item["question_texts"], ensure_ascii=False),
                    options_texts=json.dumps(item["options_texts"], ensure_ascii=False),
                    correct_answer_index=item["correct_answer_index"],
                    category=item["category"]
                ))
            session.commit()
            print(f"✅ {len(quiz_data)} Quiz Sorusu eklendi.")
        else:
            print("☑️ Quiz Soruları zaten mevcut veya dosya boş.")

    print("\n🎉 Manuel veri doldurma işlemi tamamlandı!")

if __name__ == "__main__":
    seed_database_manual()