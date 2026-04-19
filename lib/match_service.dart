import 'package:cloud_firestore/cloud_firestore.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Dùng CHUNG cho matchId và chatId
  String _buildCommonId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> createMatchIfNeeded({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final commonId = _buildCommonId(currentUserId, otherUserId);

    final matchRef = _firestore.collection('matches').doc(commonId);
    final chatRef = _firestore.collection('chats').doc(commonId);

    await _firestore.runTransaction((transaction) async {
      final matchSnap = await transaction.get(matchRef);

      /// Nếu chưa có match → tạo mới
      if (!matchSnap.exists) {
        transaction.set(matchRef, {
          'users': [currentUserId, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'chatId': commonId, // dùng chung ID
        });
      }

      /// Nếu chưa có chat → tạo chat
      final chatSnap = await transaction.get(chatRef);

      if (!chatSnap.exists) {
        transaction.set(chatRef, {
          'participants': [currentUserId, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}