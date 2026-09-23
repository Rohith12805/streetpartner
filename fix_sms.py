import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\screens\\home_dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = "message: 'EMERGENCY SOS: $_userName needs immediate assistance!',"
replacement = "message: 'EMERGENCY SOS: $_userName needs immediate assistance! Live Location: https://streetpartner.web.app/?session=${FirebaseAuth.instance.currentUser?.uid ?? \\'unknown\\'}'"

content = content.replace(target, replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated SMS message.')
