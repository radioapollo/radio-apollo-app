/* Apollo Nav — Bottom Navigation

   The root navigation shell of the application.

   It handles:
   - holding the five top-level tabs (Home, Programma's, Info,
     Evenementen, Chat) inside a PageView
   - watching connectivity and showing an offline banner when there
     is no network
   - listening to Google Cast session events so the radio stream is
     loaded onto a connected Cast device automatically

   The connectivity check on startup is wrapped in a short timeout
   so the app does not block indefinitely when the device is offline.

   The PageView uses a custom `_StricterPageScrollPhysics` so a slight
   diagonal gesture while scrolling a list vertically (e.g. the program
   list) does not accidentally flick to the next tab.
*/

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/session.dart';
import '../screens/home_screen.dart';
import '../screens/event_screen.dart';
import '../screens/program_screen.dart';
import '../screens/info_screen.dart';
import '../screens/chat_screen.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/auth_service.dart';
import '../services/cast_service.dart';
import '../theme/app_theme.dart';

class ApolloNav extends StatefulWidget {
  const ApolloNav({super.key});

  @override
  State<ApolloNav> createState() => _ApolloNavState();
}

class _ApolloNavState extends State<ApolloNav> {
  int _index = 0;
  bool _isOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription? _castSessionSub;

  final AuthService _authService = AuthService.instance;
  late final ChatService _chatService;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(authService: _authService);
    _pageController = PageController(initialPage: _index);

    _initConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _updateConnectivity,
    );

    if (!kIsWeb) {
      _castSessionSub = GoogleCastSessionManager.instance.currentSessionStream
          .listen((session) {
            if (session != null) {
              CastService.instance.castRadioStream();
            }
          });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _connectivitySub?.cancel();
    _castSessionSub?.cancel();
    super.dispose();
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 3),
      );
      _updateConnectivity(results);
    } catch (_) {
      // If the check times out or fails, assume offline so the banner shows
      if (mounted) setState(() => _isOffline = true);
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(
      () => _isOffline = results.every((r) => r == ConnectivityResult.none),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _switchTab(int newIndex) {
    setState(() => _index = newIndex);
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              // Stricter physics: requires a more intentional horizontal
              // swipe before the page starts to move. This stops the
              // program list's vertical drag from accidentally flicking
              // to the Info tab when the user's finger wobbles slightly.
              physics: const _StricterPageScrollPhysics(),
              onPageChanged: (index) => setState(() => _index = index),
              children: [
                HomeScreen(onNavigate: _switchTab),
                ProgramScreen(isActive: _index == 1),
                InfoScreen(),
                const EventScreen(),
                ChatScreen(
                  chatService: _chatService,
                  authService: _authService,
                  isActive: _index == 4,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Offline banner ────────────────────────────────────────────────────────

  Widget _buildOfflineBanner() => Container(
    width: double.infinity,
    color: AppColors.offlineBannerBg,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingXLarge,
      vertical: AppDimensions.paddingSmall,
    ),
    child: const SafeArea(
      bottom: false,
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: AppDimensions.iconMedium,
            color: AppColors.offlineIcon,
          ),
          SizedBox(width: AppDimensions.spaceSmall),
          Expanded(
            child: Text(
              'Je bent offline – gegevens kunnen verouderd zijn.',
              style: TextStyle(fontSize: 12, color: AppColors.offlineText),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: AppDecorations.bottomNav,
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: _switchTab,
        backgroundColor: AppColors.white,
        elevation: 0,
        selectedItemColor: AppColors.primaryMid,
        unselectedItemColor: AppColors.navUnselected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Programma's",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Info'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Evenementen',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}

// ─── Page scroll physics ────────────────────────────────────────────────────
//
// The default PageScrollPhysics is very eager: the tiniest horizontal
// component in a gesture immediately starts moving the page. During a
// vertical drag on a list (such as the program list) a small diagonal
// jitter was enough to flick the user onto the next tab.
//
// Two tweaks fix this:
//   1. A larger `dragStartDistanceMotionThreshold` — the finger has to
//      travel further before the PageView will claim the gesture. This
//      is what lets a vertical list win the horizontal-vs-vertical
//      arbitration that happens at the start of every drag.
//   2. A stricter fling requirement — short, low-velocity swipes no
//      longer count as "change tab" and instead snap back to the
//      current page, which fixes the "flitst en hapert" feel.

class _StricterPageScrollPhysics extends PageScrollPhysics {
  const _StricterPageScrollPhysics({super.parent});

  @override
  _StricterPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _StricterPageScrollPhysics(parent: buildParent(ancestor));
  }

  // Require the finger to travel this many logical pixels before the
  // PageView will decide the gesture is a horizontal page swipe.
  // The default is ~3.5 — 18 is generous enough that diagonal jitter
  // during a vertical scroll is resolved in favour of the vertical
  // gesture.
  @override
  double get dragStartDistanceMotionThreshold => 18.0;

  // Require a more deliberate fling before the page actually advances.
  @override
  double get minFlingVelocity => 400;

  @override
  double get minFlingDistance => 24;
}