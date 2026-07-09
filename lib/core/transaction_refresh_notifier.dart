// lib/core/transaction_refresh_notifier.dart
import 'package:flutter/foundation.dart';

class TransactionRefreshNotifier extends ChangeNotifier {
  TransactionRefreshNotifier._internal();
  static final TransactionRefreshNotifier instance = TransactionRefreshNotifier._internal();

  void notifyTransactionsChanged() => notifyListeners();
}