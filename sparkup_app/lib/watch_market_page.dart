import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';
import 'main.dart'; 

class WatchMarketPage extends StatefulWidget {
  const WatchMarketPage({super.key});
  @override
  State<WatchMarketPage> createState() => _WatchMarketPageState();
}

class _WatchMarketPageState extends State<WatchMarketPage> with SingleTickerProviderStateMixin {
  Map<String, List<Map<String, dynamic>>> marketData = {
    "BIST": [], "NASDAQ": [], "CRYPTO": [], "METALS": [],
  };
  bool loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: marketData.keys.length, vsync: this);

    Future.microtask(() {
      if (mounted) {
        fetchAllDataEfficiently();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

// watch_market_page.dart içinde _WatchMarketPageState sınıfı

Future<void> fetchAllDataEfficiently() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context)!;
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    
    // **KRİTİK KONTROL**: Backend'iniz artık UID'yi zorunlu kılıyor.
    if (userUid == null) {
        // Eğer kullanıcı girişi yapılmamışsa, API'yi çağırmadan No Data Found göster.
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.pleaseSignInFirst)));
            setState(() => loading = false);
        }
        // Boş bir veri setiyle geri dönmek yerine, burada hata vermeden durmak en sağlıklısı.
        return; 
    }
    
    // API URL'sini hazırla (user_uid zorunlu olduğu için direkt eklenir)
    String apiUrl = "$backendBaseUrl/prices?user_uid=$userUid";
    
    // Yükleniyor durumunu güncelle
    if (!loading) { 
      setState(() => loading = true);
    }

    marketData.forEach((key, value) => value.clear());

    try {
      // GÜNCELLENMİŞ API İSTEĞİ
      final res = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        // ... (Veri işleme kısmı aynı kalır)
        if (!mounted) return;
        final List<dynamic> allData = jsonDecode(res.body);
        final newMarketData = Map<String, List<Map<String, dynamic>>>.from(marketData);

        for (var item in allData) {
          final market = item['market'];
          if (market != null && newMarketData.containsKey(market)) {
            newMarketData[market]?.add(item);
          }
        }
        
        if (mounted) {
          setState(() {
            marketData = newMarketData;
            loading = false; 
          });
        }
      } else {
        throw Exception('Failed to load market data with status code: ${res.statusCode}');
      }
    } catch (e) {
      print("Error fetching market data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.noMarketDataFound)));
        setState(() => loading = false);
      }
    }
}

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          localizations.watchMarketChart,
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
          tabs: marketData.keys.map((market) {
            String tabText = market;
            if (market == "CRYPTO") tabText = localizations.crypto;
            if (market == "METALS") tabText = localizations.metals;
            return Tab(text: tabText);
          }).toList(),
        ),
      ),
      backgroundColor: Colors.black,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabController,
              children: marketData.keys.map((market) {
                final data = marketData[market] ?? [];
                final filteredData = data.where((item) => item['price'] != null && item['price'] > 0).toList();
                return _buildMarketList(market, filteredData);
              }).toList(),
            ),
    );
  }

  Widget _buildMarketList(String market, List<Map<String, dynamic>> data) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Expanded(flex: 6, child: Text(localizations.symbol, style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
              Expanded(flex: 10, child: Text(localizations.name, style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
              Expanded(flex: 7, child: Align(alignment: Alignment.centerRight, child: Text(localizations.price, style: TextStyle(color: Colors.grey, fontSize: 12.sp)))),
            ],
          ),
        ),
        const Divider(color: Color(0xFF222222), height: 1),
        Expanded(
          child: data.isEmpty
              ? Center(child: Text(localizations.noDataFound, style: TextStyle(color: Colors.grey, fontSize: 16.sp)))
              : RefreshIndicator(
                  onRefresh: fetchAllDataEfficiently,
                  child: ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (context, index) => const Divider(color: Color(0xFF222222), height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = data[index];
                      final priceValue = item['price'] as num;
                      
                      String currencySymbol;
                      
                      // 1. Dili al
                      final localeCode = Localizations.localeOf(context).languageCode;
                      
                      if (market == "BIST") {
                        currencySymbol = "₺"; 
                      } else if (market == "METALS") {
                        switch (localeCode.toLowerCase()) {
                            case 'tr': currencySymbol = '₺'; break;
                            case 'de':
                            case 'fr':
                            case 'it':
                            case 'es': currencySymbol = '€'; break; // Euro for European languages
                            case 'ru': currencySymbol = '₽'; break; // Russian Ruble
                            case 'ja': currencySymbol = '¥'; break; // Japanese Yen
                            case 'zh': currencySymbol = '¥'; break; // Chinese Yuan
                            case 'hi': currencySymbol = '₹'; break; // Indian Rupi
                            case 'ar': currencySymbol = '﷼'; break; // Riyal (Arabic)
                            default: currencySymbol = '\$'; break; // For others USD
                        }
                      } else {
                        // NASDAQ and CRYPTO USD
                        currencySymbol = "\$"; 
                      }
                      
                      String displayPrice = "${priceValue.toStringAsFixed(2)}$currencySymbol";
                      String displayName;

                      if (market == "METALS") {
                          final metalName = item['symbol']?.toString() ?? '';
                          String localizedMetalName = metalName; 
                          
                          if (metalName == "Altın") {
                              localizedMetalName = AppLocalizations.of(context)!.metalGold;
                          } else if (metalName == "Gümüş") {
                              localizedMetalName = AppLocalizations.of(context)!.metalSilver;
                          } else if (metalName == "Bakır") {
                              localizedMetalName = AppLocalizations.of(context)!.metalCopper;
                          }

                          displayName = "${AppLocalizations.of(context)!.gram} $localizedMetalName";
                      }else {
                          displayName = item['name'] ?? item['symbol'] ?? '';
                      }

                      String displaySymbol = item['symbol'] ?? '';
                      if (market == "CRYPTO" && displaySymbol.endsWith('USDT')) {
                        displaySymbol = displaySymbol.substring(0, displaySymbol.length - 4); // Cut 4 character (USDT)
                      }else if (market == "METALS") {
                          if (displaySymbol == "Altın") {
                              displaySymbol = AppLocalizations.of(context)!.metalGold;
                          } else if (displaySymbol == "Gümüş") {
                              displaySymbol = AppLocalizations.of(context)!.metalSilver;
                          } else if (displaySymbol == "Bakır") {
                              displaySymbol = AppLocalizations.of(context)!.metalCopper;
                          }
                      }
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        child: Row(
                          children: [
                            Expanded(flex: 6, child: Text(displaySymbol, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp))),
                            Expanded(flex: 10, child: Text(displayName, style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 7, child: Align(alignment: Alignment.centerRight, child: Text(displayPrice, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14.sp, letterSpacing: 0.5)))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}