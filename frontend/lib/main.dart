import 'package:flutter/material.dart';
import 'screens/explore_map_screen.dart';
import 'screens/explore_stays_screen.dart';
import 'screens/login_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentStayApp());
}

class StudentStayApp extends StatefulWidget {
  final ApiService? apiService;
  final AuthService? authService;
  final bool initialGuestMode;

  const StudentStayApp({
    super.key,
    this.apiService,
    this.authService,
    this.initialGuestMode = false,
  });

  @override
  State<StudentStayApp> createState() => _StudentStayAppState();
}

class _StudentStayAppState extends State<StudentStayApp> {
  late final ApiService _apiService;
  late final AuthService _authService;
  late bool _guestMode;

  @override
  void initState() {
    super.initState();
    _guestMode = widget.initialGuestMode;
    _apiService = widget.apiService ?? ApiService();
    _authService = widget.authService ?? AuthService(apiService: _apiService);
    _authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudentStay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade700,
          primary: Colors.blue.shade700,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 1,
        ),
      ),
      home: ListenableBuilder(
        listenable: _authService,
        builder: (context, _) {
          if (_authService.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Pehle Student/User Login karega, tabhi main app access hoga
          if (!_authService.isAuthenticated && !_guestMode) {
            return LoginScreen(
              authService: _authService,
              onContinueAsGuest: () {
                setState(() {
                  _guestMode = true;
                });
              },
            );
          }

          return MainNavigationShell(
            apiService: _apiService,
            authService: _authService,
          );
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final ApiService? apiService;
  final AuthService? authService;

  const MainNavigationShell({
    super.key,
    this.apiService,
    this.authService,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  late final ApiService _apiService;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _authService = widget.authService ?? AuthService(apiService: _apiService);
  }

  @override
  Widget build(BuildContext context) {
        final screens = [
      ExploreStaysScreen(
        apiService: _apiService,
        authService: _authService,
      ),
      ExploreMapScreen(
        apiService: _apiService,
      ),
      OwnerDashboardScreen(
        apiService: _apiService,
        authService: _authService,
        onNavigateToAuth: () => setState(() => _currentIndex = 3),
      ),
      ProfileScreen(
        authService: _authService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
                destinations: const [
          NavigationDestination(
            key: Key('nav_explore_stays'),
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Explore',
          ),
          NavigationDestination(
            key: Key('nav_explore_map'),
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map View',
          ),
          NavigationDestination(
            key: Key('nav_owner_dashboard'),
            icon: Icon(Icons.real_estate_agent_outlined),
            selectedIcon: Icon(Icons.real_estate_agent),
            label: 'Owner Portal',
          ),
          NavigationDestination(
            key: Key('nav_profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        ),
    );
  }
}
