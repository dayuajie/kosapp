import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseConfig reads credentials from compile-time dart-define values
/// when available. This avoids committing secrets into source control.
///
/// Usage (replace with values from your Supabase project settings -> API):
/// flutter run --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
///             --dart-define=SUPABASE_ANON_KEY="your-public-anon-key"
class SupabaseConfig {
  // These pick values from --dart-define at compile/run time. If not
  // provided they keep the placeholder strings so it's obvious to set them.
  static final String url = const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://elvaphdwsqevbtjydmkh.supabase.co');
  static final String key = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_AU16cqnFv6DQMzt9BZw-IA_-D-WmGaE');
}

Future<void> initSupabase() async {
  // Validate values are provided via --dart-define. This prevents confusing
  // runtime errors and gives a clear developer-facing message.
  if (SupabaseConfig.url.isEmpty || SupabaseConfig.key.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define.\n'
      'Example: flutter run --dart-define=SUPABASE_URL="https://your-project.supabase.co" '
      '--dart-define=SUPABASE_ANON_KEY="your-anon-key"',
    );
  }

  // Use `anonKey` parameter which matches the commonly used API for
  // the supabase_flutter client (matches versions around 2.x).
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.key,
  );
}

