import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\android\\app\\src\\main\\kotlin\\com\\example\\streetpartner\\SosForegroundService.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target1 = """        val fullMessage = "$sosMessage Live Location: https://streetpartner.web.app/?session=$userId\""""
replacement1 = """        val fullMessage = sosMessage"""
content = content.replace(target1, replacement1)

target2 = """            val smsManager: SmsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)"""
replacement2 = """            val smsManager: SmsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)"""
content = content.replace(target2, replacement2)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed SMS multipart and duplication")
