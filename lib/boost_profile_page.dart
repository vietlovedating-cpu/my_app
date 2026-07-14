import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BoostProfilePage extends StatefulWidget {
  final String languageCode;

  const BoostProfilePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<BoostProfilePage> createState() => _BoostProfilePageState();
}

class _BoostProfilePageState extends State<BoostProfilePage> {
  bool _isLoading = false;

  bool get isVi => widget.languageCode == 'vi';

  Future<void> _activateBoost() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'isBoosted': true,
        'boostStartedAt': FieldValue.serverTimestamp(),
        'boostExpiresAt': Timestamp.fromDate(expiresAt),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Hồ sơ của bạn đã được Boost trong 1 giờ.'
                : 'Your profile has been boosted for 1 hour.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không thể bật Boost. Vui lòng thử lại.'
                : 'Could not activate Boost. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F1),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        title: Text(
          isVi ? 'Boost hồ sơ' : 'Profile Boost',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD76A),
                        Color(0xFFE9A91A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  isVi
                      ? 'Bạn có muốn làm nổi bật hồ sơ của mình trong vòng 1 giờ không?'
                      : 'Would you like to highlight your profile for 1 hour?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isVi
                      ? 'Hồ sơ của bạn sẽ được ưu tiên hiển thị trên trang Khám phá.'
                      : 'Your profile will receive priority placement on Discover.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _activateBoost,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bolt_rounded),
                    label: Text(
                      isVi ? 'Bật Boost trong 1 giờ' : 'Boost for 1 hour',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE9A91A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}