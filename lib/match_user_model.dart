class MatchUserModel {
  final String matchId;
  final String chatId;
  final String otherUserId;
  final String firstName;
  final int age;
  final String photoUrl;

  MatchUserModel({
    required this.matchId,
    required this.chatId,
    required this.otherUserId,
    required this.firstName,
    required this.age,
    required this.photoUrl,
  });
}