import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kos_app/app/app.dart';
import 'package:kos_app/app/supabase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pastikan data lokal untuk formatting tanggal diinisialisasi
  // terutama diperlukan pada platform web (Chrome) untuk menghindari
  // LocaleDataException: call initializeDateFormatting() first
  await initializeDateFormatting('id_ID');

  // Load .env from bundled Flutter asset
  await dotenv.load(fileName: 'lib/assets/.env');


  // Koneksi Supabase
  await initSupabase();

  runApp(const KosApp());
}


