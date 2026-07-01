import 'package:flutter/foundation.dart';
class TenantRefreshNotifier extends ChangeNotifier {
  TenantRefreshNotifier._internal();
  static final TenantRefreshNotifier instance = TenantRefreshNotifier._internal();

  void notifyTenantsChanged() => notifyListeners();
}