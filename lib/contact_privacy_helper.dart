class ContactPrivacyHelper {
  static String normalizePhone(String input) {
    var phone = input.trim();

    phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.indexOf('+') > 0) {
      phone = phone.replaceAll('+', '');
    }

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    if (phone.startsWith('04') && phone.length >= 10) {
      phone = '+61${phone.substring(1)}';
    }

    if (phone.startsWith('61') && !phone.startsWith('+61')) {
      phone = '+$phone';
    }

    if (phone.startsWith('4') && phone.length == 9) {
      phone = '+61$phone';
    }

    return phone;
  }

  // TẠM THỜI TẮT CONTACTS ĐỂ TRÁNH BLACK SCREEN / CRASH iOS
  static Future<Set<String>> loadNormalizedContactPhones() async {
    return <String>{};
  }

  static Future<Set<String>> loadNormalizedContactEmails() async {
    return <String>{};
  }
}