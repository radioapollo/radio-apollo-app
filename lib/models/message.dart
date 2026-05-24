/* Message Model

   This file defines the structure of a chat message.

   Core fields:
   - id              Firestore document id (used for replies/reports/likes)
   - role            'user' | 'admin' | 'studio'
   - text            the message body
   - time            formatted HH:mm string
   - username        sender display name
   - isCurrentUser   whether this device sent it

   Roles:
   - 'user'   : a regular chatter, white bubble, their claimed name
   - 'admin'  : the moderator, orange bubble, posts as "Radio Apollo"
   - 'studio' : the presenters' PC account, green bubble, posts as "Studio";
                posts/replies like a user but has no moderation powers

   Engagement fields (added with chat actions feature):
   - likes           total like count
   - likedByMe       whether the local user's regular username liked it
   - likedByAdmin    whether the ADMIN station identity liked it; keyed
                     under `likedBy.adminLike`
   - likedByStudio   whether the STUDIO station identity liked it; keyed
                     under `likedBy.studioLike`

     Admin and studio are SEPARATE like identities — both can like the
     same message at once (count reaches 2), and one logging out doesn't
     remove the other's like. Both are independent from a regular user's
     like, which is keyed under `likedBy.<username>`. The key names start
     with a letter and don't match Firestore's reserved __.*__ pattern,
     so they never collide with a username or get rejected by Firestore.

   - replyCount      number of replies pointing at this message
   - replyTo         small embedded snapshot of the message being replied
                     to, if any. We embed instead of resolving by id so a
                     deleted parent still leaves the reply readable.

   ─── Testability ───────────────────────────────────────────────────────────
   `fromFirestoreData` is a pure function over a plain Dart map so the
   doc-to-model mapping can be unit-tested without standing up a full
   Firestore stack. ChatService._mapSnapshotToMessages delegates the
   per-doc work to this factory.
*/

class ReplyPreview {
  final String? messageId;
  final String username;
  final String textPreview;

  const ReplyPreview({
    this.messageId,
    required this.username,
    required this.textPreview,
  });

  /// Parses a `replyTo` map as stored on a Firestore chat message.
  /// Returns null when the input is missing, not a map, or doesn't
  /// have at least a parsable shape.
  static ReplyPreview? fromMap(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ReplyPreview(
      messageId: raw['messageId'] as String?,
      username: (raw['username'] as String?) ?? 'Onbekend',
      textPreview: (raw['textPreview'] as String?) ?? '',
    );
  }
}

class Message {
  final String? id;
  final String role;
  final String text;
  final String time;
  final String? username;
  final bool isCurrentUser;

  final int likes;
  final bool likedByMe;
  final bool likedByAdmin;
  final bool likedByStudio;
  final int replyCount;
  final ReplyPreview? replyTo;

  const Message({
    this.id,
    required this.role,
    required this.text,
    required this.time,
    this.username,
    this.isCurrentUser = false,
    this.likes = 0,
    this.likedByMe = false,
    this.likedByAdmin = false,
    this.likedByStudio = false,
    this.replyCount = 0,
    this.replyTo,
  });

  /// Builds a Message from the raw Firestore document data.
  ///
  /// Defensive against missing or malformed fields: a doc with no
  /// `text`, `role`, or `username` still parses (with fallback
  /// strings) rather than throwing.
  factory Message.fromFirestoreData({
    required String docId,
    required Map<String, dynamic> data,
    required String time,
    required String? localUsername,
    required bool isAdminViewer,
  }) {
    final role = data['role'] as String? ?? 'user';
    final username = data['username'] as String? ?? 'Onbekend';

    final likes = (data['likes'] as num?)?.toInt() ?? 0;
    final likedByMap = (data['likedBy'] as Map<String, dynamic>?) ?? const {};
    final likedByMe =
        localUsername != null && likedByMap[localUsername] == true;
    // Station likes live under dedicated keys (see the adminToggleLike
    // Cloud Function). They start with a letter and don't match
    // Firestore's reserved __.*__ field pattern, so they're safe and
    // never collide with a username.
    final likedByAdmin = likedByMap['adminLike'] == true;
    final likedByStudio = likedByMap['studioLike'] == true;
    final replyCount = (data['replyCount'] as num?)?.toInt() ?? 0;

    final replyTo = ReplyPreview.fromMap(data['replyTo']);

    return Message(
      id: docId,
      role: role,
      text: data['text'] as String? ?? '',
      time: time,
      username: username,
      // Only a regular 'user' message sent under the local user's own
      // claimed name renders as "mine" (blue, right-aligned). Privileged
      // viewers (admin/studio) see everything as "other", and admin /
      // studio role messages are never "mine".
      isCurrentUser:
          !isAdminViewer &&
          localUsername != null &&
          username == localUsername &&
          role == 'user',
      likes: likes,
      likedByMe: likedByMe,
      likedByAdmin: likedByAdmin,
      likedByStudio: likedByStudio,
      replyCount: replyCount,
      replyTo: replyTo,
    );
  }
}
