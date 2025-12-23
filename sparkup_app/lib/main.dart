import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'locale_provider.dart';
import 'providers/user_provider.dart'; // USER PROVIDER IMPORT EDİLDİ
import 'providers/analysis_provider.dart';
import 'auth_gate.dart';
import 'package:sparkup_app/utils/color_utils.dart';

// Use the current origin when running on Web (helps hosted web builds),
// otherwise default to local backend for development.
// Determine backend base URL for web and non-web builds.
// Priority:
// 1) Compile-time define: `--dart-define=BACKEND_BASE_URL=...`
// 2) If running on Web in non-debug (hosted), use `Uri.base.origin`.
// 3) If running via `flutter run` (dev server), fall back to local backend `http://127.0.0.1:8000`.
// 4) Non-web fallback: `http://127.0.0.1:8000`.
final String backendBaseUrl = (() {
  const fromDefine = String.fromEnvironment('BACKEND_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (!kIsWeb) return 'http://127.0.0.1:8000';
  try {
    final origin = Uri.base.origin;
    if (kDebugMode) {
      final parsed = Uri.parse(origin);
      // When running `flutter run -d chrome`, the origin will be localhost:<random-port>.
      // In that case use the local backend on port 8000 to reach FastAPI.
      if ((parsed.host == 'localhost' || parsed.host == '127.0.0.1') && parsed.port != 8000) {
        return 'http://127.0.0.1:8000';
      }
    }
    return origin;
  } catch (e) {
    return 'http://127.0.0.1:8000';
  }
})();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print('Background message received: ${message.messageId}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // KRİTİK DEĞİŞİKLİK: MultiProvider kullanılarak hem Locale hem de UserProvider eklendi
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()), // UserProvider EKLENDİ
        ChangeNotifierProvider(create: (context) => AnalysisProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  // Revamped color palette for a more vibrant, eye-catching UI
  const Color primaryColor = Color(0xFF00E5FF); // bright cyan
  const Color secondaryColor = Color(0xFF7C4DFF); // vibrant purple
  // tertiary kept for subtle surfaces
  const Color tertiaryColor = Color(0xFFB388FF);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final localeProvider = Provider.of<LocaleProvider>(context);

        return MaterialApp(
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => "Spark Up",
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            // make scaffold transparent so pages can show an app-level gradient background
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              onPrimary: Colors.black,
              secondary: secondaryColor,
              onSecondary: Colors.white,
              tertiary: tertiaryColor,
              onTertiary: Colors.white,

              surface: const Color(0xFF0F0F14),
              // 'background' and 'onBackground' are deprecated in newer
              // Flutter versions; prefer surface/onSurface.
              onSurface: Colors.white,
              error: Colors.redAccent.shade400,
              onError: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF12121A),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
              shadowColor: colorWithOpacity(Colors.black, 0.6),
              margin: EdgeInsets.zero,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade700, width: 1.w),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade800, width: 1.w),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: primaryColor, width: 2.w),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16.sp),
              labelStyle: TextStyle(color: primaryColor, fontSize: 16.sp),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 24.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
                shadowColor: colorWithOpacity(Colors.black, 0.8),
                elevation: 8,
              ),
            ),
            // Use a more expressive, friendly display font across the app
            // Poppins is clean and works well for UI headings and CTAs.
            textTheme: GoogleFonts.poppinsTextTheme(TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontSize: 16.sp, height: 1.35, fontWeight: FontWeight.w400),
              bodyMedium: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w400),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.sp),
              titleLarge: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 22.sp),
            )),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF1A1A1A),
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey.shade600,
              elevation: 10,
            ),
          ),
          home: child,
        );
      },
      child: const AuthGate(),
    );
  }
}