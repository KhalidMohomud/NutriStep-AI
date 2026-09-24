import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection, from `--dart-define-from-file=env.json` (see env.example.json).
///
/// Without those values the app runs in demo mode: everything in memory, no
/// account, nothing persisted — so the UI can still be run and designed on.
const _url = String.fromEnvironment('SUPABASE_URL');
const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

const backendEnabled = _url != '' && _publishableKey != '';

/// Google Cloud OAuth client IDs (not secrets). The web one is what Supabase
/// verifies the ID token against; iOS also needs its own.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

Future<void> initBackend() async {
  if (!backendEnabled) return;
  await Supabase.initialize(url: _url, publishableKey: _publishableKey);
}

SupabaseClient get supabase => Supabase.instance.client;
