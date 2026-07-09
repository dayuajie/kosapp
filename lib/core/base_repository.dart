import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth
    show AuthException;
import '../../core/connectivity_service.dart';
import '../../core/exceptions.dart';

mixin BaseRepository {
  final ConnectivityService _connectivity = ConnectivityService();
  Future<T> safeCall<T>(
    Future<T> Function() operation, {
    String? fallbackMessage,
  }) async {
    // 1. Cek koneksi
    if (!await _connectivity.hasInternet()) {
      throw NetworkException('Tidak ada koneksi internet. Periksa jaringan Anda.');
    }

    try {
      return await operation();
    } on SocketException {
      throw NetworkException('Koneksi terputus. Periksa jaringan Anda.');
    } on TimeoutException {
      throw NetworkException('Server terlalu lama merespons. Coba lagi nanti.');
    } on PostgrestException catch (e) {
      // Map error Supabase ke DataException
      final userMessage = _mapPostgrestError(e);
      throw DataException(userMessage);
    } on supabase_auth.AuthException {
      // AuthException asli dari Supabase (mis. gagal update auth/login)
      rethrow;
    } on AuthException {
      // AuthException custom kita (mis. validasi "Anda belum login")
      rethrow;
    } catch (e) {
      // Log error asli (bisa ke console atau crashlytics)
      print('Unhandled repository error: $e');
      throw UnexpectedException(
        fallbackMessage ?? 'Terjadi kesalahan tak terduga. Coba lagi nanti.',
      );
    }
  }

  String _mapPostgrestError(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return 'Data sudah ada. Periksa kembali input Anda.';
      case '23503':
        return 'Data terkait tidak ditemukan.';
      case 'PGRST301':
        return 'Tidak dapat terhubung ke server. Coba lagi nanti.';
      default:
        return e.message; // Supabase secara default mengembalikan string kosong/pesan bawaan jika null
    }
  }

  Future<bool> checkConnectivity() async => await _connectivity.hasInternet();
}