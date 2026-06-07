/// Script to add basic Doxygen-style (`///`) documentation
/// comments to all .dart files in backend/ and frontend/.
///
/// Usage:
///   cd backend && dart run ../scripts/add_doxygen_comments.dart
///   cd frontend && dart run ../scripts/add_doxygen_comments.dart
import 'dart:io';

void main() async {
  final cwd = Directory.current;
  final dartFiles = <File>[];

  await for (final entity in cwd.list(recursive: true, followLinks: false)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.contains('.dart_tool') &&
        !entity.path.contains('build') &&
        !entity.path.contains('pubspec') &&
        !entity.path.contains('scripts/')) {
      dartFiles.add(entity);
    }
  }

  for (final file in dartFiles) {
    final content = await file.readAsString();
    final updated = _addDoxygen(file.path, content);
    if (updated != content) {
      await file.writeAsString(updated);
      print('  ✔ ${file.path}');
    }
  }
  print('\nDone. ${dartFiles.length} files processed.');
}

String _addDoxygen(String path, String content) {
  final src = _SourceFile(content);
  final relPath = path.replaceAll('\\', '/');
  final fileName = relPath.split('/').last;

  // 1. Ensure file-header doc comment
  if (!content.startsWith('///')) {
    final dir = relPath.contains('backend/')
        ? 'backend'
        : relPath.contains('frontend/')
            ? 'frontend'
            : 'project';
    src.insert(0, '/// $fileName — PokéGrading module.');
    src.insert(1, '');
  }

  // 2. Add /// before each class, enum, abstract class, mixin
  for (int i = 0; i < src.length; i++) {
    final line = src.line(i);
    final trimmed = line.trim();

    if (trimmed.startsWith('//') || trimmed.startsWith('///') || trimmed.isEmpty) {
      continue;
    }

    if (_isClassOrEnumDef(trimmed)) {
      if (i > 0) {
        final prevLine = src.line(i - 1).trim();
        if (prevLine.isEmpty || prevLine == '{') {
          // Simple class — maybe add short doc
          final name = _extractName(trimmed);
          if (name != null && !name.startsWith('_')) {
            src.insert(i, '');
            src.insert(i, '/// $name');
          }
        }
      }
    }

    // 3. Add /// before top-level functions (non-underscore, non-build)
    if (_isTopLevelFunction(trimmed, src, i)) {
      if (i > 0) {
        final prevLine = src.line(i - 1).trim();
        if (prevLine.isEmpty && !_isDocumentable(src, i)) {
          final name = _extractFunctionName(trimmed);
          if (name != null && !name.startsWith('_')) {
            src.insert(i, '');
            src.insert(i, '/// $name');
            i += 2;
          }
        }
      }
    }
  }

  return src.toString();
}

bool _isClassOrEnumDef(String line) {
  return line.startsWith('class ') ||
      line.startsWith('abstract class ') ||
      line.startsWith('enum ') ||
      line.startsWith('mixin ') ||
      line.startsWith('extension ');
}

bool _isTopLevelFunction(String line, _SourceFile src, int idx) {
  if (line.startsWith('Future<') || line.startsWith('void ') || line.startsWith('String ') ||
      line.startsWith('int ') || line.startsWith('double ') || line.startsWith('bool ') ||
      line.startsWith('Map<') || line.startsWith('List<') || line.startsWith('Middleware')) {
    // Check indentation — top-level means no leading spaces
    final indent = src.line(idx).length - src.line(idx).trimLeft().length;
    if (indent == 0 && line.endsWith('{') || line.endsWith(') {')) {
      // Check we're not inside a class
      for (int j = idx - 1; j >= 0 && j > idx - 30; j--) {
        final l = src.line(j).trim();
        if (l.startsWith('class ') || l.startsWith('abstract class ')) return false;
        if (l.startsWith('}') || l.startsWith('//')) continue;
      }
      return true;
    }
  }
  return false;
}

String? _extractName(String line) {
  final patterns = [
    RegExp(r'^(?:abstract\s+)?class\s+(\w+)'),
    RegExp(r'^enum\s+(\w+)'),
    RegExp(r'^mixin\s+(\w+)'),
    RegExp(r'^extension\s+(\w+)'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

String? _extractFunctionName(String line) {
  final m = RegExp(r'(?:Future<[^>]+>|void|String|int|double|bool|Map<[^>]+>|List<[^>]+>)\s+(\w+)\s*\(').firstMatch(line);
  return m?.group(1);
}

bool _isDocumentable(_SourceFile src, int idx) {
  for (int j = idx - 1; j >= 0 && j > idx - 5; j--) {
    final t = src.line(j).trim();
    if (t == '///' || t.startsWith('/// ')) return true;
    if (t.isNotEmpty && !t.startsWith('//')) return false;
  }
  return false;
}

class _SourceFile {
  final List<String> _lines;
  _SourceFile(String content) : _lines = content.split('\n');

  int get length => _lines.length;
  String line(int idx) => idx < _lines.length ? _lines[idx] : '';
  void insert(int idx, String line) => _lines.insert(idx, line);

  @override
  String toString() => _lines.join('\n');
}
