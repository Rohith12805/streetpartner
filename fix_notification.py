import sys

file_path = 'C:\\Users\\rohit\\OneDrive\\Desktop\\streetpartner\\lib\\screens\\home_dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """        } else if (tick == -1) {
          // Countdown cancelled
          SosService.stopSiren();
          if (_isModalOpen) {"""

replacement = """        } else if (tick == -1) {
          // Countdown cancelled
          SosService.stopSiren();
          if (!_isBackgroundProtectionEnabled) {
              SosService.stopForegroundService();
          }
          if (_isModalOpen) {"""

content = content.replace(target, replacement)

target2 = """                  else
                    TextButton(
                      onPressed: () {
                        SosService.stopSosCountdown();
                        SosService.stopMonitoring();
                      },"""

replacement2 = """                  else
                    TextButton(
                      onPressed: () {
                        SosService.stopSosCountdown();
                        SosService.stopMonitoring();
                        if (!_isBackgroundProtectionEnabled) {
                            SosService.stopForegroundService();
                        }
                      },"""
content = content.replace(target2, replacement2)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Added stopForegroundService on cancel")
