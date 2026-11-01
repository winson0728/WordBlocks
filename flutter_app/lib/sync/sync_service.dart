import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/review_store.dart';

/// Supabase project settings from assets/sync.json (generated from config/sync.json).
/// Sync stays off while either value is empty.
class SyncConfig {
  const SyncConfig(this.url, this.key);
  final String url;
  final String key;

  bool get enabled => url.isNotEmpty && key.isNotEmpty;

  static Future<SyncConfig> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/sync.json', cache: false)) as Map<String, dynamic>;
      return SyncConfig(j['supabaseUrl'] as String? ?? '', j['supabaseKey'] as String? ?? '');
    } catch (_) {
      return const SyncConfig('', '');
    }
  }
}

enum SyncStatus { off, signedOut, syncing, synced, error }

/// Keeps review progress in step with the user's other devices.
///
/// Progress is one JSON document per user in the `progress` table (see supabase/schema.sql).
/// Every sync pulls it, merges it into the device copy with [mergeProgress] (newer card wins,
/// study days are combined, counters keep the larger value), and writes the result back.
class SyncService extends ChangeNotifier {
  SyncService(this.config, this.store);

  final SyncConfig config;
  final ReviewStore store;

  SyncStatus status = SyncStatus.off;
  String? message;
  DateTime? lastSynced;
  Timer? _debounce;
  bool _importing = false;
  StreamSubscription<AuthState>? _authSub;

  GoTrueClient get _auth => Supabase.instance.client.auth;
  String? get email => config.enabled ? _auth.currentUser?.email : null;

  Future<void> start() async {
    if (!config.enabled) return;
    try {
      await Supabase.initialize(url: config.url, publishableKey: config.key);
    } catch (e) {
      _set(SyncStatus.error, '無法連線到同步服務：$e');
      return;
    }
    _authSub = _auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn) unawaited(syncNow());
      if (s.event == AuthChangeEvent.signedOut) _set(SyncStatus.signedOut, null);
    });
    store.addListener(_onLocalChange);
    if (_auth.currentUser == null) {
      _set(SyncStatus.signedOut, null);
    } else {
      await syncNow();
    }
  }

  void _onLocalChange() {
    if (_importing || !config.enabled || _auth.currentUser == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), syncNow);
  }

  Future<void> syncNow() async {
    final user = config.enabled ? _auth.currentUser : null;
    if (user == null) return;
    _set(SyncStatus.syncing, null);
    try {
      final db = Supabase.instance.client;
      final row = await db.from('progress').select('data').eq('user_id', user.id).maybeSingle();
      final remote = Map<String, dynamic>.from(row?['data'] as Map? ?? const {});
      _importing = true;
      store.importProgress(remote);
      _importing = false;
      final local = store.exportProgress();
      if (jsonEncode(local) != jsonEncode(mergeProgress(remote, const {}))) {
        await db.from('progress').upsert({
          'user_id': user.id,
          'data': local,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      lastSynced = DateTime.now();
      _set(SyncStatus.synced, null);
    } catch (e) {
      _importing = false;
      _set(SyncStatus.error, '同步失敗，稍後會再試：$e');
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) => _guard(() async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  /// Returns an error message, or a note asking the user to confirm their email.
  Future<String?> signUp(String email, String password) async {
    String? note;
    final err = await _guard(() async {
      final r = await _auth.signUp(email: email.trim(), password: password);
      if (r.session == null) note = '已寄出確認信到 ${email.trim()}。點信中的連結後，回來這裡登入。';
    });
    return err ?? note;
  }

  Future<void> signOut() async {
    if (!config.enabled) return;
    await _auth.signOut();
  }

  Future<String?> _guard(Future<void> Function() f) async {
    if (!config.enabled) return '同步尚未設定';
    try {
      await f();
      return null;
    } on AuthException catch (e) {
      return switch (e.code) {
        'invalid_credentials' => 'Email 或密碼不正確。',
        'email_not_confirmed' => '請先點確認信中的連結，再登入。',
        'user_already_exists' => '這個 Email 已經註冊過了，請直接登入。',
        'weak_password' => '密碼太短，至少需要 6 個字元。',
        _ => e.message,
      };
    } catch (e) {
      return '連線失敗：$e';
    }
  }

  void _set(SyncStatus s, String? m) {
    status = s;
    message = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _authSub?.cancel();
    store.removeListener(_onLocalChange);
    super.dispose();
  }
}
