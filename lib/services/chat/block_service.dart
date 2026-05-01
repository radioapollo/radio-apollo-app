/* Block Service

   Lets the user hide all messages from a chosen username, locally
   and persistently.

   Blocking is a client-side feature: the blocked user's messages
   continue to be written to Firestore (the studio admin still
   sees them), but the blocking user simply never renders them.
   The block list is stored in SharedPreferences as a JSON-encoded
   array of lowercase usernames so it survives app restarts.

   Why client-side?
   ────────────────
   - We can't ban users globally — that's the admin's job via the
     report flow. Local blocking gives the user immediate control
     over what they see, which is what App Store Guideline 1.2
     specifically requires.
   - Comparison is case-insensitive: usernames are stored and
     looked up in lowercase form.

   Notify listeners
   ────────────────
   The service exposes a [Listenable] (via [ChangeNotifier]) so
   the chat list can rebuild when a block/unblock happens without
   waiting for the next Firestore snapshot.
*/

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockService extends ChangeNotifier {
  BlockService._();
  static final BlockService instance = BlockService._();

  static const _key = 'chat_blocked_usernames';

  Set<String> _blocked = <String>{};
  bool _initialised = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isInitialised => _initialised;

  /// Read-only view of the current block list (lowercase).
  Set<String> get blocked => Set.unmodifiable(_blocked);

  bool isBlocked(String? username) {
    if (username == null || username.isEmpty) return false;
    return _blocked.contains(username.toLowerCase());
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _blocked = decoded
            .whereType<String>()
            .map((s) => s.toLowerCase())
            .toSet();
      }
    } catch (_) {
      // Corrupted entry — drop it silently.
      await prefs.remove(_key);
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> block(String username) async {
    final normalised = username.trim().toLowerCase();
    if (normalised.isEmpty) return;
    if (_blocked.contains(normalised)) return;

    _blocked.add(normalised);
    await _persist();
    notifyListeners();
  }

  Future<void> unblock(String username) async {
    final normalised = username.trim().toLowerCase();
    if (!_blocked.remove(normalised)) return;
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    if (_blocked.isEmpty) return;
    _blocked.clear();
    await _persist();
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_blocked.toList()));
  }
}