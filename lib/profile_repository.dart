import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_model.dart';

class ProfileRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User chưa đăng nhập');
    }
    return user.uid;
  }

  Future<ProfileModel> loadProfile() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    return ProfileModel.fromMap(doc.data());
  }

  Future<void> saveProfile(ProfileModel profile) async {
    await _firestore.collection('users').doc(_uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateField(String key, dynamic value) async {
    await _firestore.collection('users').doc(_uid).set(
      {key: value},
      SetOptions(merge: true),
    );
  }
}