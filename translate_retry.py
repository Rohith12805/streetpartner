import json
import os
import time
from deep_translator import GoogleTranslator

L10N_DIR = os.path.join('lib', 'l10n')

LANGUAGES = {
    'hi': 'hi',
    'te': 'te',
    'ta': 'ta',
    'ml': 'ml',
    'kn': 'kn'
}

with open(os.path.join(L10N_DIR, 'app_en.arb'), 'r', encoding='utf-8') as f:
    en_data = json.load(f)

for lang, code in LANGUAGES.items():
    filepath = os.path.join(L10N_DIR, f'app_{lang}.arb')
    with open(filepath, 'r', encoding='utf-8') as f:
        lang_data = json.load(f)
        
    translator = GoogleTranslator(source='en', target=code)
    
    updated = False
    for key, en_text in en_data.items():
        # If the text in lang is same as English, it means it failed or was copied
        # Except if the text is short like "OK" where it might be same, but let's translate anyway if it's identical
        if key.startswith('@'): continue
        
        # In Indian languages, it's very rare for the translation to be identically equal to English text
        if key not in lang_data or lang_data[key] == en_text:
            try:
                res = translator.translate(en_text)
                print(f"[{lang}] {key}: {en_text[:20]} -> {res[:20]}")
                lang_data[key] = res
                updated = True
                time.sleep(0.5)
            except Exception as e:
                print(f"[{lang}] Failed {key}: {e}")
                time.sleep(2)
                
    if updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(lang_data, f, indent=2, ensure_ascii=False)

print("Retry complete.")
