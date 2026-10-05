import os
import re

d = 'lib'
for r, ds, fs in os.walk(d):
    for f in fs:
        if f.endswith('.dart'):
            filepath = os.path.join(r, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
                
            # Regex to remove const before Text if it contains AppLocalizations
            # E.g., `const Text(AppLocalizations` -> `Text(AppLocalizations`
            content = re.sub(r'const\s+(Text\s*\(\s*AppLocalizations)', r'\1', content)
            
            # Remove const from other widgets containing AppLocalizations (basic heuristic)
            content = re.sub(r'const\s+([A-Za-z0-9_]+\s*\([^)]*AppLocalizations)', r'\1', content)

            # Sometimes the const is on a parent array:
            # const [ Text(AppLocalizations... ) ]
            # This is harder to regex accurately, we'll try a basic pass
            content = re.sub(r'const\s+(\[.*?AppLocalizations.*\])', r'\1', content, flags=re.DOTALL)
            
            with open(filepath, 'w', encoding='utf-8') as file:
                file.write(content)
