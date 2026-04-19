import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_user_model.dart';

class MatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<MatchUserModel>> streamMatches(String currentUserId) {
    return _firestore
        .collection('matches')
        .where('users', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<MatchUserModel> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final users = List<String>.from(data['users'] ?? []);
        final chatId = data['chatId'] as String? ?? '';

        final otherUserId = users.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        final otherUserSnap =
            await _firestore.collection('users').doc(otherUserId).get();

        if (!otherUserSnap.exists) continue;

        final otherData = otherUserSnap.data() ?? {};

        results.add(
          MatchUserModel(
            matchId: doc.id,
            chatId: chatId,
            otherUserId: otherUserId,
            firstName: (otherData['firstName'] ?? '').toString(),
            age: (otherData['age'] ?? 0) is int
                ? otherData['age']
                : int.tryParse('${otherData['age']}') ?? 0,
            photoUrl: (otherData['photoUrl'] ?? '').toString(),
          ),
        );
      }

      return results;
    });
  }
}