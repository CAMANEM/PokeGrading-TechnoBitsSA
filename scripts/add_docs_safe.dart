/// Safe script to add basic Doxygen-style `///` documentation
/// to Dart files. Only adds file headers and class/enum docs.
///
/// Usage (from project root):
///   dart run scripts\add_docs_safe.dart backend
///   dart run scripts\add_docs_safe.dart frontend
import 'dart:io';

void main(List<String> args) async {
  final target = args.isNotEmpty ? args[0] : '.';
  final dir = Directory(target);
  if (!await dir.exists()) {
    print('Directory not found: $target');
    return;
  }

  final files = <File>[];
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.contains('.dart_tool') &&
        !e.path.contains('build') &&
        !e.path.contains('pubspec') &&
        !e.path.contains('scripts/')) {
      files.add(e);
    }
  }

  for (final f in files) {
    final content = await f.readAsString();
    final updated = _process(content);
    if (updated != content) {
      await f.writeAsString(updated);
      print('  ${f.path}');
    }
  }
  print('\nDone. ${files.length} files in $target.');
}

String _process(String src) {
  final lines = src.split('\n');
  final out = <String>[];
  int i = 0;

  bool _hasDocAbove(int idx) {
    // Only check a few lines above for existing docs
    for (int j = idx - 1; j >= 0 && j >= idx - 6; j--) {
      final t = lines[j].trim();
      if (t.startsWith('///')) return true;
      if (t.startsWith('/*')) return true;
      if (t == '' || t.startsWith('//')) continue;
      if (t.startsWith('@')) continue;
      return false;
    }
    return false;
  }

  bool _isClassDef(String line) {
    final t = line.trim();
    return t.startsWith('class ') || t.startsWith('enum ') || t.startsWith('abstract class ') || t.startsWith('mixin ') || t.startsWith('extension ');
  }

  String? _className(String line) {
    final t = line.trim();
    final r = RegExp(r'(?:abstract\s+)?(?:class|enum|mixin|extension)\s+(\w+)');
    final m = r.firstMatch(t);
    return m?.group(1);
  }

  // Check if file already starts with a doc header
  bool hasHeader = false;
  for (int j = 0; j < lines.length && j < 8; j++) {
    final t = lines[j].trim();
    if (t.startsWith('///')) { hasHeader = true; break; }
    if (t.startsWith('/*')) { hasHeader = true; break; }
    if (t.startsWith('import ') || t.startsWith('part ') || t.startsWith('export ') || t.startsWith('library ')) break;
  }

  if (!hasHeader) {
    lines.insert(0, '');
    lines.insert(0, '/// @brief');
    lines.insert(0, '/// @file');
  }

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (_isClassDef(trimmed) && !_hasDocAbove(i)) {
      final name = _className(trimmed);
      if (name != null) {
        final ind = line.substring(0, line.length - line.trimLeft().length);
        // Clean trailing blank lines before insertion point
        while (out.isNotEmpty && out.last.trim() == '') {
          out.removeLast();
        }
        out.add('');
        out.add('$ind/// @brief $name');
        out.add(line);
        i++;
        continue;
      }
    }

    out.add(line);
    i++;
  }

  return out.join('\n');
}
