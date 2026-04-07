import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/event_screen.dart';
import '../screens/program_screen.dart';
import '../screens/info_screen.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ApolloHome extends StatefulWidget {
  const ApolloHome({super.key});

  @override
  State<ApolloHome> createState() => _ApolloHomeState();
}

class _ApolloHomeState extends State<ApolloHome> {
  int _index = 0;
  final AuthService _authService = AuthService.instance;
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(authService: _authService);
  }

  void _switchTab(int newIndex) => setState(() => _index = newIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onNavigate: _switchTab),
          const ProgramScreen(),
          InfoScreen(),
          EventScreen(),
          // isActive updates on every rebuild so didUpdateWidget fires correctly
          // when the user navigates to the chat tab.
          ChatScreen(
            chatService: _chatService,
            authService: _authService,
            isActive: _index == 4,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: AppDecorations.bottomNav,
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: _switchTab,
        backgroundColor: AppColors.white,
        elevation: 0,
        selectedItemColor: AppColors.primaryMid,
        unselectedItemColor: Colors.grey,
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