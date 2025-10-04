# test_ollama.py
import requests
import json

# Ollama'nın çalıştığı yerel adres
url = "http://localhost:11434/api/generate"

# Yapay zekaya göndereceğimiz komut
prompt = "Türkiye'nin başkenti neresidir ve nüfusu ne kadardır?"

# Veri paketi
payload = {
    "model": "gemma:2b", # Çalıştırdığımız modelin adı
    "prompt": prompt,
    "stream": False # Cevabı tek parça halinde almak için
}

print("🧠 Kendi bilgisayarınızdaki yapay zekaya soruluyor...")

try:
    # Kendi bilgisayarımıza istek atıyoruz
    response = requests.post(url, json=payload)

    # Cevabı alıp ekrana yazdırıyoruz
    response_data = response.json()
    print("\n🤖 Yapay Zekanın Cevabı:")
    print(response_data['response'])

except requests.exceptions.ConnectionError:
    print("\nHATA: Ollama sunucusuna bağlanılamadı.")
    print("Lütfen terminalde 'ollama run gemma:2b' komutunun çalıştığından ve modelin hazır olduğundan emin olun.")