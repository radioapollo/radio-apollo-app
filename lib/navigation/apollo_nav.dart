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
  int  _index     = 0;
  bool _isOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription?                           _castSessionSub;

  final AuthService      _authService = AuthService.instance;
  late final ChatService _chatService;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _chatService    = ChatService(authService: _authService);
    _pageController = PageController(initialPage: _index);

    _initConnectivity();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectivity);

    if (!kIsWeb) {
      _castSessionSub = GoogleCastSessionManager.instance
          .currentSessionStream
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
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      _updateConnectivity(results);
    } catch (_) {
      // If the check times out or fails, assume offline so the banner shows
      if (mounted) setState(() => _isOffline = true);
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() =>
        _isOffline = results.every((r) => r == ConnectivityResult.none));
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _switchTab(int newIndex) {
    setState(() => _index = newIndex);
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOut,
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
              controller:    _pageController,
              physics:       const ClampingScrollPhysics(),
              onPageChanged: (index) => setState(() => _index = index),
              children: [
                HomeScreen(onNavigate: _switchTab),
                ProgramScreen(isActive: _index == 1),
                InfoScreen(),
                const EventScreen(),
                ChatScreen(
                  chatService: _chatService,
                  authService: _authService,
                  isActive:    _index == 4,
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
        width:   double.infinity,
        color:   AppColors.offlineBannerBg,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge,
          vertical:   AppDimensions.paddingSmall,
        ),
        child: const SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(Icons.wifi_off,
                  size:  AppDimensions.iconMedium,
                  color: AppColors.offlineIcon),
              SizedBox(width: AppDimensions.spaceSmall),
              Expanded(
                child: Text(
                  'Je bent offline – gegevens kunnen verouderd zijn.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.offlineText),
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
        currentIndex:        _index,
        onTap:               _switchTab,
        backgroundColor:     AppColors.white,
        elevation:           0,
        selectedItemColor:   AppColors.primaryMid,
        unselectedItemColor: AppColors.navUnselected,
        type:                BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),           label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Programma's"),
          BottomNavigationBarItem(icon: Icon(Icons.info),           label: 'Info'),
          BottomNavigationBarItem(icon: Icon(Icons.event),          label: 'Evenementen'),
          BottomNavigationBarItem(icon: Icon(Icons.chat),           label: 'Chat'),
        ],
      ),
    );
  }
}