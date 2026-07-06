import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/supabase_kos_repository.dart';


class AddKosBottomSheet {
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddKosBottomSheetContent(),
    );
  }
}

class _AddKosBottomSheetContent extends StatefulWidget {
  const _AddKosBottomSheetContent();

  @override
  State<_AddKosBottomSheetContent> createState() =>
      _AddKosBottomSheetContentState();
}

class _AddKosBottomSheetContentState
    extends State<_AddKosBottomSheetContent> {
  static const Color _primaryColor = Color(0xFF6D5EF6);

  final _kosRepo = SupabaseKosRepository();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _capacityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor:
            isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final capRaw = _capacityCtrl.text.trim();

    if (name.isEmpty || address.isEmpty || phone.isEmpty || capRaw.isEmpty) {
      _showSnack('Semua field wajib diisi', isSuccess: false);
      return;
    }
    final capacity = int.tryParse(capRaw);
    if (capacity == null || capacity <= 0) {
      _showSnack('Jumlah kamar tidak valid', isSuccess: false);
      return;
    }
    final ownerId = _kosRepo.currentUserId;
    if (ownerId == null || ownerId.isEmpty) {
      _showSnack('Belum login', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final kosId = await _kosRepo.createKos(
        name: name,
        address: address,
        phone: phone,
        capacities: capRaw,
        ownerId: ownerId,
      );

      await _kosRepo.switchActiveKos(kosId);

      if (!mounted) return;
      Navigator.pop(context, {
        'id': kosId,
        'name': name,
        'address': address,
        'phone': phone,
        'capacities': capRaw,
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        alignLabelWithHint: maxLines > 1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_home_work_rounded,
                      color: _primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftarkan Kos Baru',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Isi detail properti kos Anda',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildField(
              controller: _nameCtrl,
              label: 'Nama Kos',
              hint: 'Kos Ananda Jaya',
              icon: Icons.home_work_rounded,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _addressCtrl,
              label: 'Alamat Lengkap',
              hint: 'Jl. Ngesrep Timur V No.12, Banyumanik...',
              icon: Icons.location_on_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _phoneCtrl,
              label: 'Nomor Telepon',
              hint: '08xxxxxxxxxx',
              icon: Icons.phone_outlined,
              inputType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _capacityCtrl,
              label: 'Jumlah Kamar',
              hint: 'Contoh: 12',
              icon: Icons.meeting_room_rounded,
              inputType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Batal',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Daftarkan Kos',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}