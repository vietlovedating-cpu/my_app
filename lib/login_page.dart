import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'main.dart';


class LoginPage extends StatefulWidget {
  final String? initialLanguageCode;

  const LoginPage({
    super.key,
    this.initialLanguageCode,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool rememberMe = false;
  late String languageCode;

  bool get isVi => languageCode == 'vi';

  bool get showAppleButton =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    languageCode = widget.initialLanguageCode ?? 'vi';
    _loadSavedLogin();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _changeLanguage(String lang) async {
  if (languageCode == lang) return;

  setState(() {
    languageCode = lang;
  });

  await MyApp.of(context)?.changeLanguage(lang);
}

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;

    if (!mounted) return;

    setState(() {
      rememberMe = remember;
      if (remember) {
        emailController.text = prefs.getString('saved_email') ?? '';
        passwordController.text = prefs.getString('saved_password') ?? '';
      }
    });
  }

  Future<void> _saveLoginIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_email', emailController.text.trim());
      await prefs.setString('saved_password', passwordController.text.trim());
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    }
  }

  Future<void> _clearSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
  }
  Future<void> _saveFcmToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    print('FCM USER: ${user?.uid}');

    if (user == null) return;

    final permission = await FirebaseMessaging.instance.requestPermission();

    print('FCM PERMISSION: ${permission.authorizationStatus}');

    final fcmToken = await FirebaseMessaging.instance.getToken();

    print('LOGIN FCM TOKEN: $fcmToken');

    if (fcmToken == null) {
      print('FCM TOKEN IS NULL');
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'fcmToken': fcmToken,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('FCM TOKEN SAVED');
  } catch (e) {
    print('SAVE FCM ERROR: $e');
  }
}

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _saveLoginIfNeeded();
await _saveFcmToken();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            key: ValueKey(
              'home_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}_$languageCode',
            ),
            languageCode: languageCode,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = isVi
              ? 'Không tìm thấy tài khoản với email này.'
              : 'No user found for this email.';
          break;
        case 'wrong-password':
          message = isVi ? 'Sai mật khẩu.' : 'Wrong password.';
          break;
        case 'invalid-email':
          message = isVi ? 'Email không hợp lệ.' : 'Invalid email.';
          break;
        case 'invalid-credential':
          message = isVi
              ? 'Email hoặc mật khẩu không đúng.'
              : 'Incorrect email or password.';
          break;
        case 'user-disabled':
          message = isVi
              ? 'Tài khoản này đã bị vô hiệu hóa.'
              : 'This account has been disabled.';
          break;
        default:
          message = isVi
              ? 'Đăng nhập thất bại: ${e.message ?? e.code}'
              : 'Login failed: ${e.message ?? e.code}';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Có lỗi xảy ra: $e' : 'Something went wrong: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
Future<void> _loginWithGoogle() async {
  FocusScope.of(context).unfocus();

  setState(() {
    isLoading = true;
  });

  try {
    /// final GoogleSignIn googleSignIn = GoogleSignIn();
///
/// await googleSignIn.signOut();
///
/// final GoogleSignInAccount? googleUser =
///     await googleSignIn.signIn();
///
/// if (googleUser == null) {
///   setState(() {
///     isLoading = false;
///   });
///   return;
/// }
///

    /// final GoogleSignInAuthentication googleAuth =
///     await googleUser.authentication;
///
/// final credential = GoogleAuthProvider.credential(
///   accessToken: googleAuth.accessToken,
///   idToken: googleAuth.idToken,
/// );
///
/// await FirebaseAuth.instance.signInWithCredential(
///   credential,
/// );

    await _clearSavedLogin();
await _saveFcmToken();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          key: ValueKey(
            'home_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}_$languageCode',
          ),
          languageCode: languageCode,
        ),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Đăng nhập Google thất bại: ${e.message}'
              : 'Google sign in failed: ${e.message}',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Không thể đăng nhập Google: $e'
              : 'Could not sign in with Google: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
}
  Future<void> _loginWithApple() async {
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      await FirebaseAuth.instance.signInWithProvider(appleProvider);

      await _clearSavedLogin();
await _saveFcmToken();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            key: ValueKey(
              'home_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}_$languageCode',
            ),
            languageCode: languageCode,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = isVi
              ? 'Email này đã được đăng ký bằng phương thức khác.'
              : 'This email is already registered with a different sign-in method.';
          break;
        case 'user-disabled':
          message = isVi
              ? 'Tài khoản này đã bị vô hiệu hóa.'
              : 'This account has been disabled.';
          break;
        case 'operation-not-allowed':
          message = isVi
              ? 'Apple Sign-In chưa được bật trong Firebase.'
              : 'Apple Sign-In is not enabled in Firebase.';
          break;
        case 'popup-closed-by-user':
        case 'canceled':
          message = isVi
              ? 'Bạn đã hủy đăng nhập bằng Apple.'
              : 'Apple sign-in was cancelled.';
          break;
        default:
          message = isVi
              ? 'Đăng nhập Apple thất bại: ${e.message ?? e.code}'
              : 'Apple sign-in failed: ${e.message ?? e.code}';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không thể đăng nhập bằng Apple: $e'
                : 'Could not sign in with Apple: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? 'Đăng nhập' : 'Login'),
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
                            color: languageCode == 'vi'
                                ? Colors.pink
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _changeLanguage('en'),
                        child: Text(
                          'English',
                          style: TextStyle(
                            color: languageCode == 'en'
                                ? Colors.pink
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isVi ? 'Chào mừng quay lại' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVi ? 'Đăng nhập để tiếp tục' : 'Login to continue',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: emailController,
                  label: 'Email',
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: Colors.pink,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            rememberMe = !rememberMe;
                          });
                        },
                        child: Text(
                          isVi ? 'Ghi nhớ đăng nhập' : 'Remember me',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(
                            languageCode: languageCode,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      isVi ? 'Quên mật khẩu?' : 'Forgot Password?',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
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
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(isVi ? 'Đăng nhập' : 'Login'),
                  ),
                ),

                const SizedBox(height: 14),
SizedBox(
  width: double.infinity,
  height: 52,
  child: OutlinedButton.icon(
    onPressed: isLoading ? null : _loginWithGoogle,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.black,
      side: const BorderSide(color: Colors.black12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
    ),
    icon: const Icon(Icons.g_mobiledata, size: 30),
    label: Text(
      isVi ? 'Đăng nhập với Google' : 'Continue with Google',
      style: const TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
                if (showAppleButton) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _loginWithApple,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.apple),
                      label: Text(
                        isVi ? 'Đăng nhập với Apple' : 'Continue with Apple',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        isVi ? 'Chưa có tài khoản? ' : 'No account yet? ',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SignUpPage(
                                languageCode: languageCode,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          isVi ? 'Đăng ký' : 'Sign up',
                          style: const TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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