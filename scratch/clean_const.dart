import 'dart:io';

void main() {
  final files = [
    'lib/dashboard_page.dart',
    'lib/preview_page.dart',
    'lib/export_page.dart',
    'lib/settings_page.dart',
    'lib/templates_page.dart',
    'lib/create_presentation_page.dart',
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('File not found: $filePath');
      continue;
    }

    String content = file.readAsStringSync();

    // Replace const constructors with non-const ones
    final replacements = [
      'const ColorScheme',
      'const Border',
      'const BorderSide',
      'const Icon',
      'const BoxDecoration',
      'const LinearGradient',
      'const TextStyle',
      'const UnderlineInputBorder',
      'const OutlineInputBorder',
      'const SnackBar',
      'const EdgeInsets',
      'const Divider',
      'const SizedBox',
      'const Center',
      'const CircleAvatar',
      'const InputDecoration',
    ];

    for (final word in replacements) {
      final nonConstWord = word.replaceFirst('const ', '');
      content = content.replaceAll(word, nonConstWord);
    }

    file.writeAsStringSync(content);
    print('Cleaned $filePath');
  }
}
