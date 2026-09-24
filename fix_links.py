import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\screens\\home_dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "final locationLink = 'https://streetpartner.web.app/?session=';",
    "final locationLink = 'https://streetpartner.web.app/?session=$userId';"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

file_path2 = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\services\\admin_database_service.dart'
with open(file_path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace(
    "'liveLocationLink': 'https://streetpartner.web.app/?session=',",
    "'liveLocationLink': 'https://streetpartner.web.app/?session=$userId',"
)

with open(file_path2, 'w', encoding='utf-8') as f:
    f.write(content2)

print("Fixed location links")
