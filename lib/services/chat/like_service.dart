/* Like Service

   Handles toggling a like on a chat message.

   Two identities, two paths
   ─────────────────────────
   - Regular users like AS their claimed username. Writes happen
     directly to Firestore — the `likedBy.<username>` map cell and
     a ±1 update to the `likes` counter, both allowed by the
     `isLikeOnlyUpdate()` rule.
   - Admins like AS the "Studio" identity. The write goes through
     the `adminToggleLike` Cloud Function (session-token verified)
     and writes via the Admin SDK, bypassing the ±1 rule clamp.

   The two are independent: an admin who claimed a regular username
   before logging in as admin can have BOTH a personal like and a
   Studio like on the same message. See MessageBubble for how the
   UI picks which one to read/write depending on the viewer's
   current role.

   Atomic toggle via transaction
   ─────────────────────────────
   Two devices logged in as the same identity could in theory race
   and double-count. Both paths use a Firestore transaction (client
   side for users, server side for admins) so the like state and
   counter stay consistent.

   Optimistic UI
   ─────────────
   The caller (MessageBubble) updates its local state immediately
   so the user sees instant feedback, and only reverts if the
   underlying call throws. Most network round-trip latency is
   hidden.
*/

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_check_http.dart';
import 'auth_service.dart';
import 'user_service.dart';

class LikeService {
  LikeService._();
  static final LikeService instance = LikeService._();

  static const _collection = 'chat_messages';

  final _db = FirebaseFirestore.instance;

  // ── Regular-user path ───────────────────────────────────────────────────

  /// Toggles whether the current user's claimed username has liked the
  /// given message.
  ///
  /// Returns the new like state. Throws on failure.
  ///
  /// Requires a claimed username — anonymous readers can't like.
  Future<bool> toggleLike(String messageId) async {
    final username = UserService.instance.username;
    if (username == null || username.isEmpty) {
      throw Exception(
        'Stel eerst een gebruikersnaam in om berichten te liken.',
      );
    }

    final ref = _db.collection(_collection).doc(messageId);

    return _db
        .runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) {
            throw Exception('Bericht bestaat niet meer.');
          }

          final data = snap.data() ?? {};
          final likedBy = (data['likedBy'] as Map<String, dynamic>?) ?? {};
          final currentLikes = (data['likes'] as num?)?.toInt() ?? 0;

          final wasLiked = likedBy[username] == true;
          final newLikes = wasLiked
              ? (currentLikes - 1).clamp(0, 1 << 31)
              : currentLikes + 1;

          tx.update(ref, {
            'likes': newLikes,
            'likedBy.$username': wasLiked ? FieldValue.delete() : true,
          });

          return !wasLiked;
        })
        .catchError((e, st) {
          debugPrint('[LikeService] toggle failed: $e\n$st');
          throw e;
        });
  }

  // ── Admin (Studio) path ─────────────────────────────────────────────────

  /// Toggles whether the Studio identity has liked the given message.
  /// Routed through the `adminToggleLike` Cloud Function so the
  /// session token can be verified server-side. The function writes
  /// via Admin SDK and bypasses the client `isLikeOnlyUpdate` rule
  /// (which is fine — the server is the writer here).
  ///
  /// Returns the new like state. Throws on failure.
  ///
  /// Requires an active admin session (AuthService.isAdmin == true).
  Future<bool> toggleStudioLike(String messageId) async {
    final sessionToken = AuthService.instance.sessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw Exception(
        'Adminsessie is verlopen. Log opnieuw in om als Studio te liken.',
      );
    }

    final response = await AppCheckHttp.post('adminToggleLike', {
      'token': sessionToken,
      'messageId': messageId,
    });

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['liked'] is bool) {
          return body['liked'] as bool;
        }
      } catch (_) {}
      throw Exception('Server gaf geen geldig antwoord. Probeer opnieuw.');
    }
    if (response.statusCode == 401) {
      throw Exception(
        'Adminsessie is verlopen. Log opnieuw in om als Studio te liken.',
      );
    }
    if (response.statusCode == 404) {
      throw Exception('Bericht bestaat niet meer.');
    }
    throw Exception('Like kon niet opgeslagen worden. Probeer opnieuw.');
  }
}
