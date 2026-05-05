/* Like Service

   Handles toggling a like on a chat message.

   Direct Firestore write
   ──────────────────────
   Unlike message creation (which goes through Cloud Functions for
   App Check + rate limiting + profanity), likes are written directly
   from the client. Two reasons:

   1. The fields involved are bounded — only `likes` (counter) and
      `likedBy.{username}` (boolean) — and Firestore security rules
      can constrain the update to exactly that shape.
   2. A like has no spam vector worth a Cloud Function: dedup happens
      at the username level via the `likedBy` map, which only the
      owner of that username can write to (rules enforce this via
      claim token verification).

   Atomic toggle via transaction
   ─────────────────────────────
   Two devices logged in as the same username could in theory race
   and double-count. We wrap the read + write in a transaction so
   the like state and counter stay consistent.

   Optimistic UI
   ─────────────
   The caller (MessageBubble) updates its local state immediately
   so the user sees instant feedback, and only reverts if the
   transaction throws. Most network round-trip latency is hidden.
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';

class LikeService {
  LikeService._();
  static final LikeService instance = LikeService._();

  static const _collection = 'chat_messages';

  final _db = FirebaseFirestore.instance;

  /// Toggles whether the current user has liked the given message.
  ///
  /// Returns the new like state (`true` if now liked, `false` if now
  /// unliked) on success. Throws on failure.
  ///
  /// Requires a username — anonymous readers can't like.
  Future<bool> toggleLike(String messageId) async {
    final username = UserService.instance.username;
    if (username == null || username.isEmpty) {
      throw Exception(
        'Stel eerst een gebruikersnaam in om berichten te liken.',
      );
    }

    final ref = _db.collection(_collection).doc(messageId);

    return _db.runTransaction<bool>((tx) async {
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
    }).catchError((e, st) {
      debugPrint('[LikeService] toggle failed: $e\n$st');
      throw e;
    });
  }
}