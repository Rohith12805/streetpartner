import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\android\\app\\src\\main\\kotlin\\com\\example\\streetpartner\\SosForegroundService.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """    private fun updateNotification(secondsLeft: Int, isDeviation: Boolean = false) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildNotification(secondsLeft, isDeviation))
    }"""

replacement = """    private fun updateNotification(secondsLeft: Int, isDeviation: Boolean = false) {
        startForeground(NOTIFICATION_ID, buildNotification(secondsLeft, isDeviation))
    }"""

content = content.replace(target, replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed updateNotification to use startForeground")
