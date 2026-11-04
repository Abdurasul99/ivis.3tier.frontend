// i18n coverage: scans lib/ source files (plain dart:io, no analyzer) and fails
// when
//   (a) a t('…') / tKey('…') key has no entry in the English dictionary, or
//   (b) a Hangul string literal is not passed to t() / tKey() / l10n(korean, …)
//       (outside the dictionary file, log calls and the allowlist below).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivis/i18n/app_locale.dart';

// The dictionary file itself holds the Korean source strings.
const String _dictionaryFile = 'lib/i18n/app_locale.dart';

// Calls whose Korean text is log output, not UI (never translated).
const Set<String> _logCallees = <String>{'debugPrint', 'print', 'log'};

// Hangul literals that are data values, not display text. Keep this short.
class _Allow {
  const _Allow(this.file, this.literals, this.reason);
  final String file;
  final Set<String> literals;
  final String reason;
}

const List<_Allow> _allowlist = <_Allow>[
  _Allow(
    'lib/view/components/app_language_toggle.dart',
    <String>{'한국어'},
    'Language self-name: always shown in its own language.',
  ),
  _Allow(
    'lib/view/components/infra_vehicle_map.dart',
    <String>{'대구역', '동대구역', '수성구', '범어역', '칠성시장', '동대구', '칠성'},
    'Station names are data (matched against registry values); display goes '
        'through displayName / displayShortLabel.',
  ),
  _Allow(
    'lib/view/tabs/tab_device_management.dart',
    <String>{'대구역', '동대구역', '수성구', '범어역', '칠성시장'},
    'Station names are saved to the registry (home_station / '
        'location_address); the dropdown shows t(name).',
  ),
  _Allow(
    'lib/view/tabs/tab_setting_vehicle_infra.dart',
    <String>{'대구역', '동대구역', '수성구', '범어역', '칠성시장'},
    'Station names are saved to the registry; the dropdown shows t(name).',
  ),
  _Allow(
    'lib/view/tabs/tab_setting_member.dart',
    <String>{'관리자', '일반'},
    'Role request values handed to MemberController.reqChangeRole.',
  ),
  _Allow(
    'lib/viewmodel/controller/member_controller.dart',
    <String>{'관리자'},
    'Role request value compared before updating the cached role.',
  ),
  _Allow(
    'lib/viewmodel/repository/member_repository.dart',
    <String>{'관리자'},
    'Role request value mapped to the API role code.',
  ),
];

final RegExp _hangul = RegExp(r'[가-힣ㄱ-ㆎ]');

// ── Minimal Dart lexer (comments, nested string interpolation, brackets) ────

class _Tok {
  _Tok(this.kind, this.text, this.offset,
      {this.value = '', this.hasInterpolation = false, this.children = const <List<_Tok>>[]});

  final String kind; // id, str, punct, num
  final String text;
  final int offset;
  final String value; // decoded literal text, interpolations removed
  final bool hasInterpolation;
  final List<List<_Tok>> children; // tokens of each ${…} / $name
}

class _Lexer {
  _Lexer(this.src);

  final String src;
  int pos = 0;

  static bool _idStart(int c) =>
      (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36;
  static bool _idPart(int c) => _idStart(c) || (c >= 48 && c <= 57);

  List<_Tok> lexAll() {
    final List<_Tok> out = <_Tok>[];
    while (pos < src.length) {
      out.addAll(_lexUntilClosingBrace());
      if (pos < src.length) {
        out.add(_Tok('punct', '}', pos));
        pos++;
      }
    }
    return out;
  }

  // Lexes until an unmatched '}' (end of an interpolation) or end of input.
  List<_Tok> _lexUntilClosingBrace() {
    final List<_Tok> out = <_Tok>[];
    int depth = 0;
    while (pos < src.length) {
      final int c = src.codeUnitAt(pos);
      if (c == 32 || c == 9 || c == 10 || c == 13) {
        pos++;
      } else if (src.startsWith('//', pos)) {
        final int nl = src.indexOf('\n', pos);
        pos = nl < 0 ? src.length : nl + 1;
      } else if (src.startsWith('/*', pos)) {
        int nesting = 0;
        while (pos < src.length) {
          if (src.startsWith('/*', pos)) {
            nesting++;
            pos += 2;
          } else if (src.startsWith('*/', pos)) {
            nesting--;
            pos += 2;
            if (nesting == 0) break;
          } else {
            pos++;
          }
        }
      } else if ((c == 114 || c == 82) &&
          pos + 1 < src.length &&
          (src[pos + 1] == "'" || src[pos + 1] == '"')) {
        out.add(_lexString(raw: true));
      } else if (c == 39 || c == 34) {
        out.add(_lexString(raw: false));
      } else if (_idStart(c)) {
        final int start = pos;
        while (pos < src.length && _idPart(src.codeUnitAt(pos))) {
          pos++;
        }
        out.add(_Tok('id', src.substring(start, pos), start));
      } else if (c >= 48 && c <= 57) {
        final int start = pos;
        while (pos < src.length &&
            (_idPart(src.codeUnitAt(pos)) || src[pos] == '.')) {
          pos++;
        }
        out.add(_Tok('num', src.substring(start, pos), start));
      } else {
        if (c == 123) depth++;
        if (c == 125) {
          if (depth == 0) return out;
          depth--;
        }
        out.add(_Tok('punct', src[pos], pos));
        pos++;
      }
    }
    return out;
  }

  _Tok _lexString({required bool raw}) {
    final int start = pos;
    if (raw) pos++;
    final String quote = src[pos];
    final String delimiter = src.startsWith(quote * 3, pos) ? quote * 3 : quote;
    pos += delimiter.length;
    final StringBuffer value = StringBuffer();
    final List<List<_Tok>> children = <List<_Tok>>[];
    while (pos < src.length && !src.startsWith(delimiter, pos)) {
      final String ch = src[pos];
      if (!raw && ch == r'\') {
        final String next = pos + 1 < src.length ? src[pos + 1] : '';
        if (next == 'n') {
          value.write('\n');
          pos += 2;
        } else if (next == 't') {
          value.write('\t');
          pos += 2;
        } else if (next == 'r') {
          value.write('\r');
          pos += 2;
        } else if (next == 'u' && src[pos + 2] == '{') {
          final int end = src.indexOf('}', pos);
          value.writeCharCode(int.parse(src.substring(pos + 3, end), radix: 16));
          pos = end + 1;
        } else if (next == 'u') {
          value.writeCharCode(int.parse(src.substring(pos + 2, pos + 6), radix: 16));
          pos += 6;
        } else if (next == 'x') {
          value.writeCharCode(int.parse(src.substring(pos + 2, pos + 4), radix: 16));
          pos += 4;
        } else {
          value.write(next);
          pos += 2;
        }
      } else if (!raw && ch == r'$' && pos + 1 < src.length && src[pos + 1] == '{') {
        pos += 2;
        children.add(_lexUntilClosingBrace());
        pos++; // closing '}'
      } else if (!raw &&
          ch == r'$' &&
          pos + 1 < src.length &&
          _idStart(src.codeUnitAt(pos + 1))) {
        final int idStart = ++pos;
        while (pos < src.length && _idPart(src.codeUnitAt(pos)) && src[pos] != r'$') {
          pos++;
        }
        children.add(<_Tok>[_Tok('id', src.substring(idStart, pos), idStart)]);
      } else {
        value.write(ch);
        pos++;
      }
    }
    pos += delimiter.length;
    return _Tok('str', src.substring(start, pos), start,
        value: value.toString(),
        hasInterpolation: children.isNotEmpty,
        children: children);
  }
}

class _Frame {
  _Frame(this.open, this.callee);
  final String open; // ( [ { or 'interp'
  final String callee; // function called with '(' ('' if none / method call)
  int argIndex = 0;
}

class _Finding {
  _Finding(this.file, this.line, this.message);
  final String file;
  final int line;
  final String message;
  @override
  String toString() => '$file:$line  $message';
}

class _Scanner {
  _Scanner(this.file, this.src);

  final String file;
  final String src;
  final List<_Finding> missingKeys = <_Finding>[];
  final List<_Finding> unwrapped = <_Finding>[];
  final Set<String> allowHits = <String>{};

  int _line(int offset) => '\n'.allMatches(src.substring(0, offset)).length + 1;

  void run(Map<String, String> dictionary, List<_Allow> allowlist) {
    final List<_Tok> tokens = _Lexer(src).lexAll();
    _checkKeys(tokens, dictionary);
    _checkLiterals(tokens, <_Frame>[], allowlist);
  }

  // (a) literal keys of t()/tKey() must exist in the dictionary.
  void _checkKeys(List<_Tok> tokens, Map<String, String> dictionary) {
    for (int i = 0; i < tokens.length; i++) {
      final _Tok tok = tokens[i];
      if (tok.kind == 'str') {
        for (final List<_Tok> child in tok.children) {
          _checkKeys(child, dictionary);
        }
        continue;
      }
      // A call, not a method call (x.t()) or a declaration (String t(...)).
      final _Tok? previous = i > 0 ? tokens[i - 1] : null;
      final bool isDeclaration = previous != null &&
          previous.kind == 'id' &&
          (previous.text == 'void' || previous.text.startsWith(RegExp('[A-Z]')));
      final bool isCall = tok.kind == 'id' &&
          (tok.text == 't' || tok.text == 'tKey') &&
          i + 1 < tokens.length &&
          tokens[i + 1].text == '(' &&
          previous?.text != '.' &&
          !isDeclaration;
      if (!isCall) continue;
      final List<_Tok> args = <_Tok>[];
      int depth = 0;
      for (int j = i + 1; j < tokens.length; j++) {
        final String text = tokens[j].text;
        if (tokens[j].kind == 'punct' && (text == '(' || text == '[' || text == '{')) depth++;
        if (tokens[j].kind == 'punct' && (text == ')' || text == ']' || text == '}')) {
          depth--;
          if (depth == 0) break;
        }
        if (j > i + 1) args.add(tokens[j]);
      }
      if (args.isEmpty || args.any((_Tok a) => a.kind != 'str')) continue; // dynamic
      if (args.any((_Tok a) => a.hasInterpolation)) {
        missingKeys.add(_Finding(file, _line(tok.offset),
            'interpolated key in ${tok.text}(): use l10n(korean, english) instead'));
        continue;
      }
      final String key = args.map((_Tok a) => a.value).join();
      if (!dictionary.containsKey(key)) {
        missingKeys.add(_Finding(file, _line(tok.offset),
            'no English entry for ${tok.text}(${_show(key)})'));
      }
    }
  }

  // (b) Hangul literals must be the Korean argument of t()/tKey()/l10n().
  void _checkLiterals(List<_Tok> tokens, List<_Frame> stack, List<_Allow> allowlist) {
    for (int i = 0; i < tokens.length; i++) {
      final _Tok tok = tokens[i];
      if (tok.kind == 'punct') {
        if (tok.text == '(' || tok.text == '[' || tok.text == '{') {
          String callee = '';
          if (tok.text == '(' && i > 0 && tokens[i - 1].kind == 'id') {
            final bool dotted = i > 1 && tokens[i - 2].text == '.';
            callee = dotted ? '.${tokens[i - 1].text}' : tokens[i - 1].text;
          }
          stack.add(_Frame(tok.text, callee));
        } else if (tok.text == ')' || tok.text == ']' || tok.text == '}') {
          if (stack.isNotEmpty) stack.removeLast();
        } else if (tok.text == ',' && stack.isNotEmpty) {
          stack.last.argIndex++;
        }
        continue;
      }
      if (tok.kind != 'str') continue;
      if (_hangul.hasMatch(tok.value)) {
        _classify(tok, stack, allowlist);
      }
      for (final List<_Tok> child in tok.children) {
        _checkLiterals(child, <_Frame>[...stack, _Frame('interp', '')], allowlist);
      }
    }
  }

  void _classify(_Tok tok, List<_Frame> stack, List<_Allow> allowlist) {
    final _Frame? top = stack.isEmpty ? null : stack.last;
    if (top != null && top.open == '(') {
      if ((top.callee == 't' || top.callee == 'tKey') && top.argIndex == 0) return;
      if (top.callee == 'l10n') {
        if (top.argIndex == 0) return;
        unwrapped.add(_Finding(file, _line(tok.offset),
            'Hangul in the English argument of l10n(): ${_show(tok.text)}'));
        return;
      }
    }
    if (stack.any((_Frame f) =>
        _logCallees.contains(f.callee) || f.callee == '.log' || f.callee == '.debugPrint')) {
      return;
    }
    for (final _Allow allow in allowlist) {
      if (allow.file == file && allow.literals.contains(tok.value)) {
        allowHits.add('${allow.file}|${tok.value}');
        return;
      }
    }
    unwrapped.add(_Finding(file, _line(tok.offset),
        'Hangul literal not passed to t()/l10n(): ${_show(tok.text)}'));
  }

  static String _show(String text) => text.replaceAll('\n', r'\n');
}

List<File> _libDartFiles() {
  final List<File> files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

String _relative(File f) => f.path.replaceAll(r'\', '/');

void main() {
  final Map<String, String> dictionary = englishDictionary;
  final List<_Finding> missingKeys = <_Finding>[];
  final List<_Finding> unwrapped = <_Finding>[];
  final Set<String> allowHits = <String>{};

  setUpAll(() {
    for (final File file in _libDartFiles()) {
      final String path = _relative(file);
      final _Scanner scanner = _Scanner(path, file.readAsStringSync());
      scanner.run(dictionary, path == _dictionaryFile ? const <_Allow>[] : _allowlist);
      missingKeys.addAll(scanner.missingKeys);
      if (path != _dictionaryFile) {
        unwrapped.addAll(scanner.unwrapped);
        allowHits.addAll(scanner.allowHits);
      }
    }
  });

  test('lib/ sources were scanned', () {
    expect(_libDartFiles().length, greaterThan(50));
  });

  test('(a) every t()/tKey() literal key has an English entry', () {
    expect(missingKeys, isEmpty, reason: missingKeys.join('\n'));
  });

  test('(b) every Hangul string literal goes through t()/l10n()', () {
    expect(unwrapped, isEmpty, reason: unwrapped.join('\n'));
  });

  test('allowlist has no stale entries', () {
    final List<String> stale = <String>[
      for (final _Allow allow in _allowlist)
        for (final String literal in allow.literals)
          if (!allowHits.contains('${allow.file}|$literal')) '${allow.file}: $literal',
    ];
    expect(stale, isEmpty, reason: 'Remove unused allowlist entries:\n${stale.join('\n')}');
  });

  test('dictionary entries are Korean keys with English values', () {
    final List<String> bad = <String>[
      for (final MapEntry<String, String> e in dictionary.entries)
        if (!_hangul.hasMatch(e.key) || e.value.trim().isEmpty || _hangul.hasMatch(e.value))
          '${e.key} → ${e.value}',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
