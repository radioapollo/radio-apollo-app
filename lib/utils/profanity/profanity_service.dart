/* Profanity Service

   Loads the curse-word list from Firestore so the radiostation can
   add or remove words via the Firebase Console without redeploying
   the app.

   How it works
   ────────────
   - On startup, fetch `config/profanity` once. Merge the remote
     lists with the hardcoded fallback in `ProfanityConfig`.
   - Then subscribe to live updates on the same document. Any change
     made in the Firebase Console flows in within a second or two.
   - If Firestore is unreachable (offline first launch, rules
     misconfigured, etc.) the hardcoded list keeps protecting the
     chat — the filter never goes "open".

   Firestore document shape
   ────────────────────────
     config/profanity
       severeWords: [ "extra-slur-1", "extra-slur-2", ... ]
       mildWords:   [ "extra-swear-1", "extra-swear-2", ... ]
       updatedAt:   <server timestamp, optional>

   Both arrays are optional and can be empty. Entries are normalised
   to lowercase + trimmed before being added to the active list.

   The active lists are exposed as static getters so
   `ProfanityFilter` can keep its current synchronous API:

       ProfanityFilter.check('some message')

   No callers had to change.
*/

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'profanity_config.dart';

class ProfanityService {
  ProfanityService._();
  static final ProfanityService instance = ProfanityService._();

  // ── Public state ──────────────────────────────────────────────────────────

  /// Combined list: hardcoded fallback + Firestore additions.
  /// Read by [ProfanityFilter] on every check.
  List<String> get activeSevereWords => _activeSevere;
  List<String> get activeMildWords => _activeMild;

  bool get isInitialised => _initialised;

  // ── Internal state ────────────────────────────────────────────────────────

  static const _docPath = 'config/profanity';

  List<String> _activeSevere = List.unmodifiable(
    ProfanityConfig.allSevereWords,
  );
  List<String> _activeMild = List.unmodifiable(ProfanityConfig.allMildWords);

  bool _initialised = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called once from `main()` after Firebase is up. Returns once the
  /// initial fetch completes (or fails). Live updates continue in the
  /// background after this returns.
  Future<void> init() async {
    if (_initialised) return;

    final ref = FirebaseFirestore.instance.doc(_docPath);

    // 1. One-shot fetch with a short timeout so a slow/offline network
    //    doesn't block app startup. The hardcoded list is already in
    //    place as the fallback.
    try {
      final snap = await ref
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 4));
      _applySnapshot(snap.data());
    } catch (e) {
      debugPrint(
        '[ProfanityService] Initial fetch failed, using hardcoded list: $e',
      );
    }

    // 2. Live updates. Firestore handles reconnects internally — if the
    //    connection drops we'll just continue using the last known
    //    (or hardcoded) list until it comes back.
    _liveSub = ref.snapshots().listen(
      (snap) {
        _applySnapshot(snap.data());
      },
      onError: (e) {
        debugPrint('[ProfanityService] Live updates error: $e');
      },
    );

    _initialised = true;
  }

  /// Stop listening. Mostly for tests — in production this lives for
  /// the entire app lifetime.
  Future<void> dispose() async {
    await _liveSub?.cancel();
    _liveSub = null;
    _initialised = false;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Merge Firestore data into the active lists.
  ///
  /// Strategy: hardcoded list is always present (safety net), and any
  /// extra words from Firestore are appended. Duplicates are removed
  /// automatically by the Set conversion.
  void _applySnapshot(Map<String, dynamic>? data) {
    final remoteSevere = _normalise(data?['severeWords']);
    final remoteMild = _normalise(data?['mildWords']);

    final mergedSevere = <String>{
      ...ProfanityConfig.allSevereWords,
      ...remoteSevere,
    };
    final mergedMild = <String>{
      ...ProfanityConfig.allMildWords,
      ...remoteMild,
    };

    _activeSevere = List.unmodifiable(mergedSevere);
    _activeMild = List.unmodifiable(mergedMild);

    debugPrint(
      '[ProfanityService] Applied lists '
      '(severe: ${_activeSevere.length}, mild: ${_activeMild.length}, '
      'remote-extra: severe=${remoteSevere.length}, mild=${remoteMild.length})',
    );
  }

  /// Coerce a Firestore array field into a clean `List<String>`:
  /// lowercased, trimmed, deduplicated, no empty entries.
  List<String> _normalise(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>{};
    for (final item in raw) {
      if (item is String) {
        final clean = item.trim().toLowerCase();
        if (clean.isNotEmpty) out.add(clean);
      }
    }
    return out.toList(growable: false);
  }
}