import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'intro_question_page.dart';

class PhoneVerificationPage extends StatefulWidget {
  final String languageCode;
  final String firstName;

  const PhoneVerificationPage({
    super.key,
    required this.languageCode,
    required this.firstName,
  });

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String selectedCode = '+61';

  final List<Map<String, String>> countryCodes = [
    {'code': '+61', 'name': 'Australia'},
    {'code': '+84', 'name': 'Vietnam'},
    {'code': '+1', 'name': 'USA'},
    {'code': '+44', 'name': 'UK'},
    {'code': '+81', 'name': 'Japan'},
    {'code': '+82', 'name': 'Korea'},
    {'code': '+65', 'name': 'Singapore'},
  ];

  String? _verificationId;
  int? _resendToken;

  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _codeSent = false;

  bool get isVi => widget.languageCode == 'vi';

  String get selectedCountryName {
    final country = countryCodes.firstWhere(
      (item) => item['code'] == selectedCode,
      orElse: () => {'code': '+61', 'name': 'Australia'},
    );
    return country['name'] ?? '';
  }

  String get fullPhoneNumber {
    String phone = _phoneController.text.trim();

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    return '$selectedCode$phone';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSendingCode = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        forceResendingToken: _resendToken,

        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final user = FirebaseAuth.instance.currentUser;

            if (user != null) {
  await user.linkWithCredential(credential);

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'phoneNumber': fullPhoneNumber,
    'phoneVerified': true,
  }, SetOptions(merge: true));
}

            if (!mounted) return;

            setState(() {
              _isSendingCode = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isVi
                      ? 'Số điện thoại đã được xác minh tự động'
                      : 'Phone number verified automatically',
                ),
              ),
            );
             Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => IntroPage(
          languageCode: widget.languageCode,
          firstName: widget.firstName,
        ),
      ),
    );
          } on FirebaseAuthException catch (e) {
            if (!mounted) return;

            setState(() {
              _isSendingCode = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isVi
                      ? 'Xác minh tự động thất bại: ${e.message ?? 'Có lỗi xảy ra'}'
                      : 'Auto verification failed: ${e.message ?? 'Something went wrong'}',
                ),
              ),
            );
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            _isSendingCode = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVi
                    ? 'Gửi mã thất bại: ${e.message ?? 'Có lỗi xảy ra'}'
                    : 'Failed to send code: ${e.message ?? 'Something went wrong'}',
              ),
            ),
          );
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isSendingCode = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVi
                    ? 'Mã OTP đã được gửi tới số điện thoại của bạn'
                    : 'OTP has been sent to your phone number',
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Có lỗi xảy ra khi gửi mã OTP'
                : 'Something went wrong while sending OTP',
          ),
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Vui lòng nhập mã OTP' : 'Please enter OTP code',
          ),
        ),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không tìm thấy mã xác minh. Vui lòng gửi lại OTP.'
                : 'Verification ID not found. Please resend OTP.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingCode = true;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.linkWithCredential(credential);
      }

      if (!mounted) return;

      setState(() {
        _isVerifyingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Xác minh số điện thoại thành công'
                : 'Phone verification successful',
          ),
        ),
      );
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => IntroPage(
      languageCode: widget.languageCode,
      firstName: widget.firstName,
    ),
  ),
);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isVerifyingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Xác minh thất bại: ${e.message ?? 'Sai mã OTP'}'
                : 'Verification failed: ${e.message ?? 'Invalid OTP'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isVerifyingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Có lỗi xảy ra khi xác minh OTP'
                : 'Something went wrong while verifying OTP',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFFF8F4F6);
    final Color primaryPink = Colors.pink;
    final Color textDark = const Color(0xFF2E2A27);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          isVi ? 'Xác minh số điện thoại' : 'Phone Verification',
        ),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  isVi
                      ? 'Xác minh số điện thoại'
                      : 'Verify your phone number',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVi
                      ? 'Chọn mã quốc gia và nhập số điện thoại của bạn'
                      : 'Choose your country code and enter your phone number',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  isVi ? 'Mã quốc gia' : 'Country code',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD8C3B5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCode,
                      isExpanded: true,
                      items: countryCodes.map((country) {
                        final code = country['code']!;
                        final name = country['name']!;
                        return DropdownMenuItem<String>(
                          value: code,
                          child: Text(
                            '$code $name',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCode = value;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  isVi ? 'Số điện thoại' : 'Phone number',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Nhập số điện thoại'
                        : 'Enter your phone number',
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
                      borderSide: const BorderSide(
                        color: Color(0xFFD8C3B5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: primaryPink,
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isVi
                          ? 'Vui lòng nhập số điện thoại'
                          : 'Please enter your phone number';
                    }

                    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                      return isVi
                          ? 'Chỉ được nhập số'
                          : 'Only numbers are allowed';
                    }

                    if (value.trim().length < 8) {
                      return isVi
                          ? 'Số điện thoại quá ngắn'
                          : 'Phone number is too short';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                Text(
                  isVi
                      ? 'Mã đã chọn: $selectedCode $selectedCountryName'
                      : 'Selected: $selectedCode $selectedCountryName',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isVi
                      ? 'Số đầy đủ: $fullPhoneNumber'
                      : 'Full number: $fullPhoneNumber',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSendingCode ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSendingCode
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(isVi ? 'Gửi mã OTP' : 'Send OTP'),
                  ),
                ),

                if (_codeSent) ...[
                  const SizedBox(height: 28),

                  Text(
                    isVi ? 'Mã OTP' : 'OTP Code',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: isVi ? 'Nhập mã OTP' : 'Enter OTP code',
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
                        borderSide: const BorderSide(
                          color: Color(0xFFD8C3B5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: primaryPink,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isVerifyingCode ? null : _verifyOtp,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryPink, width: 1.4),
                        foregroundColor: primaryPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isVerifyingCode
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: primaryPink,
                              ),
                            )
                          : Text(isVi ? 'Xác minh OTP' : 'Verify OTP'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}