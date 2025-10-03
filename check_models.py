# check_models.py
import os
from dotenv import load_dotenv
import google.generativeai as genai

# .env dosyasından API anahtarını yükle
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY .env dosyasında bulunamadı!")

try:
    genai.configure(api_key=GEMINI_API_KEY)

    print("\n" + "="*40)
    print("Hesabınız İçin Kullanılabilir Modeller:")
    print("="*40)

    # Kullanılabilir modelleri listele
    for model in genai.list_models():
      # Sadece metin üretebilen ('generateContent') modelleri gösterelim
      if 'generateContent' in model.supported_generation_methods:
        print(model.name)
    
    print("="*40)
    print("\nYukarıdaki listeden metin üretimi için uygun olan birini seçin (genellikle 'pro' içeren).")

except Exception as e:
    print(f"\nAPI'ye bağlanırken bir hata oluştu: {e}")
    print("Lütfen GEMINI_API_KEY'inizin doğru olduğundan ve internet bağlantınızdan emin olun.")