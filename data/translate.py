import json
import time
import os
from deep_translator import GoogleTranslator

# Konfigürasyon
INPUT_FILE = 'manual_quiz.json'
OUTPUT_FILE = 'manual_quiz_FINAL_HINDI.json'
TARGET_LANG = 'hi'
SOURCE_LANG = 'en'

def deep_force_translate(obj, translator):
    """
    JSON yapısında özyinelemeli (recursive) olarak gezer.
    Hem tekil metinleri hem de liste halindeki şıkları işler.
    """
    if isinstance(obj, dict):
        if 'en' in obj and 'hi' in obj:
            source_text = obj['en']
            
            if source_text:
                try:
                    # DURUM 1: Eğer veri bir METİN ise (Soru metni gibi)
                    if isinstance(source_text, str):
                        obj['hi'] = translator.translate(source_text)
                        print(f"Metin Güncellendi: {source_text[:30]}...")
                        time.sleep(0.4)

                    # DURUM 2: Eğer veri bir LİSTE ise (Şıklar/Options gibi)
                    elif isinstance(source_text, list):
                        translated_list = []
                        for item in source_text:
                            if isinstance(item, str):
                                translated_list.append(translator.translate(item))
                                time.sleep(0.3) # Liste elemanları için kısa mola
                            else:
                                translated_list.append(item)
                        obj['hi'] = translated_list
                        print(f"Liste Güncellendi: {len(translated_list)} eleman çevrildi.")

                except Exception as e:
                    print(f"Çeviri hatası: {e}")
        
        # Derinlere inmeye devam et
        for key in obj:
            deep_force_translate(obj[key], translator)
            
    elif isinstance(obj, list):
        for item in obj:
            deep_force_translate(item, translator)

def main():
    if not os.path.exists(INPUT_FILE):
        print(f"Hata: {INPUT_FILE} bulunamadı!")
        return

    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    translator = GoogleTranslator(source=SOURCE_LANG, target=TARGET_LANG)
    print("Tip-kontrollü derin tarama başlatıldı...")
    
    try:
        deep_force_translate(data, translator)
    except KeyboardInterrupt:
        print("\nİşlem durduruldu. Kaydediliyor...")
    finally:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        print(f"\nİşlem bitti! Çıktı: '{OUTPUT_FILE}'")

if __name__ == "__main__":
    main()