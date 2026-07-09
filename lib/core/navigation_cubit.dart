import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationCubit extends Cubit<int> {
  NavigationCubit() : super(0);

  
  void goToTab(int index) => emit(index);
  void goToDashboard() => goToTab(0);
  void goToTenants() => goToTab(1);
  void goToPayments() => goToTab(2);
  void goToAssignRoom() => goToTab(3);
  void goToSettings() => goToTab(4);
}