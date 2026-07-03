import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:kos_app/presentation/pages/assign_room_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/app_bottom_navigation.dart';
import '../navigation/bottom_nav_item.dart';
import 'dashboard_page.dart';
import 'payments_page.dart';
import 'tenants_page.dart';
import 'settings_page.dart';
import 'tenant_form_page.dart';
import '../../core/navigation_request_notifier.dart';


class MainBottomNavShell extends StatefulWidget {
  const MainBottomNavShell({super.key});

  @override
  State<MainBottomNavShell> createState() => _MainBottomNavShellState();
}

class _MainBottomNavShellState extends State<MainBottomNavShell> {
  int currentIndex = 0;
  final _tenantsKey = GlobalKey<State>();
  StreamSubscription<AuthState>? _authSubscription; 

  @override
  void initState() {
    super.initState();
    
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.userUpdated || data.event == AuthChangeEvent.signedIn) {
        if (mounted) {
          setState(() {}); 
        }
      }
    });
    NavigationRequestNotifier.instance.addListener(_onNavigationRequested);
  }

  void _onNavigationRequested() { 
  final idx = NavigationRequestNotifier.instance.requestedIndex;
  if (idx != null && mounted) {
    setState(() => currentIndex = idx);
    NavigationRequestNotifier.instance.clear();
  }
}

  @override
  void dispose() {
    _authSubscription?.cancel(); 
    NavigationRequestNotifier.instance.removeListener(_onNavigationRequested);
    super.dispose();
  }

  String? _activeKosId() {
    return Supabase.instance.client.auth.currentUser?.userMetadata?['kos_id']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currentKosId = _activeKosId();
    final List<BottomNavItem> items = [
  BottomNavItem(
    id: 'dashboard',
    icon: Icons.dashboard_outlined,
    label: 'Dashboard',
    page: const DashboardPage(), 
  ),
  BottomNavItem(
    id: 'tenant',
    icon: Icons.people_alt_rounded,
    label: 'Penghuni',
    // Pindahkan key ke sini agar fungsi refresh di onTap bisa memanggilnya
    page: TenantsPage(key: _tenantsKey), 
  ),
  BottomNavItem(
    id: 'payments',
    icon: Icons.receipt_long_outlined,
    label: 'Pembayaran',
    page: const PaymentsPage(),
  ),
  BottomNavItem(
    id: 'assign',
    icon: Icons.bed_outlined,
    label: 'Tempatkan',
    page: const AssignRoomPage(),
  ),
  BottomNavItem(
    id: 'settings',
    icon: Icons.settings_outlined,
    label: 'Pengaturan',
    page: const SettingsPage(),
  ),
];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: items.map((e) => SafeArea(child: e.page)).toList(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Stack(
            children: [
              Positioned.fill(
                child: AppBottomNavigation(
                  currentIndex: currentIndex,
                  onTap: (i) {
                    setState(() => currentIndex = i);
                    if (i == 1) {
                      (_tenantsKey.currentState as dynamic)?.refreshTenants();
                    }
                  },
                  items: items,
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TenantFormPage(),
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF6D5EF6),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(18),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                      tooltip: 'Tambah Penghuni',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}