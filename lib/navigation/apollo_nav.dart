/* Apollo Nav — Responsive Navigation Shell

   The root navigation shell of the application.

   On MOBILE (< 600 dp wide): the original BottomNavigationBar.
   On DESKTOP (≥ 600 dp wide): a NavigationRail on the left side,
     which is how desktop/windowed Flutter apps are expected to look.
     This makes every tab reachable with a mouse without needing to
     swipe, and avoids the bottom bar being stranded at the bottom of
     a tall window.

   Everything else — connectivity banner, PageView, tab switching,
   notification routing — is unchanged.
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
import '../services/notifications/notification_router.dart';
import '../theme/app_theme.dart';

/// Width threshold above which the side rail is used instead of bottom nav.
const double _kDesktopBreakpoint = 600.0;

class ApolloNav extends StatefulWidget {
  const ApolloNav({super.key});

  @override
  State<ApolloNav> createState() => _ApolloNavState();
}

class _ApolloNavState extends State<ApolloNav> {
  int _index = 0;
  bool _isOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
    NotificationRouter.instance.requestedTab.addListener(_onNotificationRoute);
    _onNotificationRoute();
  }

  @override
  void dispose() {
    NotificationRouter.instance.requestedTab.removeListener(
      _onNotificationRoute,
    );
    _pageController.dispose();
    _connectivitySub?.cancel();
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

  void _onNotificationRoute() {
    final tab = NotificationRouter.instance.requestedTab.value;
    if (tab == null) return;
    _switchTab(tab);
    NotificationRouter.instance.consume();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;
        return isDesktop ? _buildDesktopShell() : _buildMobileShell();
      },
    );
  }

  // ── Mobile: bottom navigation bar ────────────────────────────────────────

  Widget _buildMobileShell() {
    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(child: _buildPageView()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Desktop: side navigation rail ────────────────────────────────────────

  Widget _buildDesktopShell() {
    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: Row(
              children: [
                _buildNavRail(),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _buildPageView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _switchTab,
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppColors.bottomNavBg,
      selectedIconTheme: IconThemeData(color: AppColors.primaryMid),
      unselectedIconTheme: IconThemeData(color: AppColors.navUnselected),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.primaryMid,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppColors.navUnselected,
        fontSize: 12,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: Text("Programma's"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.info_outlined),
          selectedIcon: Icon(Icons.info),
          label: Text('Info'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: Text('Evenementen'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: Text('Chat'),
        ),
      ],
    );
  }

  // ── Shared page view ──────────────────────────────────────────────────────

  Widget _buildPageView() {
    return PageView(
      controller: _pageController,
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

  // ── Bottom nav (mobile only) ──────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: AppDecorations.bottomNav,
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: _switchTab,
        backgroundColor: AppColors.bottomNavBg,
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

// ── Page scroll physics ──────────────────────────────────────────────────────

class _StricterPageScrollPhysics extends PageScrollPhysics {
  const _StricterPageScrollPhysics({super.parent});

  @override
  _StricterPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _StricterPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 18.0;

  @override
  double get minFlingVelocity => 400;

  @override
  double get minFlingDistance => 24;
}