import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_dashboard_screen.dart';


import 'screens/profile_management_screen.dart';
import 'screens/geofencing_screen.dart';
import 'screens/fake_call_generator_screen.dart';
import 'screens/area_safety_index_screen.dart';
import 'screens/nearby_emergency_services_screen.dart';

import 'services/user_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persistent registered accounts & active session from SharedPreferences
  await UserState.instance.loadFromStorage();

  // Lock to portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use edge-to-edge system UI with transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(const SafeGuardApp());
}

class SafeGuardApp extends StatelessWidget {
  const SafeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard — Women Safety',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,

      initialRoute: UserState.instance.isLoggedIn ? '/home' : '/login',

      onGenerateRoute: (settings) {
        final Map<String, WidgetBuilder> routes = {
          '/login': (ctx) => const LoginScreen(),
          '/otp': (ctx) => const OtpVerificationScreen(),
          '/register': (ctx) => const RegistrationScreen(),


          '/home': (ctx) => const HomeDashboardScreen(),
          '/profile': (ctx) => const ProfileManagementScreen(),
          '/geofencing': (ctx) => const GeofencingScreen(),
          '/fake-call': (ctx) => const FakeCallGeneratorScreen(),
          '/safety-index': (ctx) => const AreaSafetyIndexScreen(),
          '/emergency-services': (ctx) => const NearbyEmergencyServicesScreen(),
        };

        final builder = routes[settings.name];
        if (builder == null) return null;

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (ctx, anim, secAnim) => builder(ctx),
          transitionsBuilder: (ctx, anim, secAnim, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            final offsetAnim = anim.drive(tween);

            return SlideTransition(position: offsetAnim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
      },
    );
  }
}

