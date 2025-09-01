import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  static final _digits = RegExp(r'\d+');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = _digits.stringMatch(newValue.text) ?? '';
    if (raw.length > 11) raw = raw.substring(0, 11);

    String f;
    if (raw.length >= 8) {
      f = '${raw.substring(0, 3)}-${raw.substring(3, 7)}-${raw.substring(7)}';
    } else if (raw.length >= 4) {
      f = '${raw.substring(0, 3)}-${raw.substring(3)}';
    } else {
      f = raw;
    }

    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}
