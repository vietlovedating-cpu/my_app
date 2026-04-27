import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String languageCode;

  const ForgotPasswordPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? 'Quên mật khẩu' : 'Forgot Password'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Khôi phục mật khẩu' : 'Reset Password',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVi
                      ? 'Nhập email để nhận hướng dẫn đặt lại mật khẩu'
                      : 'Enter your email to receive password reset instructions',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Email',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isVi
                          ? 'Vui lòng nhập email'
                          : 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return isVi ? 'Email không hợp lệ' : 'Invalid email';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: isVi ? 'Nhập email của bạn' : 'Enter your email',
                    filled: true,
                    fillColor: const Color(0xFFFFF7FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFFD6E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.pink,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;

                      final email = emailController.text.trim();

                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isVi
                                  ? 'Link đặt lại mật khẩu đã được gửi. Vui lòng kiểm tra email và spam.'
                                  : 'Password reset link sent. Please check your email and spam folder.',
                            ),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        String message;

                        if (e.code == 'user-not-found') {
                          message = isVi
                              ? 'Không tìm thấy tài khoản với email này.'
                              : 'No account found with this email.';
                        } else if (e.code == 'invalid-email') {
                          message =
                              isVi ? 'Email không hợp lệ.' : 'Invalid email.';
                        } else {
                          message = isVi
                              ? 'Không gửi được link. Vui lòng thử lại.'
                              : 'Could not send reset link. Please try again.';
                        }

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isVi ? 'Gửi liên kết' : 'Send Reset Link',
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