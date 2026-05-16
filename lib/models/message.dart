/* Message Model

   This file defines the structure of a chat message.

   Core fields:
   - id              Firestore document id (used for replies/reports/likes)
   - role            'user' or 'admin'
   - text            the message body
   - time            formatted HH:mm string
   - username        sender display name
   - isCurrentUser   whether this device sent it

   Engagement fields (added with chat actions feature):
   - likes           total like count
   - likedByMe       whether the local user has liked this message
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
    this.replyCount = 0,
    this.replyTo,
  });

  /// Builds a Message from the raw Firestore document data.
  ///
  /// Defensive against missing or malformed fields: a doc with no
  /// `text`, `role`, or `username` still parses (with fallback
  /// strings) rather than throwing. This matters because Firestore
  /// docs can drift from the expected shape over time, and a single
  /// malformed message must not crash the entire chat list.
  ///
  /// `localUsername` and `isAdminViewer` are passed in (rather than
  /// read from a global) so the factory stays pure and testable.
  /// The caller is responsible for formatting [time] from the
  /// timestamp field before calling.
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
    final replyCount = (data['replyCount'] as num?)?.toInt() ?? 0;

    final replyTo = ReplyPreview.fromMap(data['replyTo']);

    return Message(
      id: docId,
      role: role,
      text: data['text'] as String? ?? '',
      time: time,
      username: username,
      isCurrentUser:
          !isAdminViewer &&
          localUsername != null &&
          username == localUsername &&
          role != 'admin',
      likes: likes,
      likedByMe: likedByMe,
      replyCount: replyCount,
      replyTo: replyTo,
    );
  }
}
