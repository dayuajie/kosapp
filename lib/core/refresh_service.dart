
import 'dart:async';
class RefreshService {
  RefreshService._internal();
  static final RefreshService _instance = RefreshService._internal();
  static RefreshService get instance => _instance;

  final StreamController<RefreshEvent> _controller =
      StreamController<RefreshEvent>.broadcast();
  Stream<RefreshEvent> get onRefresh => _controller.stream;
  void emit(RefreshEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
  void refreshTenants() => emit(RefreshEvent.tenants);
  void refreshTransactions() => emit(RefreshEvent.transactions);
  void refreshKos() => emit(RefreshEvent.kos);
  void refreshRooms() => emit(RefreshEvent.rooms);

  void dispose() => _controller.close();
}

enum RefreshEvent {
  tenants,
  transactions,
  kos,
  rooms,
}