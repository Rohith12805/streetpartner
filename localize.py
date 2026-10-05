import os
import re
import json
import time
from deep_translator import GoogleTranslator

# Config
LIB_DIR = "lib"
L10N_DIR = os.path.join(LIB_DIR, "l10n")
LANGUAGES = {
    'en': 'en',
    'hi': 'hi',
    'te': 'te',
    'ta': 'ta',
    'ml': 'ml',
    'kn': 'kn'
}

# Regex for unlocalized strings
TEXT_WIDGET_PATTERN = re.compile(r"(const\s+)?Text\(\s*(['\"])([^'\$\\]+?)\2\s*([^)]*)\)")
# Regex for already localized strings from previous run
LOCALIZED_PATTERN = re.compile(r"AppLocalizations\.of\(context\)\?\.([a-zA-Z0-9_]+)\s*\?\?\s*(['\"])([^'\$\\]+?)\2")

translations = {lang: {} for lang in LANGUAGES}

en_file = os.path.join(L10N_DIR, 'app_en.arb')
if os.path.exists(en_file):
    with open(en_file, 'r', encoding='utf-8') as f:
        translations['en'] = json.load(f)

def generate_key(text):
    words = re.sub(r'[^a-zA-Z0-9 ]', '', text).strip().split()
    if not words:
        return "emptyKey"
    key = words[0].lower() + ''.join(word.capitalize() for word in words[1:])
    if len(key) > 30:
        key = key[:30]
    base_key = key
    counter = 1
    while base_key in translations['en'] and translations['en'][base_key] != text:
        base_key = f"{key}{counter}"
        counter += 1
    return base_key

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # First, find already localized ones to ensure they are in translations map
    for match in LOCALIZED_PATTERN.finditer(content):
        key = match.group(1)
        text = match.group(3).strip()
        if text and len(text) > 1:
            translations['en'][key] = text

    # Then find unlocalized ones
    matches = TEXT_WIDGET_PATTERN.finditer(content)
    replacements = []
    
    for match in matches:
        is_const = match.group(1)
        quote = match.group(2)
        text = match.group(3).strip()
        rest = match.group(4)
        
        if not text or len(text) < 2:
            continue
            
        key = generate_key(text)
        translations['en'][key] = text
        
        new_text = f"Text(AppLocalizations.of(context)?.{key} ?? {quote}{text}{quote}{rest})"
        replacements.append((match.start(), match.end(), new_text))
        
    if replacements:
        for start, end, new_text in reversed(replacements):
            content = content[:start] + new_text + content[end:]
            
        if "import 'package:flutter_gen/gen_l10n/app_localizations.dart';" not in content:
            import_match = list(re.finditer(r"^import\s+['\"].+?['\"];$", content, re.MULTILINE))
            if import_match:
                last_import = import_match[-1]
                content = content[:last_import.end()] + "\nimport 'package:flutter_gen/gen_l10n/app_localizations.dart';" + content[last_import.end():]
            else:
                content = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + content

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"Processed {filepath} - {len(replacements)} replacements")

for root, dirs, files in os.walk(LIB_DIR):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("Extracting done. Translating to other languages...")
items = list(translations['en'].items())

for lang, code in LANGUAGES.items():
    if lang == 'en':
        continue
        
    if not os.path.exists(os.path.join(L10N_DIR, f'app_{lang}.arb')):
        translations[lang] = {}
    else:
        with open(os.path.join(L10N_DIR, f'app_{lang}.arb'), 'r', encoding='utf-8') as f:
            translations[lang] = json.load(f)
            
    # Find missing keys
    missing_keys = [k for k in translations['en'] if k not in translations[lang]]
    
    # Translate in batches
    batch_size = 20
    for i in range(0, len(missing_keys), batch_size):
        batch_keys = missing_keys[i:i+batch_size]
        batch_texts = [translations['en'][k] for k in batch_keys]
        try:
            translator = GoogleTranslator(source='en', target=code)
            results = translator.translate_batch(batch_texts)
            for j, res in enumerate(results):
                translations[lang][batch_keys[j]] = res
            print(f"[{lang}] Translated batch of {len(batch_texts)} strings.")
            # Sleep to avoid rate limits
            time.sleep(1)
        except Exception as e:
            # Safe print
            print(f"Failed batch translate to {lang}")
            for j, k in enumerate(batch_keys):
                translations[lang][k] = batch_texts[j]

# Save ARB files
for lang, data in translations.items():
    with open(os.path.join(L10N_DIR, f'app_{lang}.arb'), 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

print("Localization complete.")
