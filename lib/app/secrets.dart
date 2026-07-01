import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String v(String key) => dotenv.env[key] ?? '';
}

