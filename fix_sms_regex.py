import sys
import re

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\screens\\home_dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r"(\'unknown\\\'\}\')\s*(userId: FirebaseAuth)",
    r"\1,\n                        \2",
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
