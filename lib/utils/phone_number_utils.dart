import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Utility class for phone number normalization, validation, and formatting
class PhoneNumberUtils {
  /// Normalize phone number to E.164 format (e.g., +1234567890)
  /// 
  /// Returns null if phone number is invalid
  static String? normalizePhoneNumber(String phoneNumber) {
    try {
      // Remove all non-digit characters except +
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      if (cleaned.isEmpty) return null;
      
      // If it doesn't start with +, try to parse as US number
      if (!cleaned.startsWith('+')) {
        // Remove leading 1 if present (US country code)
        final withoutOne = cleaned.startsWith('1') && cleaned.length > 10
            ? cleaned.substring(1)
            : cleaned;
        
        // If it's 10 digits, assume US number
        if (RegExp(r'^\d{10}$').hasMatch(withoutOne)) {
          return '+1$withoutOne';
        }
        
        // Try parsing with default country
        try {
          final parsed = PhoneNumber.parse(withoutOne, destinationCountry: IsoCode.US);
          return parsed.international;
        } catch (e) {
          return null;
        }
      }
      
      // Parse as international number
      try {
        final parsed = PhoneNumber.parse(cleaned);
        return parsed.international;
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Format phone number for display (e.g., (123) 456-7890)
  static String formatPhoneNumber(String phoneNumber) {
    try {
      final normalized = normalizePhoneNumber(phoneNumber);
      if (normalized == null) return phoneNumber;
      
      final parsed = PhoneNumber.parse(normalized);
      return parsed.international;
    } catch (e) {
      return phoneNumber;
    }
  }
  
  /// Validate phone number
  /// Returns true if phone number is valid
  static bool validatePhoneNumber(String phoneNumber) {
    try {
      final normalized = normalizePhoneNumber(phoneNumber);
      if (normalized == null) return false;
      
      final parsed = PhoneNumber.parse(normalized);
      return parsed.isValid();
    } catch (e) {
      return false;
    }
  }
  
  /// Extract phone number from text
  /// Returns first valid phone number found, or null
  static String? extractPhoneNumber(String text) {
    // Pattern to match phone numbers
    final patterns = [
      RegExp(r'\+?\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'),
      RegExp(r'\d{10}'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final extracted = match.group(0);
        if (extracted != null && validatePhoneNumber(extracted)) {
          return normalizePhoneNumber(extracted);
        }
      }
    }
    
    return null;
  }
  
  /// Get country code from phone number
  static String? getCountryCode(String phoneNumber) {
    try {
      final normalized = normalizePhoneNumber(phoneNumber);
      if (normalized == null) return null;
      
      final parsed = PhoneNumber.parse(normalized);
      return parsed.countryCode;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if two phone numbers are the same (after normalization)
  static bool areSamePhoneNumbers(String phone1, String phone2) {
    final normalized1 = normalizePhoneNumber(phone1);
    final normalized2 = normalizePhoneNumber(phone2);
    
    if (normalized1 == null || normalized2 == null) return false;
    
    return normalized1 == normalized2;
  }
}

