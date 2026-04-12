/* Apollo Home

   Root scaffold of the app.

   Manages the bottom navigation bar and switches between the five
   main screens using an IndexedStack so each screen keeps its state.

   Also shows an offline banner when there is no network connection.
*/

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/event_screen.dart';
import '../screens/program_screen.dart';
import '../screens/info_screen.dart';
import '../screens/chat_screen.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/auth_service.dart';
import '../theme/app_theme.dart';

class ApolloHome extends StatefulWidget {
  const ApolloHome({super.key});

  @override
  State<ApolloHome> createState() => _ApolloHomeState();
}

class _ApolloHomeState extends State<ApolloHome> {
  int _index = 0;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final AuthService _authService = AuthService.instance;
  late final ChatService _chatService;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(authService: _authService);
    _initConnectivity();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectivity);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivity(results);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() =>
        _isOffline = results.every((r) => r == ConnectivityResult.none));
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _switchTab(int newIndex) => setState(() => _index = newIndex);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(onNavigate: _switchTab),
                ProgramScreen(isActive: _index == 1),
                InfoScreen(),
                EventScreen(),
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

  Widget _buildOfflineBanner() => Container(
        width: double.infinity,
        color: AppColors.offlineBannerBg,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge,
          vertical: AppDimensions.paddingSmall,
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: const [
              Icon(Icons.wifi_off,
                  size: AppDimensions.iconMedium, color: AppColors.offlineIcon),
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
          BottomNavigationBarItem(icon: Icon(Icons.home),           label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Zending'),
          BottomNavigationBarItem(icon: Icon(Icons.info),           label: 'Info'),
          BottomNavigationBarItem(icon: Icon(Icons.event),          label: 'Event'),
          BottomNavigationBarItem(icon: Icon(Icons.chat),           label: 'Chat'),
        ],
      ),
    );
  }
}