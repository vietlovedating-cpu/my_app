import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'intro_question_page.dart';
import 'phone_verification_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyEmailPage extends StatefulWidget {
  final String languageCode;
  final String firstName;

  const VerifyEmailPage({
    super.key,
    required this.languageCode,
    required this.firstName,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _timer;
  bool isLoading = false;
  bool isChecking = false;
  bool hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    if (isChecking || hasNavigated) return;
    isChecking = true;

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        hasNavigated = true;
        _timer?.cancel();
await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'emailVerified': true,
    'onboardingStep': 'phone_verification',
  }, SetOptions(merge: true));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PhoneVerificationPage(
              firstName: widget.firstName,
              languageCode: widget.languageCode,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Check email verified error: $e');
    } finally {
      isChecking = false;
    }
  }

  Future<void> _resendEmail() async {
    final isVi = widget.languageCode == 'vi';

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Đã gửi lại email xác minh. Vui lòng kiểm tra cả Spam.'
                : 'Verification email sent again. Please also check Spam.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không thể gửi lại email xác minh'
                : 'Could not resend verification email',
          ),
        ),
      );
    }
  }

  Future<void> _manualCheck() async {
    final isVi = widget.languageCode == 'vi';

    setState(() {
      isLoading = true;
    });

    await _checkEmailVerified();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Email chưa được xác minh. Vui lòng kiểm tra lại.'
                : 'Email is not verified yet. Please check again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        title: Text(isVi ? 'Xác minh Email' : 'Verify Email'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 100,
                color: Colors.pink,
              ),
              const SizedBox(height: 24),
              Text(
                isVi
                    ? 'Chúng tôi đã gửi email xác minh cho bạn'
                    : 'We have sent you a verification email',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isVi
                    ? 'Vui lòng kiểm tra hộp thư đến và cả thư mục Spam.\n\nSau khi xác minh xong, ứng dụng sẽ tự động chuyển sang bước tiếp theo.'
                    : 'Please check your inbox and Spam folder.\n\nAfter verification, the app will automatically continue to the next step.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _resendEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink,
                    side: const BorderSide(color: Colors.pink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(isVi ? 'Gửi lại email' : 'Resend Email'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _manualCheck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isVi ? 'Tôi đã xác minh' : 'I have verified',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}