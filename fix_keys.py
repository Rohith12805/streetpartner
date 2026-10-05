import os
import re
import json

LIB_DIR = "lib"
L10N_DIR = os.path.join(LIB_DIR, "l10n")
LANGUAGES = ['en', 'hi', 'te', 'ta', 'ml', 'kn']

# Find invalid keys in en
en_file = os.path.join(L10N_DIR, 'app_en.arb')
with open(en_file, 'r', encoding='utf-8') as f:
    en_data = json.load(f)

invalid_keys = []
for key in en_data.keys():
    if not key: continue
    if key[0].isdigit():
        invalid_keys.append(key)

if not invalid_keys:
    print("No invalid keys found.")
    exit(0)

# Map old to new
key_map = {k: f"text{k}" for k in invalid_keys}

# Update all ARB files
for lang in LANGUAGES:
    arb_file = os.path.join(L10N_DIR, f'app_{lang}.arb')
    if os.path.exists(arb_file):
        with open(arb_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        new_data = {}
        for k, v in data.items():
            if k in key_map:
                new_data[key_map[k]] = v
            else:
                new_data[k] = v
        with open(arb_file, 'w', encoding='utf-8') as f:
            json.dump(new_data, f, indent=2, ensure_ascii=False)

# Update all Dart files
for root, dirs, files in os.walk(LIB_DIR):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            original = content
            for old_k, new_k in key_map.items():
                content = content.replace(f"AppLocalizations.of(context)?.{old_k} ", f"AppLocalizations.of(context)?.{new_k} ")
                content = content.replace(f"AppLocalizations.of(context)?.{old_k}?", f"AppLocalizations.of(context)?.{new_k}?")
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Fixed keys in {filepath}")

print("Done fixing keys.")
