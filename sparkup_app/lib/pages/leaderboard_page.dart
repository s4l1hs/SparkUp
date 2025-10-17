import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../models/leaderboard_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardPage extends StatefulWidget {
  final String idToken;
  const LeaderboardPage({super.key, required this.idToken});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  UserProvider? _observedUserProvider;

  // --- STATE'LER ---
  List<LeaderboardEntry> _leaderboardData = [];
  LeaderboardEntry? _currentUserEntry;
  bool _isLoading = true;
  // kept for potential future use:
  // Map<String, String> _allTopics = {};
  bool _hasError = false;
  
  // --- ANİMASYON CONTROLLER'LARI ---
  late final AnimationController _listAnimationController;
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(reverse: true);
    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topLeft, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomRight, end: Alignment.topLeft), weight: 1),
    ]).animate(_backgroundController);
    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topRight, end: Alignment.bottomLeft), weight: 1),
    ]).animate(_backgroundController);

    // Localizations ve context tam hazır olduktan sonra yükleme yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPageData();
      // register provider listener once after first frame
      _observedUserProvider = Provider.of<UserProvider?>(context, listen: false);
      _observedUserProvider?.addListener(_onUserProviderChanged);
    });
  }
  
  @override
  void dispose() {
    _observedUserProvider?.removeListener(_onUserProviderChanged);
    _listAnimationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // Called when UserProvider notifies listeners (score/profile change)
  void _onUserProviderChanged() {
    final prov = _observedUserProvider;
    if (prov == null || prov.profile == null) return;
    final providerScore = prov.profile!.score;

    // If we have a current user entry, update its score and resort ranks
    if (_currentUserEntry != null && providerScore != _currentUserEntry!.score) {
      setState(() {
        // update or insert
        final email = _currentUserEntry!.email;
        final username = _currentUserEntry!.username;
        int foundIndex = -1;
        for (var i = 0; i < _leaderboardData.length; i++) {
          final e = _leaderboardData[i];
          if ((email != null && e.email == email) || (username != null && e.username == username)) {
            foundIndex = i;
            break;
          }
        }
        if (foundIndex >= 0) {
          _leaderboardData[foundIndex] = LeaderboardEntry(rank: _leaderboardData[foundIndex].rank, email: _leaderboardData[foundIndex].email, username: _leaderboardData[foundIndex].username, score: providerScore);
        } else {
          // if not present, append entry using currentUserEntry meta
          _leaderboardData.add(LeaderboardEntry(rank: _currentUserEntry!.rank, email: _currentUserEntry!.email, username: _currentUserEntry!.username, score: providerScore));
        }

        // resort and recompute ranks
        _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
        for (var i = 0; i < _leaderboardData.length; i++) {
          final e = _leaderboardData[i];
          _leaderboardData[i] = LeaderboardEntry(rank: i + 1, email: e.email, username: e.username, score: e.score);
          // update _currentUserEntry when matching
          if ((_currentUserEntry!.email != null && _currentUserEntry!.email == e.email) || (_currentUserEntry!.username != null && _currentUserEntry!.username == e.username)) {
            _currentUserEntry = LeaderboardEntry(rank: i + 1, email: _currentUserEntry!.email, username: _currentUserEntry!.username, score: providerScore);
          }
        }
      });
    }
  }

  // --- API FONKSİYONLARI ---
  Future<void> _loadPageData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _listAnimationController.reset();

    try {
      // Only fetch leaderboard and current user rank now (topics removed)
      final leaderboardResp = await _api_apiSafe(() => _apiService.getLeaderboard(widget.idToken), const Duration(seconds: 8));
      final userRankResp = await _api_apiSafe(() => _apiService.getUserRank(widget.idToken), const Duration(seconds: 8));

      // Normalize leaderboard
      List<LeaderboardEntry> leaderboardParsed = [];
      if (leaderboardResp is List) {
        leaderboardParsed = leaderboardResp.map((e) {
          if (e is LeaderboardEntry) return e;
          return LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map));
        }).toList();
      }

      LeaderboardEntry? currentUserParsed;
      if (userRankResp is LeaderboardEntry) currentUserParsed = userRankResp;
      else if (userRankResp is Map) currentUserParsed = LeaderboardEntry.fromJson(Map<String, dynamic>.from(userRankResp));

      if (mounted) {
        setState(() {
          _leaderboardData = leaderboardParsed;
          _currentUserEntry = currentUserParsed;
        });
        _listAnimationController.forward();
      }

      // If backend didn't return current user entry, try to find it in leaderboard using Firebase user
      if (_currentUserEntry == null) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final fbEmail = fbUser.email;
          final fbName = fbUser.displayName;
          LeaderboardEntry? found;
          for (var e in leaderboardParsed) {
            if ((fbEmail != null && e.email == fbEmail) || (fbName != null && e.username == fbName)) {
              found = e;
              break;
            }
          }
          if (found != null && mounted) {
            setState(() => _currentUserEntry = found);
          }
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _hasError = true);
        final msg = AppLocalizations.of(context)?.errorCouldNotLoadData ?? "Could not load data (timeout)";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e, st) {
      debugPrint("Sayfa verileri yüklenirken hata: $e\n$st");
      if (mounted) {
        setState(() => _hasError = true);
        final msg = AppLocalizations.of(context)?.noDataAvailable;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg!), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // helper used earlier — keep as is
  Future<dynamic> _api_apiSafe(Future<dynamic> Function() fn, Duration timeout) {
    return fn().timeout(timeout, onTimeout: () => throw TimeoutException("API timeout"));
  }

  // Rütbe anahtarını puana göre hesaplar
  String _getRankKey(int score) {
    if (score >= 10000) {
        return 'rankMaster';
    } else if (score >= 5000) {
        return 'rankDiamond';
    } else if (score >= 2000) {
        return 'rankGold';
    } else if (score >= 1000) {
        return 'rankSilver';
    } else if (score >= 500) {
        return 'rankBronze';
    } else {
        return 'rankIron'; // İlk defa kayıt olanlar veya 500 altı için
    }
  }
  
  String _maskEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@${domain.substring(0,1)}...';
    return '${name.substring(0, 2)}***@${domain.substring(0,1)}...';
  }

  // new helper: display name prefers logged-in user's Firebase displayName,
  // then backend username, falls back to masked email
  String _displayName(LeaderboardEntry entry) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final fbName = fbUser?.displayName;
    final fbEmail = fbUser?.email;
    // If this leaderboard entry corresponds to the logged-in user (by email),
    // prefer the Firebase displayName (full name) as in settings_page.dart
    if (fbName != null && fbName.trim().isNotEmpty && fbEmail != null && entry.email != null && entry.email == fbEmail) {
      return fbName;
    }
    if (entry.username != null && entry.username!.trim().isNotEmpty) return entry.username!;
    return _maskEmail(entry.email);
  }
  
  // --- ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Listen to UserProvider and keep _currentUserEntry in sync when user's total score changes.
    final userProvider = Provider.of<UserProvider?>(context);
    final providerScore = userProvider?.profile?.score;
    if (providerScore != null) {
      // If we don't yet have currentUserEntry, try to find it in leaderboard (match by email or username)
      if (_currentUserEntry == null && _leaderboardData.isNotEmpty) {
        final fbUser = FirebaseAuth.instance.currentUser;
        LeaderboardEntry? found;
        for (var e in _leaderboardData) {
          if ((fbUser?.email != null && e.email == fbUser!.email) ||
              (fbUser?.displayName != null && e.username == fbUser!.displayName)) {
            found = e;
            break;
          }
        }
        if (found != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentUserEntry = found);
          });
        }
      }

      // If we have currentUserEntry but provider score differs, update both entry and leaderboard list
      else if (_currentUserEntry != null && providerScore != _currentUserEntry!.score) {
        // Update UI in next frame to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            // 1) update current user entry score
            _currentUserEntry = LeaderboardEntry(
              rank: _currentUserEntry!.rank,
              email: _currentUserEntry!.email,
              username: _currentUserEntry!.username,
              score: providerScore,
            );

            // 2) update (or insert) the user's entry in the leaderboard array
            int foundIndex = -1;
            for (var i = 0; i < _leaderboardData.length; i++) {
              final e = _leaderboardData[i];
              if ((e.email != null && e.email == _currentUserEntry!.email) ||
                  (e.username != null && e.username == _currentUserEntry!.username)) {
                foundIndex = i;
                break;
              }
            }
            if (foundIndex >= 0) {
              _leaderboardData[foundIndex] = LeaderboardEntry(rank: _leaderboardData[foundIndex].rank, email: _leaderboardData[foundIndex].email, username: _leaderboardData[foundIndex].username, score: providerScore);
            } else {
              // if not present, append — will be re-sorted below
              _leaderboardData.add(LeaderboardEntry(rank: _currentUserEntry!.rank, email: _currentUserEntry!.email, username: _currentUserEntry!.username, score: providerScore));
            }

            // 3) re-sort leaderboard by score desc and recompute ranks
            _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
            for (var i = 0; i < _leaderboardData.length; i++) {
              final e = _leaderboardData[i];
              _leaderboardData[i] = LeaderboardEntry(rank: i + 1, email: e.email, username: e.username, score: e.score);
              // also update currentUserEntry.rank if it matches
              if ((_currentUserEntry!.email != null && _currentUserEntry!.email == e.email) || (_currentUserEntry!.username != null && _currentUserEntry!.username == e.username)) {
                _currentUserEntry = LeaderboardEntry(rank: i + 1, email: _currentUserEntry!.email, username: _currentUserEntry!.username, score: providerScore);
              }
            }
          });
        });
      }
    }

    // Show only users after rank 10 (i.e. index >= 10). Ranks 4..10 are handled in the Top Players dashboard.
    final listDisplay = _leaderboardData.length > 10 ? _leaderboardData.sublist(10) : <LeaderboardEntry>[]; 

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CANLI ARKA PLAN
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(child: Align(alignment: _backgroundAnimation1.value, child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])))),
                  Positioned.fill(child: Align(alignment: _backgroundAnimation2.value, child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.tertiary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.tertiary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])))),
                ],
              );
            },
          ),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _hasError 
                  ? Center(child: Text("${localizations.error}: ${localizations.noDataAvailable}", style: TextStyle(color: theme.colorScheme.error)))
                  : _leaderboardData.isEmpty && _currentUserEntry == null
                    ? Center(child: Text(localizations.noDataAvailable, style: TextStyle(color: Colors.grey.shade400)))
                    : CustomScrollView(
                        slivers: [
                          if (_currentUserEntry != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.h, right: 16.w, left: 16.w),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 18.r,
                                            backgroundColor: theme.colorScheme.surfaceVariant,
                                            child: Text(
                                              (_displayName(_currentUserEntry!).isNotEmpty) ? _displayName(_currentUserEntry!)[0].toUpperCase() : 'A',
                                              style: TextStyle(fontSize: 16.sp, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ConstrainedBox(
                                                constraints: BoxConstraints(maxWidth: 140.w),
                                                child: Text(
                                                  _displayName(_currentUserEntry!),
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Row(children: [
                                                Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 14.sp),
                                                SizedBox(width: 6.w),
                                                Text("${_currentUserEntry!.score} ${localizations.points}", style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                                              ]),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(child: SizedBox(height: 8.h)),
                          
                          // Podyum Kısmı
                          if (_leaderboardData.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _AnimatedListItem(
                                index: 0, 
                                controller: _listAnimationController, 
                                child: _buildPodium(context, _leaderboardData.take(3).toList(), _leaderboardData.skip(3).toList()) 
                              ),
                            ),
                            
                          // Kullanıcının Kendi Sıralaması
                          if (_currentUserEntry != null)
                            SliverToBoxAdapter(
                              child: _AnimatedListItem(
                                index: 1,
                                controller: _listAnimationController,
                                child: _buildUserRankCard(theme, _currentUserEntry!, localizations),
                              ),
                            ),

                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = listDisplay[index];
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: _AnimatedListItem(
                                    index: index + 2, 
                                    controller: _listAnimationController,
                                    child: _buildLeaderboardTile(theme, entry),
                                  ),
                                );
                              },
                              childCount: listDisplay.length,
                            ),
                          ),
                          
                          // FloatingActionButton için alt boşluk
                          const SliverToBoxAdapter(child: SizedBox(height: 80)), 
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI BUILD METOTLARI ---
  
  // Kullanıcının kendi sıralamasını gösteren özel Card
  Widget _buildUserRankCard(ThemeData theme, LeaderboardEntry entry, AppLocalizations localizations) {
    // Rütbe anahtarını hesapla
    final String rankKey = _getRankKey(entry.score);
    
    // Yerelleştirilmiş rütbe adını al
    // AppLocalizations'dan dinamik olarak metin almak için reflection benzeri bir yaklaşım kullanıyoruz.
    // Bu, l10n tarafından oluşturulan 'tr' gibi bir metni 'rankTr' alan adına çevirir.
    String getLocalizedRank(String key) {
        switch(key) {
            case 'rankMaster': return localizations.rankMaster;
            case 'rankDiamond': return localizations.rankDiamond;
            case 'rankGold': return localizations.rankGold;
            case 'rankSilver': return localizations.rankSilver;
            case 'rankBronze': return localizations.rankBronze;
            case 'rankIron': return localizations.rankIron;
            default: return '';
        }
    }
    final String rankName = getLocalizedRank(rankKey);
    
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.7),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: theme.colorScheme.secondary, width: 2.w),
      ),
      child: ListTile(
        leading: Text("#${entry.rank}", style: TextStyle(fontSize: 16.sp, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
        title: Text(localizations.yourRank, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        // Rütbe Adı Eklendi
        subtitle: Row(
          children: [
            Text(_displayName(entry), style: TextStyle(color: Colors.grey.shade400)),
            SizedBox(width: 8.w),
            // Yerelleştirilmiş rütbe adını göster
            Text("($rankName)", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13.sp)),
          ],
        ),
        trailing: Row( mainAxisSize: MainAxisSize.min, children: [ Text(entry.score.toString(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)), SizedBox(width: 4.w), Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 18.sp)])
      ),
    );
  }
  
  // Liderlik tablosu List Tile 
  Widget _buildLeaderboardTile(ThemeData theme, LeaderboardEntry entry) {
      return Card(
        color: theme.cardTheme.color,
        margin: EdgeInsets.only(bottom: 12.h),
        child: ListTile(
          leading: Text("#${entry.rank}", style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          title: Text(_displayName(entry), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          trailing: Row( mainAxisSize: MainAxisSize.min, children: [ Text(entry.score.toString(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)), SizedBox(width: 4.w), Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 18.sp)])
        ),
      );
  }

  Widget _buildPodium(BuildContext context, List<LeaderboardEntry> topEntries, List<LeaderboardEntry> bestPlayers) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    // Ensure exactly 3 slots for podium display
    final List<LeaderboardEntry?> podium = List.generate(3, (index) => index < topEntries.length ? topEntries[index] : null);

    // Podium row (three columns)
    final podiumRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place (silver)
        Expanded(
          child: podium[1] != null
              ? _buildPodiumPlace(context, podium[1]!, theme, height: 120.h, color: const Color(0xFFC0C0C0))
              : _buildEmptyPodium(120.h, Colors.grey.shade700),
        ),
        // 1st place (gold) - trophy icon removed
        Expanded(
          child: podium[0] != null
              ? _buildPodiumPlace(context, podium[0]!, theme, height: 150.h, isFirst: true, color: const Color(0xFFFFD700))
              : _buildEmptyPodium(150.h, Colors.grey.shade700),
        ),
        // 3rd place (copper)
        Expanded(
          child: podium[2] != null
              ? _buildPodiumPlace(context, podium[2]!, theme, height: 100.h, color: const Color(0xFFB87333))
              : _buildEmptyPodium(100.h, Colors.grey.shade700),
        ),
      ],
    );

    // Best players table (fixed 4..10) full-width under podium — increased padding/size
    final dashboardCard = Card(
      color: theme.colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 13.w), // slightly larger padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.topPlayers,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Divider(color: Colors.white12, thickness: 1),
            SizedBox(height: 12.h),
            // fixed rows for ranks 4..10 (7 rows) with increased font sizes
            for (var i = 0; i < 7; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Builder(builder: (context) {
                  final entry = i < bestPlayers.length ? bestPlayers[i] : null;
                  final rank = 4 + i;
                  final name = entry != null ? _displayName(entry) : "-";
                  final scoreText = entry != null ? "${entry.score}" : "-";
                  return Row(
                    children: [
                      Container(
                        width: 36.w,
                        alignment: Alignment.center,
                        child: Text("#$rank", style: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.sp), overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 12.w),
                      Text(scoreText, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                      SizedBox(width: 8.w),
                      Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 14.sp),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 28.h, top: 6.h), // small top space inside block
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          podiumRow,
          SizedBox(height: 18.h), // push dashboard a bit further down from podium
          dashboardCard,
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(BuildContext context, LeaderboardEntry entry, ThemeData theme, {required double height, bool isFirst = false, required Color color}) {
    return Column(
      children: [
        if (isFirst) Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32.sp),
        SizedBox(height: isFirst ? 8.h : 12.h),
        Text("#${entry.rank}", style: TextStyle(fontSize: 18.sp, color: isFirst ? Colors.amber : Colors.white, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text(_displayName(entry), style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade300), overflow: TextOverflow.ellipsis),
        SizedBox(height: 8.h),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: Text(entry.score.toString(), style: TextStyle(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Widget _buildEmptyPodium(double height, Color color) {
    return Column(
      children: [
        SizedBox(height: 32.sp + 12.h + 4.h), // Icon + Text space
        Text("-", style: TextStyle(fontSize: 18.sp, color: color, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text("---", style: TextStyle(fontSize: 13.sp, color: color)),
        SizedBox(height: 8.h),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Center(child: Text("0", style: TextStyle(fontSize: 22.sp, color: color, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }


  // topic selection removed
}

// Kademeli liste animasyonu için yardımcı widget
class _AnimatedListItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final intervalStart = (index * 0.1).clamp(0.0, 1.0);
    final intervalEnd = (intervalStart + 0.5).clamp(0.0, 1.0);
    
    final animation = CurvedAnimation(parent: controller, curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut));
    
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}