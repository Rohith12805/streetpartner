import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_dashboard_screen.dart';

import 'screens/registration_screen.dart';
import 'screens/profile_management_screen.dart';
import 'screens/fencing_hub_screen.dart';
import 'screens/geofencing_screen.dart';
import 'screens/route_fencing_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/fake_call_generator_screen.dart';
import 'screens/area_safety_index_screen.dart';
import 'screens/nearby_emergency_services_screen.dart';
import 'screens/features_screen.dart';
import 'screens/emergency_numbers_screen.dart';
import 'services/fake_call_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

bool _firebaseInitialized = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FakeCallService for local notification & scheduling
  try {
    await FakeCallService.instance.initialize();
    FakeCallService.instance.navigatorKey = navigatorKey;
  } catch (e) {
    debugPrint('FakeCallService init error: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Lock to portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use edge-to-edge system UI with transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const SheildApp());
}

class SheildApp extends StatelessWidget {
  const SheildApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_firebaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)?.firebaseConfigurationMissing ?? 'Firebase Configuration Missing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'It looks like Firebase has not been configured for this project yet. Please run the following command in your terminal:\n\nflutterfire configure\n\nAnd ensure google-services.json is added for Android.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Sheild',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          locale: locale,
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('te'),
            Locale('ta'),
            Locale('ml'),
            Locale('kn'),
          ],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: '/',

      onGenerateRoute: (settings) {
        final Map<String, WidgetBuilder> routes = {
          '/': (ctx) => const AuthWrapper(),
          '/onboarding': (ctx) => const OnboardingScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/registration': (ctx) => const RegistrationScreen(),

          '/home': (ctx) => const HomeDashboardScreen(),
          '/dashboard': (ctx) => const HomeDashboardScreen(),
          '/features': (ctx) => const FeaturesScreen(),
          '/emergency-numbers': (ctx) => const EmergencyNumbersScreen(),
          '/profile': (ctx) => const ProfileManagementScreen(),
          '/fencing-hub': (ctx) => const FencingHubScreen(),
          '/geofencing': (ctx) => const GeofencingScreen(),
          '/route-fencing': (ctx) => const RouteFencingScreen(),
          '/fake-call': (ctx) => const FakeCallGeneratorScreen(),
            '/ai-assistant': (ctx) => const AiAssistantScreen(),
          '/safety-index': (ctx) => const AreaSafetyIndexScreen(),
          '/navigation': (ctx) => const NavigationScreen(),
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

            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnim = anim.drive(tween);

            return SlideTransition(position: offsetAnim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
      },
    );
  },
);
}
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                final data = docSnapshot.data!.data() as Map<String, dynamic>?;
                if (data?['isProfileComplete'] == true) {
                  return const HomeDashboardScreen();
                }
              }
              if (docSnapshot.hasError) {
                // If there's a temporary network or Firestore error, don't kick logged-in user to registration
                return const HomeDashboardScreen();
              }
              return const RegistrationScreen();
            },
          );
        }

        // Unauthenticated: show Onboarding welcome screen until user signs in
        return const OnboardingScreen();
      },
    );
  }
}
