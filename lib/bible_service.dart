import 'dart:convert';
import 'package:flutter/services.dart';

class BibleVerse {
  final String verseNumber;
  final String text;

  BibleVerse({required this.verseNumber, required this.text});

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      verseNumber: json['verse'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class BibleChapter {
  final String chapterNumber;
  final List<BibleVerse> verses;

  BibleChapter({required this.chapterNumber, required this.verses});

  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    return BibleChapter(
      chapterNumber: json['chapter'] as String? ?? '',
      verses: (json['verses'] as List? ?? [])
          .map((v) => BibleVerse.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BibleBook {
  final String name;
  final List<BibleChapter> chapters;

  BibleBook({required this.name, required this.chapters});

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      name: json['book'] as String? ?? '',
      chapters: (json['chapters'] as List? ?? [])
          .map((c) => BibleChapter.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BibleService {
  BibleService._privateConstructor();
  static final BibleService instance = BibleService._privateConstructor();

  final Map<String, List<String>> _booksListCache = {};
  final Map<String, Map<String, BibleBook>> _loadedBooksCache = {};

  /// Get list of books for a given translation ('kjv' or 'niv')
  Future<List<String>> getBooks(String translation) async {
    final tKey = translation.toLowerCase();
    if (_booksListCache.containsKey(tKey)) {
      return _booksListCache[tKey]!;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/$tKey/Books.json');
      final List<dynamic> list = json.decode(jsonStr);
      final books = list.map((b) => b.toString()).toList();
      _booksListCache[tKey] = books;
      return books;
    } catch (_) {
      // Fallback books list
      final defaultBooks = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah",
        "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
        "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
        "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke",
        "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians",
        "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
        "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"
      ];
      _booksListCache[tKey] = defaultBooks;
      return defaultBooks;
    }
  }

  /// Load a specific book from the assets
  Future<BibleBook?> loadBook(String translation, String bookName) async {
    final tKey = translation.toLowerCase();
    _loadedBooksCache[tKey] ??= {};

    if (_loadedBooksCache[tKey]!.containsKey(bookName)) {
      return _loadedBooksCache[tKey]![bookName];
    }

    // Attempt to load. Since filenames differ, try both with-space and without-space formats.
    final possibleFileNames = [
      bookName,
      bookName.replaceAll(' ', ''),
    ];

    for (final name in possibleFileNames) {
      try {
        final path = 'assets/$tKey/$name.json';
        final jsonStr = await rootBundle.loadString(path);
        final Map<String, dynamic> data = json.decode(jsonStr);
        final book = BibleBook.fromJson(data);
        _loadedBooksCache[tKey]![bookName] = book;
        return book;
      } catch (_) {
        // Try the next name
      }
    }

    return null;
  }

  /// Search verses matching query in a translation
  Future<List<Map<String, dynamic>>> searchVerses(String translation, String query) async {
    final results = <Map<String, dynamic>>[];
    if (query.trim().isEmpty) return results;

    final books = await getBooks(translation);
    final normalizedQuery = query.toLowerCase();

    for (final bookName in books) {
      final book = await loadBook(translation, bookName);
      if (book == null) continue;

      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          if (verse.text.toLowerCase().contains(normalizedQuery)) {
            results.add({
              'book': bookName,
              'chapter': chapter.chapterNumber,
              'verse': verse.verseNumber,
              'text': verse.text,
            });
            if (results.length >= 100) {
              return results; // Limit search results to 100
            }
          }
        }
      }
    }

    return results;
  }
}
