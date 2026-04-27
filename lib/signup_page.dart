import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'terms_page.dart';
import 'privacy_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_email_page.dart';

class SignUpPage extends StatefulWidget {
  final String languageCode;

  const SignUpPage({
    super.key,
    required this.languageCode,
  });


  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();

  bool isChecked = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  late String languageCode;

bool get isVi => languageCode == 'vi';
@override
void initState() {
  super.initState();
  languageCode = widget.languageCode;
}

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameController.dispose();
    surnameController.dispose();
    super.dispose();
  }
Future<void> _changeLanguage(String lang) async {
  if (languageCode == lang) return;
  setState(() {
    languageCode = lang;
  });

  await MyApp.of(context)?.changeLanguage(lang);
}
  Future<void> _showEmailAlreadyExistsDialog(bool isVi) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isVi ? 'Email đã tồn tại' : 'Email already exists'),
        content: SingleChildScrollView(
          child: Text(
            isVi
                ? 'Email này đã được đăng ký nhưng có thể chưa xác minh.\n\nBạn có muốn gửi lại email xác minh không?\n\nVui lòng kiểm tra cả hộp Spam nếu không thấy email.'
                : 'This email is already registered but may not be verified.\n\nDo you want to resend the verification email?\n\nPlease also check your Spam folder if you do not see the email.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                );

                await FirebaseAuth.instance.currentUser
                    ?.sendEmailVerification();

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

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerifyEmailPage(
                      languageCode: languageCode,
                      firstName: firstNameController.text.trim(),
                    ),
                  ),
                );
              } catch (_) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isVi
                          ? 'Không thể gửi lại email. Có thể mật khẩu chưa đúng.'
                          : 'Could not resend the verification email. The password may be incorrect.',
                    ),
                  ),
                );
              }
            },
            child: Text(isVi ? 'Gửi lại' : 'Resend'),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    final isVi = languageCode == 'vi';
    if (!_formKey.currentState!.validate()) return;

    if (!isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Bạn phải đồng ý Điều khoản và Chính sách quyền riêng tư'
                : 'You must agree to the Terms & Privacy Policy',
          ),
        ),
      );
      return;
    }

    final auth = FirebaseAuth.instance;

    try {
     final userCredential = await auth.createUserWithEmailAndPassword(
  email: emailController.text.trim(),
  password: passwordController.text.trim(),
);

final user = userCredential.user;

if (user != null) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'uid': user.uid,
   'email': emailController.text.trim(),
    'firstName': firstNameController.text.trim(),
    'surname': surnameController.text.trim(),


    'profileCompleted': false,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
      await auth.currentUser?.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Đăng ký thành công. Vui lòng kiểm tra email để xác minh tài khoản. Hãy kiểm tra cả Spam.'
                : 'Sign up successful. Please check your email to verify your account. Please also check Spam.',
          ),
        ),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            languageCode: languageCode,
            firstName: firstNameController.text.trim(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _showEmailAlreadyExistsDialog(isVi);
        return;
      }

      String message;

      if (e.code == 'weak-password') {
        message = isVi ? 'Mật khẩu quá yếu' : 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = isVi ? 'Email không hợp lệ' : 'Invalid email';
      } else {
        message = isVi ? 'Đăng ký thất bại' : 'Sign up failed';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Đã có lỗi xảy ra' : 'Something went wrong',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? 'Đăng ký' : 'Sign Up'),
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
                Align(
  alignment: Alignment.topRight,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () => _changeLanguage('vi'),
        child: Text(
          'Tiếng Việt',
          style: TextStyle(
            color: languageCode == 'vi' ? Colors.pink : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      TextButton(
        onPressed: () => _changeLanguage('en'),
        child: Text(
          'English',
          style: TextStyle(
            color: languageCode == 'en' ? Colors.pink : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
),
const SizedBox(height: 20),
                Text(
                  isVi ? 'Tạo tài khoản' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVi
                      ? 'Vui lòng điền đầy đủ thông tin bên dưới'
                      : 'Please fill in all the information below',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: emailController,
                  label: isVi ? 'Email' : 'Email',
                  hint: isVi ? 'Nhập email của bạn' : 'Enter your email',
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
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: passwordController,
                  label: isVi ? 'Mật khẩu' : 'Password',
                  hint: isVi ? 'Nhập mật khẩu' : 'Enter your password',
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isVi
                          ? 'Vui lòng nhập mật khẩu'
                          : 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return isVi
                          ? 'Mật khẩu phải có ít nhất 6 ký tự'
                          : 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: confirmPasswordController,
                  label: isVi ? 'Xác nhận mật khẩu' : 'Confirm Password',
                  hint: isVi ? 'Nhập lại mật khẩu' : 'Re-enter your password',
                  obscureText: obscureConfirmPassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isVi
                          ? 'Vui lòng xác nhận mật khẩu'
                          : 'Please confirm your password';
                    }
                    if (value != passwordController.text) {
                      return isVi
                          ? 'Mật khẩu xác nhận không khớp'
                          : 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: firstNameController,
                  label: isVi ? 'Tên' : 'First Name',
                  hint: isVi ? 'Nhập tên của bạn' : 'Enter your first name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isVi
                          ? 'Vui lòng nhập tên'
                          : 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: surnameController,
                  label: isVi ? 'Họ' : 'Surname',
                  hint: isVi ? 'Nhập họ của bạn' : 'Enter your surname',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isVi
                          ? 'Vui lòng nhập họ'
                          : 'Please enter your surname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: Colors.pink,
                      onChanged: (value) {
                        setState(() {
                          isChecked = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            Text(
                              isVi ? 'Tôi đồng ý với ' : 'I agree to the ',
                              style: const TextStyle(fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TermsPage(
                                      languageCode: languageCode,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                isVi
                                    ? 'Điều khoản sử dụng'
                                    : 'Terms & Conditions',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              isVi ? ' và ' : ' and ',
                              style: const TextStyle(fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PrivacyPage(
                                      languageCode: languageCode,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                isVi
                                    ? 'Chính sách quyền riêng tư'
                                    : 'Privacy Policy',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(isVi ? 'Đăng ký' : 'Sign Up'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
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
              borderSide: const BorderSide(color: Colors.pink, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}