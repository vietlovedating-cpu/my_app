import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

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

  static Future<Set<String>> loadNormalizedContactPhones() async {
    try {
      var status = await Permission.contacts.status;

      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (!status.isGranted) {
        return <String>{};
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final phones = <String>{};

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalized = normalizePhone(phone.number);
          if (normalized.isNotEmpty) {
            phones.add(normalized);
          }
        }
      }

      print('CONTACT phones loaded: ${phones.length}');
      return phones;
    } catch (e) {
      print('CONTACT phones error: $e');
      return <String>{};
    }
  }

  static Future<Set<String>> loadNormalizedContactEmails() async {
    try {
      var status = await Permission.contacts.status;

      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (!status.isGranted) {
        return <String>{};
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final emails = <String>{};

      for (final contact in contacts) {
        for (final email in contact.emails) {
          final value = email.address.trim().toLowerCase();
          if (value.isNotEmpty) {
            emails.add(value);
          }
        }
      }

      print('CONTACT emails loaded: ${emails.length}');
      return emails;
    } catch (e) {
      print('CONTACT emails error: $e');
      return <String>{};
    }
  }
}