import 'package:flutter/foundation.dart';

class NavigationRequestNotifier extends ChangeNotifier {
  NavigationRequestNotifier._();
  static final NavigationRequestNotifier instance = NavigationRequestNotifier._();

  int? _requestedIndex;
  int? get requestedIndex => _requestedIndex;

  void requestTab(int index) {
    _requestedIndex = index;
    notifyListeners();
  }

  void clear() {
    _requestedIndex = null;
  }
}