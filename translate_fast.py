import json
import os
import urllib.request
import urllib.parse
import time

L10N_DIR = os.path.join('lib', 'l10n')
LANGUAGES = {'hi': 'hi', 'te': 'te', 'ta': 'ta', 'ml': 'ml', 'kn': 'kn'}

with open(os.path.join(L10N_DIR, 'app_en.arb'), 'r', encoding='utf-8') as f:
    en_data = json.load(f)

def translate(text, target):
    url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=" + target + "&dt=t&q=" + urllib.parse.quote(text)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        response = urllib.request.urlopen(req)
        data = json.loads(response.read().decode('utf-8'))
        return "".join([x[0] for x in data[0]])
    except Exception as e:
        return text

for lang, code in LANGUAGES.items():
    filepath = os.path.join(L10N_DIR, f'app_{lang}.arb')
    with open(filepath, 'r', encoding='utf-8') as f:
        lang_data = json.load(f)
        
    updated = False
    for key, en_text in en_data.items():
        if key.startswith('@'): continue
        if key not in lang_data or lang_data[key] == en_text:
            res = translate(en_text, code)
            lang_data[key] = res
            updated = True
            time.sleep(0.1)
            
    if updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(lang_data, f, indent=2, ensure_ascii=False)
        print(f"Updated {lang}")

print("Done")
