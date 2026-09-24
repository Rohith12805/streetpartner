import sys

with open('lib/screens/home_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Inject _manualAlertTriggered variable
content = content.replace(
    'bool _isLiveLocationActive = false;',
    'bool _isLiveLocationActive = false;\n  bool _manualAlertTriggered = false;'
)

# 2. Modify timer subscription to respect _manualAlertTriggered
content = content.replace(
    '        if (tick > 0) {\n          _secondsLeft = tick;\n          if (!_isModalOpen) {\n            SosService.playSiren();',
    '        if (tick > 0) {\n          _secondsLeft = tick;\n          if (!_isModalOpen) {\n            if (!_manualAlertTriggered) { SosService.playSiren(); }'
)

content = content.replace(
    '        } else if (tick == 0) {\n          // Countdown finished, alert is dispatching\n          SosService.stopSiren();',
    '        } else if (tick == 0) {\n          _manualAlertTriggered = false;\n          // Countdown finished, alert is dispatching\n          SosService.stopSiren();'
)

content = content.replace(
    '        } else if (tick == -1) {\n          // Countdown cancelled\n          SosService.stopSiren();',
    '        } else if (tick == -1) {\n          _manualAlertTriggered = false;\n          // Countdown cancelled\n          SosService.stopSiren();'
)


# 3. Remove "I am safe" button from the banner
banner_old = '''          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sosRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Stop Live Location?'),
                    content: const Text('Are you sure you are safe and want to stop sharing your location?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _stopLiveLocation();
                        },
                        child: const Text('Stop Sharing', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('I am Safe - Stop Sharing'),
            ),
          ),'''

content = content.replace(banner_old, '')


# 4. Modify SosButton text and isActive param
sos_btn_old = '''          SosButton(
            isActive: false,
            isLoading: false,
            onPressed: _onSosPressed,
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Press to trigger a 10-second emergency countdown.\\nAlerts trusted contacts & sounds a siren.','''

sos_btn_new = '''          SosButton(
            isActive: _isLiveLocationActive,
            isLoading: false,
            onPressed: _onSosPressed,
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isLiveLocationActive 
                ? '🚨 SOS ALERT ACTIVE\\nPress again to cancel or stop sharing location.' 
                : 'Press to trigger a 10-second emergency countdown.\\nAlerts trusted contacts & sounds a siren.','''

content = content.replace(sos_btn_old, sos_btn_new)


# 5. Modify _onSosPressed
on_sos_old = '''  void _onSosPressed() {
    // Manually trigger the native foreground countdown
    SosService.triggerSosCountdown('''

on_sos_new = '''  void _onSosPressed() {
    if (_isLiveLocationActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Emergency?'),
          content: const Text('Are you sure you want to stop sharing your live location and cancel the SOS alert?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _stopLiveLocation();
              },
              child: const Text('Stop Sharing', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }
    
    _manualAlertTriggered = true;
    // Manually trigger the native foreground countdown
    SosService.triggerSosCountdown('''

content = content.replace(on_sos_old, on_sos_new)


with open('lib/screens/home_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
