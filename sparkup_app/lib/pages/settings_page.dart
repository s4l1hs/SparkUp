import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../locale_provider.dart';
import '../main.dart';
import '../providers/user_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _isLoadingProfile = true;
  bool _isSavingLanguage = false;
  bool _isSavingNotifications = false;
  
  bool _notificationsEnabled = true;
  String _currentLanguageCode = 'en';
  String? _username; // changed: store username instead of email
  int _userScore = 0;
  
  late final AnimationController _animationController;

  final Map<String, String> _supportedLanguages = {
    'en': 'English', 'tr': 'Türkçe', 'de': 'Deutsch', 'fr': 'Français', 'es': 'Español',
    'it': 'Italiano', 'ru': 'Русский', 'zh': '中文 (简体)', 'hi': 'हिन्दी', 'ja': '日本語', 'ar': 'العربية',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
      _animationController.forward(); 
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _getIdToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception("User not logged in");

      final uri = Uri.parse("$backendBaseUrl/user/profile/");
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200 && mounted) {
        final profile = jsonDecode(response.body);
        // changed: prefer Firebase displayName, then backend username, then email
        final firebaseName = FirebaseAuth.instance.currentUser?.displayName;
        final backendUsername = (profile['username'] as String?) ?? '';
        final fallbackEmail = (profile['email'] as String?) ?? 'Anonymous';
        setState(() {
          _currentLanguageCode = profile['language_code'] ?? 'en';
          _username = (firebaseName != null && firebaseName.isNotEmpty) ? firebaseName : (backendUsername.isNotEmpty ? backendUsername : fallbackEmail);
          _userScore = profile['score'] ?? 0;
          _notificationsEnabled = profile['notifications_enabled'] ?? true;
        });
        Provider.of<LocaleProvider>(context, listen: false).setLocale(_currentLanguageCode);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Failed to load user profile: $e");
      if(mounted) _showErrorSnackBar("Failed to load user profile");
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveLanguage(String langCode) async {
    if (_isSavingLanguage) return;
    setState(() => _isSavingLanguage = true);
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception("User not logged in");
      
      final uri = Uri.parse("$backendBaseUrl/user/language/?language_code=$langCode");
      final response = await http.put(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        Provider.of<LocaleProvider>(context, listen: false).setLocale(langCode);
        setState(() => _currentLanguageCode = langCode);
      } else {
        throw Exception('Failed to save language');
      }
    } catch (e) {
      print("Failed to save language: $e");
       if(mounted) _showErrorSnackBar("Failed to save language");
    } finally {
      if(mounted) setState(() => _isSavingLanguage = false);
    }
  }

  Future<void> _saveNotificationSetting(bool isEnabled) async {
    if(_isSavingNotifications) return;
    setState(() {
       _notificationsEnabled = isEnabled;
       _isSavingNotifications = true;
    });
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception("User not logged in");
      
      final uri = Uri.parse("$backendBaseUrl/user/notifications/");
      final response = await http.put(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'enabled': isEnabled}),
      );
      if (response.statusCode != 200) throw Exception('Failed to save setting');
    } catch (e) {
      print("Failed to save notification setting: $e");
      if (mounted) {
        _showErrorSnackBar("Failed to save notification setting");
        setState(() => _notificationsEnabled = !isEnabled);
      }
    } finally {
       if(mounted) setState(() => _isSavingNotifications = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }
  
  void _showSignOutConfirmation() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(localizations.signOut), content: Text(localizations.signOutConfirmation), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(localizations.cancel)), TextButton(onPressed: () async { Navigator.of(ctx).pop(); await FirebaseAuth.instance.signOut(); await GoogleSignIn().signOut(); }, child: Text(localizations.signOut, style: TextStyle(color: Theme.of(context).colorScheme.error)))]));
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settings), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
        children: [
          _AnimatedSettingsItem(index: 0, controller: _animationController, child: _buildProfileCard(theme)),
          SizedBox(height: 30.h),
          _AnimatedSettingsItem(index: 1, controller: _animationController, child: _buildSectionHeader(localizations.general, theme)),
          _AnimatedSettingsItem(index: 2, controller: _animationController, child: _buildSettingsCard(children: [ _buildLanguageTile(localizations, theme), const Divider(color: Colors.white12, height: 1, indent: 72), _buildNotificationsTile(localizations, theme) ])),
          SizedBox(height: 30.h),
          _AnimatedSettingsItem(index: 3, controller: _animationController, child: _buildSectionHeader(localizations.account, theme)),
          _AnimatedSettingsItem(index: 4, controller: _animationController, child: _buildSettingsCard(children: [ _buildSignOutTile(localizations, theme) ])),
          SizedBox(height: 40.h),
          FadeTransition(opacity: _animationController, child: Center(child: Text('Spark Up v1.0.0', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.sp)))),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    final userProvider = Provider.of<UserProvider?>(context);
    final providerProfile = userProvider?.profile;
    final displayName = (providerProfile as dynamic)?.username ?? _username;
    final displayScore = (providerProfile as dynamic)?.score ?? _userScore;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: _isLoadingProfile
          ? Center(heightFactor: 1.5, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
          : Row(
              children: [
                // changed: profile picture is first letter of username
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: theme.colorScheme.tertiary,
                  child: Text(
                    (displayName != null && displayName.isNotEmpty) ? displayName[0].toUpperCase() : 'A',
                    style: TextStyle(fontSize: 24.sp, color: theme.colorScheme.onTertiary, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // changed: show username instead of email
                  Text(displayName ?? "Anonymous", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4.h),
                  Row(children: [ Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 16.sp), SizedBox(width: 4.w), Text("$displayScore ${AppLocalizations.of(context)!.points}", style: TextStyle(color: theme.colorScheme.secondary, fontSize: 14.sp, fontWeight: FontWeight.w600))])
                ])),
              ],
            ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) { return Card(elevation: 0, color: Theme.of(context).colorScheme.surface.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), child: Column(children: children)); }
  Widget _buildSectionHeader(String title, ThemeData theme) { return Padding(padding: EdgeInsets.only(bottom: 12.h, left: 12.w, top: 10.h), child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 1.2))); }
  Widget _buildLanguageTile(AppLocalizations localizations, ThemeData theme) { return ListTile(leading: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.language_outlined, color: theme.colorScheme.primary)), title: Text(localizations.applicationLanguage), subtitle: Text(_supportedLanguages[_currentLanguageCode] ?? 'English'), trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16), onTap: () => _showLanguageBottomSheet(localizations, theme)); }
  Widget _buildNotificationsTile(AppLocalizations localizations, ThemeData theme) { return SwitchListTile(secondary: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary)), title: Text(localizations.notifications), subtitle: Text(localizations.forAllAlarms), value: _notificationsEnabled, activeColor: theme.colorScheme.secondary, onChanged: _isSavingNotifications ? null : (value) => _saveNotificationSetting(value)); }
  Widget _buildSignOutTile(AppLocalizations localizations, ThemeData theme) { return ListTile(leading: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.logout, color: theme.colorScheme.secondary)), title: Text(localizations.signOut, style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)), onTap: () => _showSignOutConfirmation()); }

  void _showLanguageBottomSheet(AppLocalizations localizations, ThemeData theme) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) { return StatefulBuilder(builder: (BuildContext context, StateSetter setModalState) { return Container(padding: EdgeInsets.symmetric(horizontal: 16.w), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))), child: Column(mainAxisSize: MainAxisSize.min, children: [ Container(width: 40.w, height: 4.h, margin: EdgeInsets.symmetric(vertical: 12.h), decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2.r))), Text(localizations.applicationLanguage, style: theme.textTheme.titleLarge), SizedBox(height: 10.h), const Divider(color: Colors.white24), LimitedBox(maxHeight: 300.h, child: ListView(shrinkWrap: true, children: _supportedLanguages.entries.map((entry) { return RadioListTile<String>(title: Text(entry.value, style: TextStyle(color: _currentLanguageCode == entry.key ? theme.colorScheme.primary : Colors.white)), value: entry.key, groupValue: _currentLanguageCode, activeColor: theme.colorScheme.primary, onChanged: (value) { if(value != null) { Navigator.pop(context); _saveLanguage(value); }}); }).toList())), SizedBox(height: 20.h)]));});});
  }
}

class _AnimatedSettingsItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedSettingsItem({required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(index * 0.1, min((index + 4) * 0.1, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}