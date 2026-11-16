// Password reset API: envelope parsing for 200 / 4xx answers and the shared
// password policy (reset page, signup, password-change dialog).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ivis/model/common_model.dart';
import 'package:ivis/viewmodel/controller/password_controller.dart';
import 'package:ivis/viewmodel/repository/password_repository.dart';

http.Response _json(Object payload, int status) =>
    http.Response.bytes(utf8.encode(json.encode(payload)), status);

void main() {
  group('PasswordRepository.parseEnvelope', () {
    test('200 envelope is parsed', () {
      final CommonResponse? res = PasswordRepository.parseEnvelope(
        _json(<String, dynamic>{'code': '0000', 'message': 'ok'}, 200),
      );

      expect(res?.code, '0000');
    });

    test('400 envelope keeps the backend code and message', () {
      final CommonResponse? unknownEmail = PasswordRepository.parseEnvelope(
        _json(<String, dynamic>{'code': '9002', 'message': 'Email not registered'}, 400),
      );
      final CommonResponse? idMismatch = PasswordRepository.parseEnvelope(
        _json(<String, dynamic>{'code': '9007', 'message': 'ID does not match'}, 400),
      );

      expect(unknownEmail?.code, '9002');
      expect(unknownEmail?.message, 'Email not registered');
      expect(idMismatch?.code, '9007');
    });

    test('5xx answers are null even with an envelope', () {
      final CommonResponse? res = PasswordRepository.parseEnvelope(
        _json(<String, dynamic>{'code': '9999', 'message': 'exception occurred'}, 500),
      );

      expect(res, isNull);
    });

    test('unparseable or non-envelope bodies are null', () {
      expect(PasswordRepository.parseEnvelope(http.Response('<html>', 400)), isNull);
      expect(PasswordRepository.parseEnvelope(http.Response('[1,2]', 200)), isNull);
      expect(
        PasswordRepository.parseEnvelope(_json(<String, dynamic>{'error': 'x'}, 400)),
        isNull,
      );
    });
  });

  group('isValidPasswordPolicy', () {
    test('accepts 8-16 chars with letter, digit and special', () {
      expect(isValidPasswordPolicy('abcd123!'), isTrue);
      expect(isValidPasswordPolicy('Abcdefg1234567#!'), isTrue);
    });

    test('rejects short, long and incomplete passwords', () {
      expect(isValidPasswordPolicy('ab12!'), isFalse);
      expect(isValidPasswordPolicy('Abcdefg1234567#!x'), isFalse);
      expect(isValidPasswordPolicy('abcdefgh1'), isFalse);
      expect(isValidPasswordPolicy('abcdefgh!'), isFalse);
      expect(isValidPasswordPolicy('12345678!'), isFalse);
      expect(isValidPasswordPolicy(''), isFalse);
    });
  });
}
