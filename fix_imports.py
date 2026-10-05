import os
d = 'lib'
for r, ds, fs in os.walk(d):
    for f in fs:
        if f.endswith('.dart'):
            filepath = os.path.join(r, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            if 'package:flutter_gen/gen_l10n/app_localizations.dart' in content:
                content = content.replace('package:flutter_gen/gen_l10n/app_localizations.dart', 'package:streetpartner/l10n/app_localizations.dart')
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(content)
