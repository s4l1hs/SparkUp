import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'auth_gate.dart';

// Lokal backend adresi
final String backendBaseUrl = "http://127.0.0.1:8000"; 

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

  runApp(
    ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Yeni Vurgu Rengi: Canlı Mavi/Cyan
    final Color primaryColor = Colors.cyanAccent.shade400; 
    // İkincil Enerji Rengi: Kırmızımsı Turuncu
    final Color secondaryColor = Colors.deepOrangeAccent.shade400; 

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
          
          // --- SPARK UP YENİ TEMASI (Siyah & Mavi/Turuncu) ---
          theme: ThemeData(
            // Arka plan rengi
            scaffoldBackgroundColor: Colors.black, 
            
            // Ana renk paleti
            colorScheme: ColorScheme.dark(
              primary: primaryColor, // Vurgu Rengi (Cyan)
              onPrimary: Colors.black,
              secondary: secondaryColor, // İkincil Rengi (Turuncu)
              surface: const Color(0xFF151515), // Kartlar ve konteynerler için koyu yüzey
              background: Colors.black,
              onBackground: Colors.white,
            ),
            
            // App Bar Teması
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
            
            // Kart Teması
            cardTheme: CardThemeData( 
              color: const Color(0xFF1A1A1A), // Yüzey renginden biraz daha koyu
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              shadowColor: Colors.black.withOpacity(0.4),
              margin: EdgeInsets.zero,
            ),
            
            // Giriş Alanları Teması
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1A1A1A), // Giriş alanı arka planı
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
                borderSide: BorderSide(color: primaryColor, width: 2.w), // Vurgu rengi
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16.sp),
              labelStyle: TextStyle(color: primaryColor, fontSize: 16.sp),
            ),
            
            // Buton Teması
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, // Vurgu rengi
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
            
            // Text Teması
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontSize: 16.sp),
              bodyMedium: TextStyle(color: Colors.white, fontSize: 14.sp),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16.sp),
              titleLarge: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20.sp), // Vurgu rengi
            ),
            
            // Bottom Nav Bar Teması
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF1A1A1A),
              selectedItemColor: primaryColor, // Vurgu rengi
              unselectedItemColor: Colors.grey.shade600,
              elevation: 10,
            )

          ),
          home: child,
        );
      },
      child: const AuthGate(),
    );
  }
}