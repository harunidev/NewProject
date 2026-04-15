import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crosssync/core/theme/app_theme.dart';
import 'package:crosssync/features/auth/presentation/screens/login_screen.dart';
import 'package:crosssync/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:crosssync/features/tasks/presentation/screens/tasks_screen.dart';

void main() {
  runApp(const ProviderScope(child: CrossSyncApp()));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/app', builder: (_, __) => const CalendarScreen()),
        GoRoute(path: '/app/tasks', builder: (_, __) => const TasksScreen()),
      ],
    ),
  ],
);

class CrossSyncApp extends StatelessWidget {
  const CrossSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CrossSync',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({required this.child});

  final Widget child;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          switch (i) {
            case 0:
              context.go('/app');
            case 1:
              context.go('/app/tasks');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            activeIcon: Icon(Icons.check_box),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
