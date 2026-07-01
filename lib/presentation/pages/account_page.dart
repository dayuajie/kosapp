import 'package:flutter/material.dart';

import 'edit_account_page.dart';

class AccountPage extends StatelessWidget {

  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const EditAccountPage(),
    );
  }
}
