class Validators {
  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  static String? indianPhone(String? value) {
    var digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    // Numbers are often pasted or typed with a country code or trunk prefix
    // ("+91 98765 43210", "098765 43210"). Strip those before checking the
    // 10 digit local number instead of rejecting an otherwise valid number.
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number';
    }

    return null;
  }

  static bool isValidIndianPhone(String? value) {
    return indianPhone(value) == null;
  }

  const Validators._();
}
