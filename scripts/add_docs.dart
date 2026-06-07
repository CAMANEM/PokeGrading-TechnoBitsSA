/// Script to add Doxygen-style (`///`) documentation comments
/// to all .dart files in backend/ and frontend/.
///
/// Run: dart run scripts/add_docs.dart
import 'dart:io';

void main() async {
  final root = Directory('.');
  final dartFiles = <File>[];

  await for (final entity
      in root.list(recursive: true, followLinks: false)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.contains('.dart_tool') &&
        !entity.path.contains('build') &&
        !entity.path.contains('pubspec')) {
      dartFiles.add(entity);
    }
  }

  for (final file in dartFiles) {
    final content = await file.readAsString();
    final updated = _addDoxygenDocs(file.path, content);
    if (updated != content) {
      await file.writeAsString(updated);
      print('  ✔ ${file.path}');
    }
  }
  print('\nDone. ${dartFiles.length} files processed.');
}

String _addDoxygenDocs(String path, String content) {
  final lines = content.split('\n');
  final result = <String>[];
  int i = 0;

  String? _nextNonBlank(int idx) {
    for (int j = idx; j < lines.length; j++) {
      if (lines[j].trim().isNotEmpty) return lines[j].trim();
    }
    return null;
  }

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // Skip existing /// comments
    if (trimmed.startsWith('///')) {
      result.add(line);
      i++;
      continue;
    }

    // Convert // comments before classes/functions/enums to ///
    if (trimmed.startsWith('//') && !trimmed.startsWith('///')) {
      final next = _nextNonBlank(i + 1);
      if (next != null && _isDocumentable(next)) {
        // Convert this and adjacent // lines to ///
        while (i < lines.length &&
            lines[i].trim().startsWith('//') &&
            !lines[i].trim().startsWith('///')) {
          result.add(lines[i].replaceFirst('//', '///'));
          i++;
        }
        continue;
      }
    }

    // Convert /* ... */ doc blocks before classes to ///
    if (trimmed.startsWith('/*')) {
      final startIdx = i;
      final blockLines = <int>[];
      blockLines.add(i);
      i++;
      while (i < lines.length && !lines[i].trim().endsWith('*/')) {
        blockLines.add(i);
        i++;
      }
      if (i < lines.length) blockLines.add(i);
      i++; // skip */

      final next = _nextNonBlank(i);
      if (next != null && _isDocumentable(next)) {
        for (final idx in blockLines) {
          var l = lines[idx];
          final t = l.trim();
          if (t == '/*' || t == '/**') continue;
          if (t.endsWith('*/')) {
            final content = t.substring(0, t.length - 2).trim();
            if (content.isNotEmpty) {
              result.add('  /// $content');
            }
            continue;
          }
          if (t.startsWith('* ')) {
            result.add('  /// ${t.substring(2)}');
          } else if (t.startsWith('*')) {
            result.add('  /// ${t.substring(1)}');
          } else if (t.startsWith('+ ')) {
            result.add('  /// ${t.substring(2)}');
          } else if (t.startsWith('//')) {
            // already handled above
            continue;
          } else {
            result.add(l);
          }
        }
        continue;
      } else {
        // Not a doc block, keep as-is
        for (final idx in blockLines) {
          result.add(lines[idx]);
        }
        continue;
      }
    }

    result.add(line);
    i++;
  }

  return result.join('\n');
}

bool _isDocumentable(String line) {
  return line.startsWith('class ') ||
      line.startsWith('abstract class ') ||
      line.startsWith('enum ') ||
      line.startsWith('typedef ') ||
      line.startsWith('mixin ') ||
      line.startsWith('extension ') ||
      line.startsWith('Future<') ||
      line.startsWith('void ') ||
      line.startsWith('String ') ||
      line.startsWith('int ') ||
      line.startsWith('double ') ||
      line.startsWith('bool ') ||
      line.startsWith('Map<') ||
      line.startsWith('List<') ||
      line.startsWith('final ') ||
      line.startsWith('const ') ||
      line.startsWith('static ') ||
      line.startsWith('factory ') ||
      line.startsWith('@override') ||
      line.startsWith('Widget ') ||
      line.startsWith('State<') ||
      line.startsWith('StatelessWidget') ||
      line.startsWith('StatefulWidget') ||
      line.startsWith('ChangeNotifier') ||
      line.startsWith('Router ') ||
      line.startsWith('Middleware ') ||
      line.startsWith('Handler ') ||
      line.startsWith(' get ') ||
      line.startsWith(' set ') ||
      line.contains(' Middleware(') ||
      line.contains(' abstract class');
}
