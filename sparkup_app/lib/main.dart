import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'providers/user_provider.dart'; // USER PROVIDER IMPORT EDİLDİ
import 'auth_gate.dart';

String backendBaseUrl = "http://127.0.0.1:8000";

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Background message received: ${message.messageId}');
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ana Renk Paleti
    final Color primaryColor = Colors.cyanAccent.shade400; // Ana Vurgu Rengi
    final Color secondaryColor = Colors.deepOrangeAccent.shade400; // İkincil Enerji Rengi
    
    // 1. ÜÇÜNCÜ RENK TANIMLAMASI
    final Color tertiaryColor = Colors.purpleAccent.shade200; // Üçüncül Vurgu Rengi (Mor/Eflatun)

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
            scaffoldBackgroundColor: Colors.black,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              onPrimary: Colors.black,
              secondary: secondaryColor,
              onSecondary: Colors.black,
              
              // 2. ÜÇÜNCÜ RENKLERİ COLOR SCHEME'E EKLEME
              tertiary: tertiaryColor,
              onTertiary: Colors.black,

              surface: const Color(0xFF151515),
              background: Colors.black,
              onBackground: Colors.white,
              error: Colors.redAccent.shade400,
              onError: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1A1A1A),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              shadowColor: Colors.black.withOpacity(0.4),
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
                  fontWeight: FontWeight.bold,
                ),
                shadowColor: Colors.black.withOpacity(0.8),
                elevation: 8,
              ),
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontSize: 16.sp),
              bodyMedium: TextStyle(color: Colors.white, fontSize: 14.sp),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16.sp),
              titleLarge: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20.sp),
            ),
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