import 'package:flutter/material.dart';
import 'account_page.dart';
import 'security_page.dart';
import 'preferences_page.dart';
import 'registration/registration_form_page.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Profile / account fields
  String _displayName = 'Rahman';
  String _userStatus = 'Administrator';
  String _email = 'rahman@example.com';

  // Security / payment
  bool _isBiometricEnabled = false;
  bool _hasPassword = true;
  String _paymentMethod = 'Tidak ada';

  // Preferences
  bool _notificationsEnabled = true;
  String _language = 'Bahasa Indonesia';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _displayName);
    final statusController = TextEditingController(text: _userStatus);
    final emailController = TextEditingController(text: _email);

    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: statusController,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: const Icon(Icons.work_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _displayName = nameController.text.trim().isEmpty ? _displayName : nameController.text.trim();
        _userStatus = statusController.text.trim().isEmpty ? _userStatus : statusController.text.trim();
        _email = emailController.text.trim().isEmpty ? _email : emailController.text.trim();
      });
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    
    final ok = await showDialog<bool?>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubah Password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (newController.text != confirmController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password baru tidak cocok')),
                          );
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _hasPassword = true);
    }
  }

  Future<void> _pickLanguage() async {
    final languages = [
      {'name': 'Bahasa Indonesia', 'code': 'id'},
      {'name': 'English', 'code': 'en'},
    ];
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih Bahasa'),
        children: languages
            .map((l) => SimpleDialogOption(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _language == l['name'] ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(l['name']!),
                      ],
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(l['name']),
                ))
            .toList(),
      ),
    );

    if (res != null) setState(() => _language = res);
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? Theme.of(context).primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade600),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      // TODO_BLACKBOXAI_TempRegistrationFAB_START
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const RegistrationPage(),
            ),
          );
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register'),
        tooltip: 'Temporary: Registration form',
      ),
      // TODO_BLACKBOXAI_TempRegistrationFAB_END
      body: SafeArea(

        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Card - Enhanced
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _editProfile,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.edit, size: 18, color: Colors.grey.shade600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  _userStatus,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _email,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Akses Cepat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickActionCard(
                  title: 'Bahasa',
                  icon: Icons.language,
                  value: _language == 'Bahasa Indonesia' ? 'ID' : 'EN',
                  onTap: _pickLanguage,
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  title: 'Notifikasi',
                  icon: Icons.notifications_active,
                  value: _notificationsEnabled ? 'On' : 'Off',
                  onTap: () {
                    setState(() => _notificationsEnabled = !_notificationsEnabled);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notifikasi ${_notificationsEnabled ? "diaktifkan" : "dinonaktifkan"}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  title: 'Mode Gelap',
                  icon: Icons.dark_mode,
                  value: _darkMode ? 'On' : 'Off',
                  onTap: () {
                    setState(() => _darkMode = !_darkMode);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Mode gelap ${_darkMode ? "diaktifkan" : "dinonaktifkan"}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Main Settings Sections
            const Text(
              'Pengaturan Utama',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildSettingsCard(
              title: 'Akun',
              icon: Icons.person_outline,
              subtitle: 'Informasi akun & metode pembayaran',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountPage()),
              ),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsCard(
              title: 'Keamanan',
              icon: Icons.lock_outline,
              subtitle: 'Password, autentikasi, dan keamanan',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SecurityPage()),
              ),
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsCard(
              title: 'Preferensi',
              icon: Icons.settings_outlined,
              subtitle: 'Notifikasi, bahasa, tema',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PreferencesPage()),
              ),
              color: Colors.purple,
            ),
            const SizedBox(height: 24),

            // Support Section
            const Text(
              'Dukungan & Informasi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.help_outline, color: Colors.blue, size: 20),
                    ),
                    title: const Text('Pusat Bantuan'),
                    subtitle: const Text('Panduan & FAQ'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buka pusat bantuan')),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.purple, size: 20),
                    ),
                    title: const Text('Tentang Aplikasi'),
                    subtitle: const Text('Versi 1.0.0'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'KosManager',
                      applicationVersion: '1.0.0',
                      applicationIcon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home, color: Colors.white),
                      ),
                      children: const [
                        SizedBox(height: 8),
                        Text('Aplikasi manajemen kos terbaik untuk pengelolaan kost yang efisien dan modern.'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.privacy_tip_outlined, color: Colors.red, size: 20),
                    ),
                    title: const Text('Kebijakan Privasi'),
                    subtitle: const Text('Ketahui bagaimana data Anda dilindungi'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buka kebijakan privasi')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPaymentMethod() async {
    final methods = ['Tidak ada', 'Transfer Bank', 'QRIS', 'Kartu Kredit'];
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih Metode Pembayaran'),
        children: methods.map((m) => SimpleDialogOption(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _paymentMethod == m ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(m),
              ],
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(m),
        )).toList(),
      ),
    );
    if (res != null) setState(() => _paymentMethod = res);
  }
}