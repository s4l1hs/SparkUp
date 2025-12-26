import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../models/leaderboard_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sparkup_app/utils/color_utils.dart';

class LeaderboardPage extends StatefulWidget {
  final String idToken;
  const LeaderboardPage({super.key, required this.idToken});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  UserProvider? _observedUserProvider;

  List<LeaderboardEntry> _leaderboardData = [];
  LeaderboardEntry? _currentUserEntry;
  bool _isLoading = true;
  bool _hasError = false;

  late final AnimationController _listAnimationController;
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat(reverse: true);
    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomRight, end: Alignment.topLeft),
          weight: 1),
    ]).animate(_backgroundController);
    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomLeft, end: Alignment.topRight),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topRight, end: Alignment.bottomLeft),
          weight: 1),
    ]).animate(_backgroundController);

    // Localizations ve context tam hazır olduktan sonra yükleme yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPageData();
      // register provider listener once after first frame
      _observedUserProvider =
          Provider.of<UserProvider?>(context, listen: false);
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
    if (_currentUserEntry != null &&
        providerScore != _currentUserEntry!.score) {
      setState(() {
        // update or insert
        final email = _currentUserEntry!.email;
        final username = _currentUserEntry!.username;
        int foundIndex = -1;
        for (var i = 0; i < _leaderboardData.length; i++) {
          final e = _leaderboardData[i];
          if ((email != null && e.email == email) ||
              (username != null && e.username == username)) {
            foundIndex = i;
            break;
          }
        }
        if (foundIndex >= 0) {
          _leaderboardData[foundIndex] = LeaderboardEntry(
              rank: _leaderboardData[foundIndex].rank,
              email: _leaderboardData[foundIndex].email,
              username: _leaderboardData[foundIndex].username,
              score: providerScore);
        } else {
          // if not present, append entry using currentUserEntry meta
          _leaderboardData.add(LeaderboardEntry(
              rank: _currentUserEntry!.rank,
              email: _currentUserEntry!.email,
              username: _currentUserEntry!.username,
              score: providerScore));
        }

        // resort and recompute ranks
        _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
        for (var i = 0; i < _leaderboardData.length; i++) {
          final e = _leaderboardData[i];
          _leaderboardData[i] = LeaderboardEntry(
              rank: i + 1,
              email: e.email,
              username: e.username,
              score: e.score);
          // update _currentUserEntry when matching
          if ((_currentUserEntry!.email != null &&
                  _currentUserEntry!.email == e.email) ||
              (_currentUserEntry!.username != null &&
                  _currentUserEntry!.username == e.username)) {
            _currentUserEntry = LeaderboardEntry(
                rank: i + 1,
                email: _currentUserEntry!.email,
                username: _currentUserEntry!.username,
                score: providerScore);
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
      final leaderboardResp = await _apiServiceSafe(
          () => _apiService.getLeaderboard(widget.idToken),
          const Duration(seconds: 8));
      final userRankResp = await _apiServiceSafe(
          () => _apiService.getUserRank(widget.idToken),
          const Duration(seconds: 8));

      // Normalize leaderboard
      List<LeaderboardEntry> leaderboardParsed = [];
      if (leaderboardResp is List) {
        leaderboardParsed = leaderboardResp.map((e) {
          if (e is LeaderboardEntry) return e;
          return LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map));
        }).toList();
      }

      LeaderboardEntry? currentUserParsed;
      if (userRankResp is LeaderboardEntry) {
        currentUserParsed = userRankResp;
      } else if (userRankResp is Map) {
        currentUserParsed =
            LeaderboardEntry.fromJson(Map<String, dynamic>.from(userRankResp));
      }

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
            if ((fbEmail != null && e.email == fbEmail) ||
                (fbName != null && e.username == fbName)) {
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
        final msg = AppLocalizations.of(context)?.errorCouldNotLoadData ??
            "Could not load data (timeout)";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e, st) {
      debugPrint("Sayfa verileri yüklenirken hata: $e\n$st");
      if (mounted) {
        setState(() => _hasError = true);
        final msg = AppLocalizations.of(context)?.noDataAvailable;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg!), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // helper used earlier — keep as is
  Future<dynamic> _apiServiceSafe(
      Future<dynamic> Function() fn, Duration timeout) {
    return fn().timeout(timeout,
        onTimeout: () => throw TimeoutException("API timeout"));
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
      return 'rankIron';
    }
  }

  String _maskEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@${domain.substring(0, 1)}...';
    return '${name.substring(0, 2)}***@${domain.substring(0, 1)}...';
  }

  String _displayName(LeaderboardEntry entry) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final fbName = fbUser?.displayName;
    final fbEmail = fbUser?.email;
    // If this leaderboard entry corresponds to the logged-in user (by email),
    // prefer the Firebase displayName (full name) as in settings_page.dart
    if (fbName != null &&
        fbName.trim().isNotEmpty &&
        fbEmail != null &&
        entry.email != null &&
        entry.email == fbEmail) {
      return fbName;
    }
    if (entry.username != null && entry.username!.trim().isNotEmpty) {
      return entry.username!;
    }
    return _maskEmail(entry.email);
  }

  // --- ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Respect user's reduced-motion accessibility setting
    final bool animate = !MediaQuery.of(context).accessibleNavigation;

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
              (fbUser?.displayName != null &&
                  e.username == fbUser!.displayName)) {
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
      else if (_currentUserEntry != null &&
          providerScore != _currentUserEntry!.score) {
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
                  (e.username != null &&
                      e.username == _currentUserEntry!.username)) {
                foundIndex = i;
                break;
              }
            }
            if (foundIndex >= 0) {
              _leaderboardData[foundIndex] = LeaderboardEntry(
                  rank: _leaderboardData[foundIndex].rank,
                  email: _leaderboardData[foundIndex].email,
                  username: _leaderboardData[foundIndex].username,
                  score: providerScore);
            } else {
              // if not present, append — will be re-sorted below
              _leaderboardData.add(LeaderboardEntry(
                  rank: _currentUserEntry!.rank,
                  email: _currentUserEntry!.email,
                  username: _currentUserEntry!.username,
                  score: providerScore));
            }

            // 3) re-sort leaderboard by score desc and recompute ranks
            _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
            for (var i = 0; i < _leaderboardData.length; i++) {
              final e = _leaderboardData[i];
              _leaderboardData[i] = LeaderboardEntry(
                  rank: i + 1,
                  email: e.email,
                  username: e.username,
                  score: e.score);
              // also update currentUserEntry.rank if it matches
              if ((_currentUserEntry!.email != null &&
                      _currentUserEntry!.email == e.email) ||
                  (_currentUserEntry!.username != null &&
                      _currentUserEntry!.username == e.username)) {
                _currentUserEntry = LeaderboardEntry(
                    rank: i + 1,
                    email: _currentUserEntry!.email,
                    username: _currentUserEntry!.username,
                    score: providerScore);
              }
            }
          });
        });
      }
    }

    // Show only users after rank 10 (i.e. index >= 10). Ranks 4..10 are handled in the Top Players dashboard.
    final listDisplay = _leaderboardData.length > 10
        ? _leaderboardData.sublist(10)
        : <LeaderboardEntry>[];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // animated ambient background blobs for depth
          AnimatedBuilder(
            // If user requests reduced motion, stop the background animation updates
            animation: animate
                ? _backgroundController
                : const AlwaysStoppedAnimation(0),
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: animate
                          ? _backgroundAnimation1.value
                          : Alignment.center,
                      child: Container(
                        width: 420.w,
                        height: 420.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            colorWithOpacity(theme.colorScheme.primary, 0.14),
                            Colors.transparent
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: colorWithOpacity(
                                    theme.colorScheme.primary, 0.06),
                                blurRadius: 100.r,
                                spreadRadius: 60.r)
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: animate
                          ? _backgroundAnimation2.value
                          : Alignment.center,
                      child: Container(
                        width: 320.w,
                        height: 320.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            colorWithOpacity(theme.colorScheme.secondary, 0.12),
                            Colors.transparent
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: colorWithOpacity(
                                    theme.colorScheme.secondary, 0.05),
                                blurRadius: 100.r,
                                spreadRadius: 40.r)
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.primary))
                : _hasError
                    ? Center(
                        child: Text(
                            "${localizations.error}: ${localizations.noDataAvailable}",
                            style: TextStyle(color: theme.colorScheme.error)))
                    : _leaderboardData.isEmpty && _currentUserEntry == null
                        ? Center(
                            child: Text(localizations.noDataAvailable,
                                style: TextStyle(color: Colors.grey.shade400)))
                        : CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 12.h),
                                sliver: SliverToBoxAdapter(
                                  child: _HeaderRow(
                                      localizations: localizations,
                                      theme: theme,
                                      currentUser: _currentUserEntry,
                                      displayNameFn: _displayName),
                                ),
                              ),
                              if (_leaderboardData.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _AnimatedListItem(
                                    index: 0,
                                    controller: _listAnimationController,
                                    child: _buildPodium(
                                        context,
                                        _leaderboardData.take(3).toList(),
                                        _leaderboardData.skip(3).toList()),
                                  ),
                                ),
                              if (_currentUserEntry != null)
                                SliverToBoxAdapter(
                                  child: _AnimatedListItem(
                                      index: 1,
                                      controller: _listAnimationController,
                                      child: _buildUserRankCard(theme,
                                          _currentUserEntry!, localizations)),
                                ),
                              SliverPadding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 8.h),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final entry = listDisplay[index];
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 12.h),
                                        child: _AnimatedListItem(
                                          index: index + 2,
                                          controller: _listAnimationController,
                                          child: _buildLeaderboardTile(
                                              theme, entry),
                                        ),
                                      );
                                    },
                                    childCount: listDisplay.length,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 80)),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankCard(
      ThemeData theme, LeaderboardEntry entry, AppLocalizations localizations) {
    final String rankKey = _getRankKey(entry.score);
    String getLocalizedRank(String key) {
      switch (key) {
        case 'rankMaster':
          return localizations.rankMaster;
        case 'rankDiamond':
          return localizations.rankDiamond;
        case 'rankGold':
          return localizations.rankGold;
        case 'rankSilver':
          return localizations.rankSilver;
        case 'rankBronze':
          return localizations.rankBronze;
        case 'rankIron':
          return localizations.rankIron;
        default:
          return '';
      }
    }

    final String rankName = getLocalizedRank(rankKey);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: GlassCard(
        padding: EdgeInsets.all(14.w),
        borderRadius: BorderRadius.circular(14.r),
        child: Row(
          children: [
            _GradientAvatar(name: _displayName(entry), radius: 28.r, colors: [
              theme.colorScheme.secondary,
              theme.colorScheme.primary
            ]),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.yourRank,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6.h),
                    Row(children: [
                      Text(_displayName(entry),
                          style: TextStyle(color: Colors.grey.shade200)),
                      SizedBox(width: 8.w),
                      Text("($rankName)",
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  Text(entry.score.toString(),
                      style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp)),
                  SizedBox(width: 6.w),
                  Icon(Icons.star_rounded,
                      color: theme.colorScheme.secondary, size: 18.sp)
                ]),
                SizedBox(height: 6.h),
                GradientButton(
                  onPressed: () => _loadPageData(),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
                  ],
                  borderRadius: BorderRadius.circular(10.r),
                  child: Text(AppLocalizations.of(context)!.refresh,
                      style: TextStyle(fontSize: 12.sp)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(ThemeData theme, LeaderboardEntry entry) {
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      borderRadius: BorderRadius.circular(12.r),
      child: Row(
        children: [
          SizedBox(
              width: 44.w,
              child: Text("#${entry.rank}",
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.bold))),
          _GradientAvatar(
              name: _displayName(entry),
              radius: 20.r,
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
          SizedBox(width: 12.w),
          Expanded(
              child: Text(_displayName(entry),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(width: 8.w),
          Row(children: [
            Text(entry.score.toString(),
                style: TextStyle(
                    fontSize: 14.sp,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold)),
            SizedBox(width: 6.w),
            Icon(Icons.star_rounded,
                color: theme.colorScheme.secondary, size: 16.sp)
          ]),
        ],
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<LeaderboardEntry> topEntries,
      List<LeaderboardEntry> bestPlayers) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    final List<LeaderboardEntry?> podium = List.generate(
        3, (index) => index < topEntries.length ? topEntries[index] : null);

    return Padding(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stylized podium with 3D feeling
          Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                colorWithOpacity(theme.colorScheme.surface, 0.08),
                colorWithOpacity(Colors.black, 0.06)
              ]),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.black45,
                    blurRadius: 22.r,
                    offset: Offset(0, 10.h))
              ],
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                    child: _PodiumBlock(
                        entry: podium[1],
                        height: 120.h,
                        color: const Color(0xFFC0C0C0),
                        place: 2,
                        displayNameFn: _displayName)),
                Expanded(
                    child: _PodiumBlock(
                        entry: podium[0],
                        height: 160.h,
                        color: const Color(0xFFFFD700),
                        place: 1,
                        isChampion: true,
                        displayNameFn: _displayName)),
                Expanded(
                    child: _PodiumBlock(
                        entry: podium[2],
                        height: 100.h,
                        color: const Color(0xFFB87333),
                        place: 3,
                        displayNameFn: _displayName)),
              ],
            ),
          ),
          SizedBox(height: 18.h),

          // Top players dashboard (4..10)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: GlassCard(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
              borderRadius: BorderRadius.circular(12.r),
              child: Column(
                children: [
                  Text(localizations.topPlayers,
                      style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  const Divider(color: Colors.white12),
                  SizedBox(height: 10.h),
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Builder(builder: (context) {
                        final entry =
                            i < bestPlayers.length ? bestPlayers[i] : null;
                        final rank = 4 + i;
                        final name = entry != null ? _displayName(entry) : "-";
                        final scoreText =
                            entry != null ? "${entry.score}" : "-";
                        return Row(
                          children: [
                            SizedBox(
                                width: 36.w,
                                child: Text("#$rank",
                                    style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontWeight: FontWeight.bold))),
                            SizedBox(width: 8.w),
                            Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 8.w),
                            Text(scoreText,
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 8.w),
                            Icon(Icons.star_rounded,
                                color: theme.colorScheme.secondary,
                                size: 14.sp),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// small reusable gradient avatar used inside this file
class _GradientAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final List<Color> colors;
  const _GradientAvatar(
      {required this.name, required this.radius, required this.colors});

  @override
  Widget build(BuildContext context) {
    final initials = (name.isNotEmpty) ? name.trim()[0].toUpperCase() : 'A';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 8.r, offset: Offset(0, 4.h))
        ],
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8.sp)),
    );
  }
}

// Podium block widget for clearer structure
class _PodiumBlock extends StatelessWidget {
  final LeaderboardEntry? entry;
  final double height;
  final Color color;
  final int place;
  final bool isChampion;
  final String Function(LeaderboardEntry) displayNameFn;

  const _PodiumBlock(
      {this.entry,
      required this.height,
      required this.color,
      required this.place,
      this.isChampion = false,
      required this.displayNameFn});

  @override
  Widget build(BuildContext context) {
    final display = entry != null ? displayNameFn(entry!) : "-";
    final score = entry != null ? entry!.score.toString() : "0";

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isChampion)
            Transform.translate(
                offset: Offset(0, -12.h),
                child: Icon(Icons.emoji_events_rounded,
                    color: Colors.amber, size: 28.sp)),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: colorWithOpacity(color, 0.06),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              border:
                  Border.all(color: colorWithOpacity(color, 0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10.r,
                    offset: Offset(0, 8.h))
              ],
            ),
            child: Column(
              children: [
                _GradientAvatar(
                    name: display,
                    radius: isChampion ? 32.r : 26.r,
                    colors: [color, colorWithOpacity(color, 0.6)]),
                SizedBox(height: 8.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 120.w),
                  child: Text(display,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: height,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      colorWithOpacity(color, 0.9),
                      colorWithOpacity(color, 0.35)
                    ]),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12.r)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8.r,
                          offset: Offset(0, 6.h))
                    ],
                  ),
                  child: Text(score,
                      style: TextStyle(
                          fontSize: 20.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 6.h),
                Text("#$place",
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Animated list item helper (unchanged except timings)
class _AnimatedListItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedListItem(
      {required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool animate = !MediaQuery.of(context).accessibleNavigation;
    if (!animate) return child;

    final intervalStart = (index * 0.08).clamp(0.0, 1.0);
    final intervalEnd = (intervalStart + 0.5).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
        parent: controller,
        curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut));

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

// Small header row with title and optional current user summary
class _HeaderRow extends StatelessWidget {
  final AppLocalizations localizations;
  final ThemeData theme;
  final LeaderboardEntry? currentUser;
  final String Function(LeaderboardEntry) displayNameFn;

  const _HeaderRow(
      {required this.localizations,
      required this.theme,
      this.currentUser,
      required this.displayNameFn});

  @override
  Widget build(BuildContext context) {
    final userProv = Provider.of<UserProvider?>(context);
    final profile = userProv?.profile;
    int maxEnergy = 5;
    if (profile != null) {
      final level = profile.subscriptionLevel.toLowerCase();
      if (level == 'free') {
        maxEnergy = 3;
      } else if (level == 'pro') {
        maxEnergy = 5;
      } else if (level == 'ultra') {
        maxEnergy = 5;
      }
    }
    final currentEnergy = profile?.remainingEnergy ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(localizations.leaderboard,
                    style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))),
            if (currentUser != null)
              Row(
                children: [
                  _GradientAvatar(
                      name: displayNameFn(currentUser!),
                      radius: 18.r,
                      colors: [
                        theme.colorScheme.secondary,
                        theme.colorScheme.primary
                      ]),
                  SizedBox(width: 8.w),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayNameFn(currentUser!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text("${currentUser!.score} ${localizations.points}",
                            style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 12.sp)),
                      ])
                ],
              )
          ],
        ),
        if (profile != null) ...[
          SizedBox(height: 12.h),
          // Energy slider
          _EnergySlider(
              current: currentEnergy.clamp(0, maxEnergy),
              max: maxEnergy,
              theme: theme),
          SizedBox(height: 6.h)
        ]
      ],
    );
  }
}

class _EnergySlider extends StatefulWidget {
  final int current;
  final int max;
  final ThemeData theme;
  const _EnergySlider(
      {required this.current, required this.max, required this.theme});

  @override
  State<_EnergySlider> createState() => _EnergySliderState();
}

class _EnergySliderState extends State<_EnergySlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color _getEnergyColor(double percentage) {
    if (percentage <= 0.25) return Colors.redAccent;
    if (percentage <= 0.50) return Colors.orangeAccent;
    // Neon yellow/gold for energy (bright, attention-grabbing)
    return const Color(0xFFFFD700);
    // Veya temanın rengini kullanmak istersen:
    // return widget.theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Enerji yüzdesi
    final double percentage =
        widget.max > 0 ? (widget.current / widget.max) : 0.0;
    final Color activeColor = _getEnergyColor(percentage);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık ve Sayaç
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: activeColor, size: 18.sp),
                  SizedBox(width: 6.w),
                  Text(
                    AppLocalizations.of(context)?.energyLabel ?? 'Energy',
                    style: TextStyle(
                      color: colorWithOpacity(Colors.white, 0.9),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colorWithOpacity(activeColor, 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colorWithOpacity(activeColor, 0.3)),
                ),
                child: Text(
                  '${widget.current}/${widget.max}',
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Segmentli Enerji Barı
          SizedBox(
            height: 14.h, // Bar yüksekliği
            child: Row(
              children: List.generate(widget.max, (index) {
                // Bu segment dolu mu?
                final bool isActive = index < widget.current;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: index == widget.max - 1
                            ? 0
                            : 6.w), // Segmentler arası boşluk
                    child: isActive
                        ? _buildActiveSegment(activeColor)
                        : _buildInactiveSegment(),
                  ),
                );
              }),
            ),
          ),

          // Alt Bilgi: (refill info removed — handled server-side)
        ],
      ),
    );
  }

  Widget _buildActiveSegment(Color color) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            gradient: LinearGradient(
              colors: [
                colorWithOpacity(color, 0.7),
                color,
                colorWithOpacity(color, 0.7)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colorWithOpacity(color, 0.6),
                blurRadius: 8.r, // Glow efekti
                offset: const Offset(0, 0),
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: Stack(
              children: [
                // Shimmer Efekti (Işık yansıması geçişi)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pos =
                          constraints.maxWidth * 2 * _shimmerController.value -
                              constraints.maxWidth;
                      return Transform.translate(
                        offset: Offset(pos, 0),
                        child: Container(
                          width: constraints.maxWidth * 0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorWithOpacity(Colors.white, 0.0),
                                colorWithOpacity(Colors.white, 0.4),
                                colorWithOpacity(Colors.white, 0.0)
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInactiveSegment() {
    return Container(
      decoration: BoxDecoration(
        color: colorWithOpacity(Colors.white, 0.1), // Sönük arka plan
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: colorWithOpacity(Colors.white, 0.05)),
      ),
    );
  }
}
