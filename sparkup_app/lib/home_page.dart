import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'settings_page.dart';
import 'main.dart';
import 'watch_market_page.dart';
import 'locale_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _followedItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserAlarms();
    _loadUserSettings(); 
  }

  String _getLocalizedSymbolName(String symbol, AppLocalizations localizations) {
    switch (symbol.toLowerCase()) {
      case 'altın' || 'altin':
        return localizations.metalGold;
      case 'gümüş' || 'gumus':
        return localizations.metalSilver;
      case 'bakır' || 'bakir':
        return localizations.metalCopper;
      default:
        return symbol;
    }
  }

  String _getLocalizedMarketName(String market, AppLocalizations localizations) {
    switch (market) {
      case 'CRYPTO':
        return localizations.crypto; 
      case 'METALS':
        return localizations.metals; 
      default: 
        return market;
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final uri = Uri.parse("$backendBaseUrl/user/settings/$uid");
      final response = await http.get(uri).timeout(const Duration(seconds: 10)); 

      if (response.statusCode == 200 && mounted) {
        final settings = jsonDecode(response.body);
        final languageCode = settings['language_code'] ?? 'en';

        Provider.of<LocaleProvider>(context, listen: false).setLocale(languageCode);
      }
    } catch (e) {
      print("Failed to load user settings on Home Page: $e");
    }
  }

  Future<void> _fetchUserAlarms() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userUid = _auth.currentUser?.uid;
      if (userUid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final uri = Uri.parse("$backendBaseUrl/alerts?user_uid=$userUid");
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _followedItems = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print("Error fetching alerts: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createOrEditAlarm(String market, String symbol, double percentage, {int? editId}) async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    try {
      final userUid = _auth.currentUser?.uid;
      if (userUid == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.pleaseSignInFirst)));
        return;
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.couldNotGetNotificationToken)));
        return;
      }

      final exists = _followedItems.any((alarm) {
        if (editId != null && alarm['id'] == editId) return false;
        String alarmSymbol = alarm['symbol'];
        String checkSymbol = symbol;
        if (alarm['market'] == 'CRYPTO') {
          if (alarmSymbol.endsWith("USDT")) alarmSymbol = alarmSymbol.substring(0, alarmSymbol.length - 4);
          if (checkSymbol.endsWith("USDT")) checkSymbol = checkSymbol.substring(0, checkSymbol.length - 4);
        }
        return alarm['market'] == market && alarmSymbol.toUpperCase() == checkSymbol.toUpperCase();
      });

      if (exists) {
        String displaySymbol = symbol;
        if (market == 'CRYPTO' && displaySymbol.endsWith('USDT')) {
          displaySymbol = displaySymbol.substring(0, displaySymbol.length - 1);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.redAccent.shade200, Colors.red.shade900]),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(localizations.alarmAlreadyExists(displaySymbol, market), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }

      final uri = editId != null ? Uri.parse("$backendBaseUrl/alerts/$editId") : Uri.parse("$backendBaseUrl/alerts");
      final body = jsonEncode({"market": market, "symbol": symbol, "percentage": percentage, "user_uid": userUid, "user_token": fcmToken});
      final res = editId != null
          ? await http.put(uri, headers: {"Content-Type": "application/json"}, body: body)
          : await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);

      if (res.statusCode == 200) {
        await _fetchUserAlarms();
      } else {
        print("Error creating/editing alarm: ${res.body}");
      }
    } catch (e) {
      print("Create/Edit alarm error: $e");
    }
  }

  Future<void> _deleteAlarm(int id) async {
    try {
      final userUid = _auth.currentUser?.uid;
      if (userUid == null) return;
      final uri = Uri.parse("$backendBaseUrl/alerts/$id?user_uid=$userUid");
      final response = await http.delete(uri);
      if (response.statusCode != 200) {
        _fetchUserAlarms(); // If deletion fails on backend, refresh UI to show it again
      }
    } catch (e) {
      print("Delete alarm error: $e");
      _fetchUserAlarms();
    }
  }

  void _openSetAlarmDialog(BuildContext context, AppLocalizations localizations) {
    String? selectedMarket;
    String? selectedSymbol;
    double? selectedPercentage;
    final markets = ['BIST', 'NASDAQ', 'CRYPTO', 'METALS'];
    final percentages = [1, 2, 5, 10];
    List<String> symbolsForMarket = [];
    bool _isLoadingSymbols = false;

    Future<List<String>> fetchSymbolsForMarket(String market) async {
      try {
        final uri = Uri.parse("$backendBaseUrl/symbols_with_name?market=$market");
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          return data.map((e) => e['symbol'].toString()).toList();
        }
      } catch (e) {
        print("Error fetching symbols for $market: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.marketSymbolsCouldNotBeLoaded(market))));
        }
      }
      return [];
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: StatefulBuilder(
            builder: (builderContext, setState) {
              return SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.grey.shade900, Colors.black87]),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(localizations.setAlarm, style: TextStyle(color: Colors.amber.shade400, fontSize: 24.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 24.h),
                      _buildDropdownContainer(
                        icon: Icons.store_mall_directory_outlined,
                        child: DropdownButton<String>(
                          dropdownColor: Colors.grey.shade800,
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: selectedMarket,
                          hint: Text(localizations.selectMarket, style: const TextStyle(color: Colors.grey)),
                          items: markets.map((m) {
                            return DropdownMenuItem(
                              value: m, 
                              child: Text(
                                _getLocalizedMarketName(m, localizations),
                                style: const TextStyle(color: Colors.white)
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() {
                              _isLoadingSymbols = true;
                              selectedMarket = value;
                              selectedSymbol = null;
                              symbolsForMarket = [];
                            });
                            final symbols = await fetchSymbolsForMarket(value);
                            setState(() {
                              symbolsForMarket = symbols;
                              _isLoadingSymbols = false;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 50.h,
                        child: _isLoadingSymbols
                            ? Center(child: CircularProgressIndicator(color: Colors.amber.shade600, strokeWidth: 2.5))
                            : (selectedMarket != null
                                ? _buildDropdownContainer(
                                    icon: Icons.analytics_outlined,
                                    child: DropdownButton<String>(
                                      dropdownColor: Colors.grey.shade800,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      hint: Text(localizations.selectSymbol, style: const TextStyle(color: Colors.grey)),
                                      value: symbolsForMarket.contains(selectedSymbol) ? selectedSymbol : null,
                                      items: symbolsForMarket.map((s) {
                                        final displayName = selectedMarket == 'METALS'? _getLocalizedSymbolName(s, localizations): s;
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(displayName, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(() => selectedSymbol = value),
                                    ),
                                  )
                                : const SizedBox()),
                      ),
                      SizedBox(height: 16.h),
                      _buildDropdownContainer(
                        icon: Icons.percent_rounded,
                        child: DropdownButton<double>(
                          dropdownColor: Colors.grey.shade800,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: Text(localizations.selectChangePercent, style: const TextStyle(color: Colors.grey)),
                          value: selectedPercentage,
                          items: percentages.map((p) => DropdownMenuItem(value: p.toDouble(), child: Text('$p%', style: const TextStyle(color: Colors.white)))).toList(),
                          onChanged: (value) => setState(() => selectedPercentage = value),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(localizations.cancel, style: const TextStyle(color: Colors.grey)),
                          ),
                          SizedBox(width: 12.w),
                          ElevatedButton(
                            onPressed: (selectedMarket != null && selectedSymbol != null && selectedPercentage != null)
                                ? () async {
                                    String formattedSymbol = selectedSymbol!;
                                    if (selectedMarket == 'CRYPTO') {
                                      formattedSymbol = "${selectedSymbol!.toUpperCase()}T";
                                    }else if (selectedMarket == 'METALS') {
                                      formattedSymbol = selectedSymbol!.toUpperCase();
                                    }
                                    Navigator.pop(dialogContext); // Close dialog before async operation
                                    await _createOrEditAlarm(selectedMarket!, formattedSymbol, selectedPercentage!);
                                  }
                                : null,
                            child: Text(localizations.setAlarm),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openEditAlarmDialog(BuildContext context, Map<String, dynamic> alert, AppLocalizations localizations) {
    String? selectedMarket = alert['market'];
    String? selectedSymbol = alert['symbol'];
    if (selectedMarket == 'CRYPTO' && selectedSymbol != null && selectedSymbol.endsWith('USDT')) {
      selectedSymbol = selectedSymbol.substring(0, selectedSymbol.length - 1);
    }
    
    double? selectedPercentage = alert['percentage']?.toDouble();

    final markets = ['BIST', 'NASDAQ', 'CRYPTO', 'METALS'];
    final percentages = [1, 2, 5, 10];
    List<String> symbolsForMarket = [];
    bool _isLoadingSymbols = false;

    Future<List<String>> _fetchSymbolsForMarket(String market) async {
      try {
        final uri = Uri.parse("$backendBaseUrl/symbols_with_name?market=$market");
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          return data.map((e) => e['symbol'].toString()).toList();
        }
      } catch (e) {
        print("Error fetching symbols for $market: $e");
      }
      return [];
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: StatefulBuilder(
            builder: (context, setState) {

              if (selectedMarket != null && symbolsForMarket.isEmpty && !_isLoadingSymbols) {
                setState(() => _isLoadingSymbols = true);
                _fetchSymbolsForMarket(selectedMarket!).then((symbols) {
                  setState(() {
                    symbolsForMarket = symbols;
                    _isLoadingSymbols = false;
                  });
                });
              }

              return SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade900, Colors.black87],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localizations.editAlarm,
                        style: TextStyle(
                          color: Colors.amber.shade400,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      
                      _buildDropdownContainer(
                        icon: Icons.store_mall_directory_outlined,
                        child: DropdownButton<String>(
                          dropdownColor: Colors.grey.shade800,
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: selectedMarket,
                          items: markets.map((m) {
                            return DropdownMenuItem(
                              value: m, 
                              child: Text(
                                _getLocalizedMarketName(m, localizations), 
                                style: const TextStyle(color: Colors.white)
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() {
                              _isLoadingSymbols = true;
                              selectedMarket = value;
                              selectedSymbol = null;
                              symbolsForMarket = [];
                            });
                            final symbols = await _fetchSymbolsForMarket(value);
                            setState(() {
                              symbolsForMarket = symbols;
                              _isLoadingSymbols = false;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 50.h,
                        child: _isLoadingSymbols
                            ? Center(child: CircularProgressIndicator(color: Colors.amber.shade600, strokeWidth: 2.5))
                            : _buildDropdownContainer(
                                icon: Icons.analytics_outlined,
                                child: DropdownButton<String>(
                                  dropdownColor: Colors.grey.shade800,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  value: symbolsForMarket.contains(selectedSymbol) ? selectedSymbol : null,
                                  hint: Text(localizations.selectSymbol, style: TextStyle(color: Colors.grey)),
                                  items: symbolsForMarket.map((s) {
                                    final displayName = selectedMarket == 'METALS' ? _getLocalizedSymbolName(s, localizations): s;
                                    return DropdownMenuItem(
                                      value: s, 
                                      child: Text(displayName, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => selectedSymbol = value),
                                ),
                              ),
                      ),
                      SizedBox(height: 16.h),
                      
                      _buildDropdownContainer(
                        icon: Icons.percent_rounded,
                        child: DropdownButton<double>(
                          dropdownColor: Colors.grey.shade800,
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: selectedPercentage,
                          hint: Text(localizations.selectChangePercent, style: TextStyle(color: Colors.grey)),
                          items: percentages.map((p) => DropdownMenuItem(value: p.toDouble(), child: Text('$p%', style: const TextStyle(color: Colors.white)))).toList(),
                          onChanged: (value) => setState(() => selectedPercentage = value),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(localizations.cancel, style: TextStyle(color: Colors.grey)),
                          ),
                          SizedBox(width: 12.w),
                          ElevatedButton(
                            onPressed: () async {
                              if (selectedMarket != null && selectedSymbol != null && selectedPercentage != null) {
                                String formattedSymbol = selectedSymbol!;
                                if (selectedMarket == 'CRYPTO') {
                                  formattedSymbol = "${selectedSymbol!.toUpperCase()}T";
                                }else if (selectedMarket == 'METALS') {
                                  formattedSymbol = selectedSymbol!.toUpperCase();
                                }
                                await _createOrEditAlarm(
                                  selectedMarket!,
                                  formattedSymbol,
                                  selectedPercentage!,
                                  editId: alert['id'],
                                );
                                Navigator.pop(context);
                              }
                            },
                            child: Text(localizations.save),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDropdownContainer({required IconData icon, required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.shade600, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<LocaleProvider>(context); 
    final user = _auth.currentUser;
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        title: Text(user?.displayName ?? localizations.marketWatcher, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22.sp)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.amber, size: 30.sp),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(localizations.followedAlarms, style: TextStyle(color: Colors.amber.shade400, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.grey, height: 24),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                        : _followedItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined, color: Colors.grey, size: 48.sp),
                                    SizedBox(height: 16.h),
                                    Text(localizations.noAlarmsYet, style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchUserAlarms,
                                child: ListView.builder(
                                  itemCount: _followedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _followedItems[index];
                                    String symbol = item['symbol'] ?? '';
                                    final String displaySymbol = item['market'] == 'METALS'? _getLocalizedSymbolName(symbol, localizations): (item['market'] == 'CRYPTO' && symbol.endsWith('USDT')? symbol.substring(0, symbol.length - 4): symbol);

                                    return Slidable(
                                      key: ValueKey(item['id']),
                                      endActionPane: ActionPane(
                                        motion: const DrawerMotion(),
                                        extentRatio: 0.25,
                                        children: [
                                          SlidableAction(
                                            onPressed: (context) {
                                              setState(() => _followedItems.removeAt(index));
                                              _deleteAlarm(item['id']);
                                            },
                                            backgroundColor: Colors.red.shade700,
                                            foregroundColor: Colors.white,
                                            icon: Icons.delete_forever,
                                            label: localizations.delete,
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.amber.withOpacity(0.1),
                                          child: Icon(Icons.notifications_active_outlined, color: Colors.amber.shade400),
                                        ),
                                        // Artık burada çevrilmiş veya düzenlenmiş displaySymbol'ı kullanıyoruz
                                        title: Text(displaySymbol, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                                        subtitle: Text(_getLocalizedMarketName(item['market'] ?? '', localizations), style: TextStyle(color: Colors.grey.shade400, fontSize: 12.sp)),
                                        trailing: Text('%${item['percentage']}', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)),
                                        onTap: () => _openEditAlarmDialog(context, item, localizations),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 55.h,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add_alert_rounded, size: 28.sp),
                label: Text(localizations.setAlarm, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
                onPressed: () => _openSetAlarmDialog(context, localizations),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 55.h,
              child: ElevatedButton.icon(
                icon: Icon(Icons.bar_chart_rounded, size: 28.sp),
                label: Text(localizations.watchMarkets, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchMarketPage())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}