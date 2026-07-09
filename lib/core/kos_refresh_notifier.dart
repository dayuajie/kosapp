import 'package:flutter/foundation.dart';

class KosRefreshNotifier extends ChangeNotifier {
  KosRefreshNotifier._internal();
  static final KosRefreshNotifier instance = KosRefreshNotifier._internal();

  void notifyKosChanged() => notifyListeners();
}