import 'package:flutter_contacts/flutter_contacts.dart';

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

  static Future<List<Contact>> _safeLoadContacts() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);

      if (!granted) {
        return <Contact>[];
      }

      return await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
      );
    } catch (e) {
      print('ContactPrivacyHelper error: $e');
      return <Contact>[];
    }
  }

  static Future<Set<String>> loadNormalizedContactPhones() async {
    final contacts = await _safeLoadContacts();

    final Set<String> phones = {};

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = normalizePhone(phone.number);
        if (normalized.isNotEmpty) {
          phones.add(normalized);
        }
      }
    }

    return phones;
  }

  static Future<Set<String>> loadNormalizedContactEmails() async {
    final contacts = await _safeLoadContacts();

    final Set<String> emails = {};

    for (final contact in contacts) {
      for (final email in contact.emails) {
        final value = email.address.trim().toLowerCase();
        if (value.isNotEmpty) {
          emails.add(value);
        }
      }
    }

    return emails;
  }
}