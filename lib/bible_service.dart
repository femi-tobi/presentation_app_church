import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ParsedReference {
  final bool isValid;
  final String? book;
  final int? chapter;
  final List<int> verses; // Support range/lists (e.g. [16, 17, 18])
  final String? normalizedReference;
  final String? error;
  final String? invalidPart; // Track invalid part for UI highlight color feedback

  ParsedReference({
    required this.isValid,
    this.book,
    this.chapter,
    this.verses = const [],
    this.normalizedReference,
    this.error,
    this.invalidPart,
  });
}

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

  final Map<String, String> abbreviations = {
    "gen": "Genesis", "ge": "Genesis", "gn": "Genesis", "g": "Genesis",
    "exo": "Exodus", "ex": "Exodus", "exod": "Exodus",
    "lev": "Leviticus", "le": "Leviticus", "lv": "Leviticus",
    "num": "Numbers", "nu": "Numbers", "nm": "Numbers", "nb": "Numbers",
    "deut": "Deuteronomy", "deu": "Deuteronomy", "dt": "Deuteronomy",
    "josh": "Joshua", "jos": "Joshua", "js": "Joshua",
    "judg": "Judges", "jdg": "Judges", "jg": "Judges", "jdgs": "Judges", "jud": "Judges",
    "ruth": "Ruth", "ru": "Ruth", "rt": "Ruth",
    "1sam": "1 Samuel", "1sa": "1 Samuel", "1 sa": "1 Samuel", "i sam": "1 Samuel", "1sm": "1 Samuel",
    "2sam": "2 Samuel", "2sa": "2 Samuel", "2 sa": "2 Samuel", "ii sam": "2 Samuel", "2sm": "2 Samuel",
    "1kgs": "1 Kings", "1ki": "1 Kings", "1k": "1 Kings", "1 kings": "1 Kings",
    "2kgs": "2 Kings", "2ki": "2 Kings", "2k": "2 Kings", "2 kings": "2 Kings",
    "1chr": "1 Chronicles", "1ch": "1 Chronicles", "1 chron": "1 Chronicles",
    "2chr": "2 Chronicles", "2ch": "2 Chronicles", "2 chron": "2 Chronicles",
    "ezra": "Ezra", "ezr": "Ezra", "ez": "Ezra",
    "neh": "Nehemiah", "ne": "Nehemiah", "nmh": "Nehemiah",
    "est": "Esther", "esth": "Esther", "es": "Esther",
    "job": "Job", "jb": "Job",
    "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms", "psalms": "Psalms", "pss": "Psalms", "p": "Psalms",
    "prov": "Proverbs", "pro": "Proverbs", "pr": "Proverbs", "prv": "Proverbs",
    "eccl": "Ecclesiastes", "ecc": "Ecclesiastes", "ec": "Ecclesiastes", "qoh": "Ecclesiastes",
    "song": "Song of Solomon", "songofsolomon": "Song of Solomon", "sos": "Song of Solomon", "ss": "Song of Solomon", "canticles": "Song of Solomon", "song of songs": "Song of Solomon",
    "isa": "Isaiah", "is": "Isaiah",
    "jer": "Jeremiah", "jr": "Jeremiah",
    "lam": "Lamentations", "la": "Lamentations",
    "ezek": "Ezekiel", "ezk": "Ezekiel",
    "dan": "Daniel", "dn": "Daniel", "da": "Daniel",
    "hos": "Hosea", "ho": "Hosea",
    "joel": "Joel", "jl": "Joel",
    "amos": "Amos", "am": "Amos",
    "obad": "Obadiah", "ob": "Obadiah", "oba": "Obadiah",
    "jon": "Jonah", "jnh": "Jonah",
    "mic": "Micah", "mc": "Micah",
    "nah": "Nahum", "na": "Nahum",
    "hab": "Habakkuk", "hb": "Habakkuk",
    "zeph": "Zephaniah", "zep": "Zephaniah", "zp": "Zephaniah",
    "hag": "Haggai", "hg": "Haggai",
    "zech": "Zechariah", "zec": "Zechariah", "zc": "Zechariah",
    "mal": "Malachi", "ml": "Malachi",
    "matt": "Matthew", "mat": "Matthew", "mt": "Matthew",
    "mark": "Mark", "mrk": "Mark", "mk": "Mark", "mr": "Mark",
    "luke": "Luke", "luk": "Luke", "lk": "Luke", "lu": "Luke",
    "john": "John", "jhn": "John", "jn": "John", "joh": "John",
    "acts": "Acts", "act": "Acts", "ac": "Acts",
    "rom": "Romans", "ro": "Romans", "rm": "Romans",
    "1cor": "1 Corinthians", "1co": "1 Corinthians", "1 co": "1 Corinthians", "i cor": "1 Corinthians", "1corinthians": "1 Corinthians",
    "2cor": "2 Corinthians", "2co": "2 Corinthians", "2 co": "2 Corinthians", "ii cor": "2 Corinthians", "2corinthians": "2 Corinthians",
    "gal": "Galatians", "ga": "Galatians",
    "eph": "Ephesians", "ep": "Ephesians",
    "phil": "Philippians", "php": "Philippians", "philip": "Philippians", "pp": "Philippians",
    "col": "Colossians", "co": "Colossians",
    "1thess": "1 Thessalonians", "1th": "1 Thessalonians", "1 thes": "1 Thessalonians", "1thes": "1 Thessalonians",
    "2thess": "2 Thessalonians", "2th": "2 Thessalonians", "2 thes": "2 Thessalonians", "2thes": "2 Thessalonians",
    "1tim": "1 Timothy", "1ti": "1 Timothy", "1 tm": "1 Timothy",
    "2tim": "2 Timothy", "2ti": "2 Timothy", "2 tm": "2 Timothy",
    "tit": "Titus", "ti": "Titus",
    "philem": "Philemon", "phm": "Philemon", "pm": "Philemon",
    "heb": "Hebrews", "hb": "Hebrews", "he": "Hebrews",
    "jas": "James", "jam": "James", "jm": "James",
    "1pet": "1 Peter", "1pe": "1 Peter", "1 pt": "1 Peter",
    "2pet": "2 Peter", "2pe": "2 Peter", "2 pt": "2 Peter",
    "1jn": "1 John", "1john": "1 John", "1jhn": "1 John", "1 jo": "1 John",
    "2jn": "2 John", "2john": "2 John", "2jhn": "2 John", "2 jo": "2 John",
    "3jn": "3 John", "3john": "3 John", "3jhn": "3 John", "3 jo": "3 John",
    "jude": "Jude", "jud": "Jude",
    "rev": "Revelation", "re": "Revelation", "rv": "Revelation", "revelation": "Revelation", "apocalypse": "Revelation"
  };

  /// Parses text into structured Book, Chapter, and Verse list
  Future<ParsedReference> parseReference(String translation, String input) async {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) {
      return ParsedReference(isValid: false, error: 'Empty query');
    }

    // Regex to match e.g.:
    // "1jn 3:16", "john 3.16", "jn3,16", "rom 8:28-31", "ps 23:1-6", "john 3", "jn3"
    // Capture group 1: optional leading digit + book letters
    // Capture group 2: chapter digits
    // Capture group 3: separator + verse part
    final parserRegex = RegExp(r'^(\d?\s*[a-z\s]+?)\s*[-.,:]?\s*(\d+)(?:\s*[-.,:]\s*(.+))?$');
    final match = parserRegex.firstMatch(query);

    String parsedBookPart = '';
    String chapterPart = '';
    String versePart = '';

    if (match != null) {
      parsedBookPart = match.group(1)?.trim() ?? '';
      chapterPart = match.group(2) ?? '';
      versePart = match.group(3)?.trim() ?? '';
    } else {
      // Fallback: If it's just a book name like "John"
      parsedBookPart = query;
    }

    if (parsedBookPart.isEmpty) {
      return ParsedReference(isValid: false, error: 'Could not resolve book');
    }

    // Expand abbreviations
    String targetBookName = abbreviations[parsedBookPart.replaceAll(' ', '')] ?? '';

    // If still not matched, check closest exact match from books list
    final books = await getBooks(translation);
    if (targetBookName.isEmpty) {
      targetBookName = books.firstWhere(
        (b) => b.replaceAll(' ', '').toLowerCase() == parsedBookPart.replaceAll(' ', ''),
        orElse: () {
          // Fuzzy check: starts with
          return books.firstWhere(
            (b) => b.toLowerCase().startsWith(parsedBookPart),
            orElse: () => '',
          );
        },
      );
    }

    if (targetBookName.isEmpty) {
      return ParsedReference(isValid: false, error: 'Invalid book', invalidPart: parsedBookPart);
    }

    final book = await loadBook(translation, targetBookName);
    if (book == null) {
      return ParsedReference(isValid: false, error: 'Failed to load book');
    }

    // If only book name is typed
    if (chapterPart.isEmpty) {
      return ParsedReference(
        isValid: true,
        book: targetBookName,
        chapter: 1,
        verses: [1],
        normalizedReference: '$targetBookName 1',
      );
    }

    final int? chNum = int.tryParse(chapterPart);
    if (chNum == null) {
      return ParsedReference(isValid: false, error: 'Invalid chapter format', invalidPart: chapterPart);
    }

    final chapter = book.chapters.firstWhere(
      (c) => int.tryParse(c.chapterNumber) == chNum,
      orElse: () => BibleChapter(chapterNumber: '', verses: []),
    );

    if (chapter.chapterNumber.isEmpty) {
      return ParsedReference(isValid: false, error: 'Chapter does not exist', invalidPart: chapterPart);
    }

    // If no verse part is supplied, default to the whole chapter (return first verse as initial default focus)
    if (versePart.isEmpty) {
      return ParsedReference(
        isValid: true,
        book: targetBookName,
        chapter: chNum,
        verses: [],
        normalizedReference: '$targetBookName $chNum',
      );
    }

    // Parse verse parts (supports ranges e.g. "16-18" or lists "16,17,18")
    final List<int> resolvedVerses = [];
    if (versePart.contains('-')) {
      // Range split
      final parts = versePart.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start != null && end != null && start <= end) {
          for (int v = start; v <= end; v++) {
            resolvedVerses.add(v);
          }
        }
      }
    } else {
      // Comma-separated list or single verse
      final parts = versePart.split(',');
      for (final p in parts) {
        final v = int.tryParse(p.trim());
        if (v != null) {
          resolvedVerses.add(v);
        }
      }
    }

    if (resolvedVerses.isEmpty) {
      // User typed "John 3:" but no verse number yet
      return ParsedReference(
        isValid: true,
        book: targetBookName,
        chapter: chNum,
        verses: [],
        normalizedReference: '$targetBookName $chNum:',
      );
    }

    // Validate that all resolved verses exist in this chapter
    for (final vNum in resolvedVerses) {
      final exists = chapter.verses.any((v) => int.tryParse(v.verseNumber) == vNum);
      if (!exists) {
        return ParsedReference(
          isValid: false,
          error: 'Verse $vNum does not exist in chapter $chNum',
          invalidPart: versePart,
        );
      }
    }

    final normalized = resolvedVerses.length == 1
        ? '$targetBookName $chNum:${resolvedVerses.first}'
        : '$targetBookName $chNum:${resolvedVerses.first}-${resolvedVerses.last}';

    return ParsedReference(
      isValid: true,
      book: targetBookName,
      chapter: chNum,
      verses: resolvedVerses,
      normalizedReference: normalized,
    );
  }

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
        final book = await compute(_parseBibleBook, jsonStr);
        _loadedBooksCache[tKey]![bookName] = book;
        return book;
      } catch (_) {
        // Try the next name
      }
    }

    return null;
  }

  /// Search verses matching query in a translation.
  /// Modified: Only returns book reference matches (like 'Joshua 18:5' or 'Genesis 1') instead of keyword searches.
  Future<List<Map<String, dynamic>>> searchVerses(String translation, String query) async {
    final results = <Map<String, dynamic>>[];
    final parsedRef = await parseReference(translation, query);
    if (!parsedRef.isValid || parsedRef.book == null || parsedRef.chapter == null) {
      return results;
    }

    final book = await loadBook(translation, parsedRef.book!);
    if (book == null) return results;

    final chapter = book.chapters.firstWhere(
      (c) => int.tryParse(c.chapterNumber) == parsedRef.chapter,
      orElse: () => BibleChapter(chapterNumber: '', verses: []),
    );
    if (chapter.chapterNumber.isEmpty) return results;

    if (parsedRef.verses.isNotEmpty) {
      for (final vNum in parsedRef.verses) {
        final verse = chapter.verses.firstWhere(
          (v) => int.tryParse(v.verseNumber) == vNum,
          orElse: () => BibleVerse(verseNumber: '', text: ''),
        );
        if (verse.verseNumber.isNotEmpty) {
          results.add({
            'book': parsedRef.book!,
            'chapter': parsedRef.chapter.toString(),
            'verse': verse.verseNumber,
            'text': verse.text,
          });
        }
      }
    } else {
      // If only book + chapter searched, return all verses in the chapter
      for (final v in chapter.verses) {
        results.add({
          'book': parsedRef.book!,
          'chapter': parsedRef.chapter.toString(),
          'verse': v.verseNumber,
          'text': v.text,
        });
      }
    }

    return results;
  }

  /// Finds the next or previous verse in the Bible relative to the current book, chapter, and verse.
  Future<Map<String, dynamic>?> getNextOrPrevVerse({
    required String translation,
    required String bookName,
    required int chapterNum,
    required int verseNum,
    required bool next,
  }) async {
    final book = await loadBook(translation, bookName);
    if (book == null) return null;

    final chIdx = book.chapters.indexWhere((c) => int.tryParse(c.chapterNumber) == chapterNum);
    if (chIdx == -1) return null;

    final currentChapter = book.chapters[chIdx];
    final vIdx = currentChapter.verses.indexWhere((v) => int.tryParse(v.verseNumber) == verseNum);
    if (vIdx == -1) return null;

    if (next) {
      if (vIdx + 1 < currentChapter.verses.length) {
        final nextVerse = currentChapter.verses[vIdx + 1];
        return {
          'book': bookName,
          'chapter': chapterNum.toString(),
          'verse': nextVerse.verseNumber,
          'text': nextVerse.text,
        };
      } else {
        // Go to next chapter, first verse
        if (chIdx + 1 < book.chapters.length) {
          final nextChapter = book.chapters[chIdx + 1];
          if (nextChapter.verses.isNotEmpty) {
            final nextVerse = nextChapter.verses.first;
            return {
              'book': bookName,
              'chapter': nextChapter.chapterNumber,
              'verse': nextVerse.verseNumber,
              'text': nextVerse.text,
            };
          }
        } else {
          // Go to next book
          final books = await getBooks(translation);
          final bookIdx = books.indexWhere((b) => b.toLowerCase() == bookName.toLowerCase());
          if (bookIdx != -1 && bookIdx + 1 < books.length) {
            final nextBookName = books[bookIdx + 1];
            final nextBook = await loadBook(translation, nextBookName);
            if (nextBook != null && nextBook.chapters.isNotEmpty && nextBook.chapters.first.verses.isNotEmpty) {
              final nextVerse = nextBook.chapters.first.verses.first;
              return {
                'book': nextBookName,
                'chapter': nextBook.chapters.first.chapterNumber,
                'verse': nextVerse.verseNumber,
                'text': nextVerse.text,
              };
            }
          }
        }
      }
    } else {
      // Previous verse
      if (vIdx - 1 >= 0) {
        final prevVerse = currentChapter.verses[vIdx - 1];
        return {
          'book': bookName,
          'chapter': chapterNum.toString(),
          'verse': prevVerse.verseNumber,
          'text': prevVerse.text,
        };
      } else {
        // Go to previous chapter, last verse
        if (chIdx - 1 >= 0) {
          final prevChapter = book.chapters[chIdx - 1];
          if (prevChapter.verses.isNotEmpty) {
            final prevVerse = prevChapter.verses.last;
            return {
              'book': bookName,
              'chapter': prevChapter.chapterNumber,
              'verse': prevVerse.verseNumber,
              'text': prevVerse.text,
            };
          }
        } else {
          // Go to previous book, last chapter, last verse
          final books = await getBooks(translation);
          final bookIdx = books.indexWhere((b) => b.toLowerCase() == bookName.toLowerCase());
          if (bookIdx != -1 && bookIdx - 1 >= 0) {
            final prevBookName = books[bookIdx - 1];
            final prevBook = await loadBook(translation, prevBookName);
            if (prevBook != null && prevBook.chapters.isNotEmpty && prevBook.chapters.last.verses.isNotEmpty) {
              final prevChapter = prevBook.chapters.last;
              final prevVerse = prevChapter.verses.last;
              return {
                'book': prevBookName,
                'chapter': prevChapter.chapterNumber,
                'verse': prevVerse.verseNumber,
                'text': prevVerse.text,
              };
            }
          }
        }
      }
    }
    return null;
  }
}

/// Helper top-level function to parse a Bible book in a background isolate
BibleBook _parseBibleBook(String jsonStr) {
  final Map<String, dynamic> data = json.decode(jsonStr);
  return BibleBook.fromJson(data);
}
