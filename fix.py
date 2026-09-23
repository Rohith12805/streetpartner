import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\screens\\home_dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Dart doesn't like escaped single quotes inside interpolation in a single-quoted string.
# We'll replace \'unknown\' with "unknown"
content = content.replace("\\'unknown\\'", '"unknown"')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
