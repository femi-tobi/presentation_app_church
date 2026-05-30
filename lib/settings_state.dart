import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';


/// Stores a single entry in the recent presentations list.
class PresentationRecord {
  final String id;
  final String title;
  final int slideCount;
  final String thumbnailUrl; // first slide bg image
  final DateTime createdAt;
  final List<SlideData> slides;
  final String outlineText;

  PresentationRecord({
    required this.id,
    required this.title,
    required this.slideCount,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.slides,
    required this.outlineText,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slideCount': slideCount,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      'slides': slides.map((s) => s.toJson()).toList(),
      'outlineText': outlineText,
    };
  }

  factory PresentationRecord.fromJson(Map<String, dynamic> json) {
    return PresentationRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      slideCount: json['slideCount'] as int,
      thumbnailUrl: json['thumbnailUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      slides: (json['slides'] as List<dynamic>)
          .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
          .toList(),
      outlineText: json['outlineText'] as String? ?? '',
    );
  }

  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return 'Modified ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Modified ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Modified Yesterday';
    return 'Modified ${createdAt.day} ${_month(createdAt.month)} ${createdAt.year}';
  }

  static String _month(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}

/// Slide data representation holding editing configurations.
class SlideData {
  final String id;
  String title;
  String subtitle;
  String imageUrl;        // mutable so user can swap backgrounds
  double opacity;         // 0.0–1.0 overlay visibility
  double blur;            // 0.0–30.0 background blur
  bool isBold;
  bool isItalic;
  TextAlign alignment;
  String transition;
  double titleFontSize;   // pt size for main title text
  double subtitleFontSize; // pt size for subtitle / quote text
  String? logoUrl;        // logo image url / data-url
  double logoX;           // relative X position (0.0 to 1.0)
  double logoY;           // relative Y position (0.0 to 1.0)
  double logoSize;        // size of logo in pixels
  double textX;           // relative X offset (-1.0 to 1.0)
  double textY;           // relative Y offset (-1.0 to 1.0)
  int bgColorValue;       // ARGB color value (default 0xFF000000 for black)

  SlideData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.opacity = 0.85,
    this.blur = 12.0,
    this.isBold = false,
    this.isItalic = true,
    this.alignment = TextAlign.center,
    this.transition = 'Cross Dissolve',
    this.titleFontSize = 48.0,
    this.subtitleFontSize = 20.0,
    String? logoUrl,
    this.logoX = 0.85,
    this.logoY = 0.05,
    this.logoSize = 80.0,
    this.textX = 0.0,
    this.textY = 0.0,
    this.bgColorValue = 0xFF000000,
  }) : logoUrl = logoUrl ?? AppSettings.instance.logoUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'opacity': opacity,
      'blur': blur,
      'isBold': isBold,
      'isItalic': isItalic,
      'alignment': alignment.name,
      'transition': transition,
      'titleFontSize': titleFontSize,
      'subtitleFontSize': subtitleFontSize,
      'logoUrl': logoUrl,
      'logoX': logoX,
      'logoY': logoY,
      'logoSize': logoSize,
      'textX': textX,
      'textY': textY,
      'bgColorValue': bgColorValue,
    };
  }

  factory SlideData.fromJson(Map<String, dynamic> json) {
    return SlideData(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      imageUrl: json['imageUrl'] as String,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      blur: (json['blur'] as num?)?.toDouble() ?? 12.0,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? true,
      alignment: TextAlign.values.firstWhere(
        (e) => e.name == json['alignment'],
        orElse: () => TextAlign.center,
      ),
      transition: json['transition'] as String? ?? 'Cross Dissolve',
      titleFontSize: (json['titleFontSize'] as num?)?.toDouble() ?? 48.0,
      subtitleFontSize: (json['subtitleFontSize'] as num?)?.toDouble() ?? 20.0,
      logoUrl: json['logoUrl'] as String?,
      logoX: (json['logoX'] as num?)?.toDouble() ?? 0.85,
      logoY: (json['logoY'] as num?)?.toDouble() ?? 0.05,
      logoSize: (json['logoSize'] as num?)?.toDouble() ?? 80.0,
      textX: (json['textX'] as num?)?.toDouble() ?? 0.0,
      textY: (json['textY'] as num?)?.toDouble() ?? 0.0,
      bgColorValue: json['bgColorValue'] as int? ?? 0xFF000000,
    );
  }
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._() {
    // Initialize with default high-fidelity slides matching Sunday Morning Service
    _activeSlides = [
      SlideData(
        id: '01',
        title: 'Welcome Home',
        subtitle: '"Peace be with you as we enter this sacred space."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAkigYecE0CmKCuZFuBavKgN8DzoLC7W6Sk1f-88TsL65rI2VnvQzMWzMBXlbn8NSWWMj3iuMzd11L6JwDZ2c8g0xtJ2u0GEE_8MBPBgHYWSh0YLC1YOuFntl9RJBWsp_VN3nRZxNGLDsJHoY5mYOytCHGZhxtVaiBfRrxImcruugnP5uLvBWeSb5hVCEijqYRd-ALjE3KK6juaQxJCITKZ5jv7tLDBMLKDJmX1snESiJYg_J9JA4PfxwbF4qYm65btRgUVbPErgMhD',
        opacity: 0.85,
        blur: 12.0,
      ),
      SlideData(
        id: '02',
        title: 'Worship Set 1',
        subtitle: '"Sing praises to the King, lift up holy hands."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBfTxPcvdVGtfS9lB7z9X1sbdQv7Ilwyi2_gIR8q6qyd9VBoA89wAD1lUuPKcv-bTKvDQfFzhBP6D7Wmk9GXpxYRw7FAL7uNi_tcvc3eygW39xLOHnW1sTQPIVorDBZlUEyEzmhNPNBCDJjA2Ij6dXwIx3KehHleNrkVpRci9akO3-G-MmNbU2NkBiLJ8yIjB5aE0YBidFgvYrgL8hM7H6EzeujgWZY61dJJ3HW-o51FReWjE5GK3bd7aYCLoO6ydFHTSxp8PoX38Pr',
        opacity: 0.70,
        blur: 4.0,
        alignment: TextAlign.center,
        isBold: true,
        isItalic: false,
      ),
      SlideData(
        id: '03',
        title: 'Sermon Notes',
        subtitle: '"Exploring the deep roots of our faith and community."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBOy_uRm4spX4LG8doBchZNGyiO4lrxmQssiqyI1iBFyFONgeUCM5HyR_WsacGWJatGTaSzstvh3A7zkFM5td3MFYD-xSJa-ueTFJcUUCoIQqVNxm4-ij-iXs9bAGSuinsPa60GOYvzioSwl6ir3hv4gYp9koJQW3t9iNwMMd_0DUn2GN8_JD5pN31SbQYpl2Os2GzmPm7YG8Dsyc4RSXi64168o8knrfH0rilaDoh7w60YpEiQEIcyE0LjRoPA0C6KrEhbju4CVP4f',
        opacity: 0.90,
        blur: 15.0,
        alignment: TextAlign.left,
        isBold: false,
        isItalic: true,
      ),
      SlideData(
        id: '04',
        title: 'Closing Prayer',
        subtitle: '"Go forth in grace, spread peace and wisdom."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuC7vrdf0-1MvJXE356j2QWAdqpVFRk3iunfVAlO_TA1nQeR2qaAk5aQbTiQ7x4o41c8QKHp0WjP_U0ZZ_TynH_Qj7LxQUjwbVylQIqSgYPdkhsy-2gOEjVYnnsbP5aEwkSlo7v4TvZwP-TgpmFPGT-Dm4H254TZk2sMH_A9jiSsreTqRqwsMd_ORqBdEm5kA6iG1yBUgpPJ28OD9zSa1v0wfl0mj4Cg3lcsoA2w5BUSKkS-ZXLZ_fB_BwPKYOW0DUcuWNXievN0BCOG',
        opacity: 0.80,
        blur: 8.0,
      ),
    ];
  }

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  set isDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      saveSettings();
      notifyListeners();
    }
  }

  Color _primaryColor = const Color(0xFF2E0052);
  Color get primaryColor => _primaryColor;
  set primaryColor(Color value) {
    if (_primaryColor != value) {
      _primaryColor = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _fontFamily = 'Libre Caslon Text';
  String get fontFamily => _fontFamily;
  set fontFamily(String value) {
    if (_fontFamily != value) {
      _fontFamily = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _churchName = 'Grace Community Chapel';
  String get churchName => _churchName;
  set churchName(String value) {
    if (_churchName != value) {
      _churchName = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _churchEmail = 'media@gracecommunity.org';
  String get churchEmail => _churchEmail;
  set churchEmail(String value) {
    if (_churchEmail != value) {
      _churchEmail = value;
      saveSettings();
      notifyListeners();
    }
  }

  bool _isOffline = false;
  bool get isOffline => _isOffline;
  set isOffline(bool value) {
    if (_isOffline != value) {
      _isOffline = value;
      saveSettings();
      notifyListeners();
    }
  }

  String? _logoUrl;
  String? get logoUrl => _logoUrl ?? 'assets/app_icon.ico';
  set logoUrl(String? value) {
    if (_logoUrl != value) {
      _logoUrl = value;
      saveSettings();
      notifyListeners();
    }
  }



  // Active Slides and selection tracking for Go Live feature
  late List<SlideData> _activeSlides;
  List<SlideData> get activeSlides => _activeSlides;
  void updateActiveSlides(List<SlideData> slides) {
    _activeSlides = List.from(slides);
    notifyListeners();
  }

  int _activeSlideIndex = 0;
  int get activeSlideIndex => _activeSlideIndex;
  set activeSlideIndex(int value) {
    if (_activeSlideIndex != value) {
      _activeSlideIndex = value;
      notifyListeners();
    }
  }

  // ── Recent Presentations ───────────────────────────────────────────────────
  final List<PresentationRecord> _recentPresentations = [];
  List<PresentationRecord> get recentPresentations =>
      List.unmodifiable(_recentPresentations);

  void addRecentPresentation(PresentationRecord record) {
    // Remove duplicate IDs before adding
    _recentPresentations.removeWhere((r) => r.id == record.id);
    _recentPresentations.insert(0, record); // newest first
    if (_recentPresentations.length > 12) _recentPresentations.removeLast();
    saveSettings();
    notifyListeners();
  }

  void deleteRecentPresentation(String id) {
    _recentPresentations.removeWhere((r) => r.id == id);
    saveSettings();
    notifyListeners();
  }

  void renameRecentPresentation(String id, String newTitle) {
    final index = _recentPresentations.indexWhere((r) => r.id == id);
    if (index != -1) {
      final oldRecord = _recentPresentations[index];
      _recentPresentations[index] = PresentationRecord(
        id: oldRecord.id,
        title: newTitle,
        slideCount: oldRecord.slideCount,
        thumbnailUrl: oldRecord.thumbnailUrl,
        createdAt: oldRecord.createdAt,
        slides: oldRecord.slides,
        outlineText: oldRecord.outlineText,
      );
      saveSettings();
      notifyListeners();
    }
  }

  void duplicateRecentPresentation(String id) {
    final index = _recentPresentations.indexWhere((r) => r.id == id);
    if (index != -1) {
      final oldRecord = _recentPresentations[index];
      final newRecord = PresentationRecord(
        id: '${oldRecord.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
        title: '${oldRecord.title} (Copy)',
        slideCount: oldRecord.slideCount,
        thumbnailUrl: oldRecord.thumbnailUrl,
        createdAt: DateTime.now(),
        slides: oldRecord.slides.map((s) => SlideData(
          id: s.id,
          title: s.title,
          subtitle: s.subtitle,
          imageUrl: s.imageUrl,
          opacity: s.opacity,
          blur: s.blur,
          isBold: s.isBold,
          isItalic: s.isItalic,
          alignment: s.alignment,
          transition: s.transition,
          titleFontSize: s.titleFontSize,
          subtitleFontSize: s.subtitleFontSize,
          logoUrl: s.logoUrl,
          logoX: s.logoX,
          logoY: s.logoY,
          logoSize: s.logoSize,
          textX: s.textX,
          textY: s.textY,
          bgColorValue: s.bgColorValue,
        )).toList(),
        outlineText: oldRecord.outlineText,
      );
      _recentPresentations.insert(index + 1, newRecord);
      saveSettings();
      notifyListeners();
    }
  }

  void clearCache() {
    _recentPresentations.clear();
    saveSettings();
    notifyListeners();
  }

  // ── Storage Calculation ────────────────────────────────────────────────────
  /// Soft cap for local presentation data (150 slides total).
  static const int storageTotalSlides = 150;

  /// Sum of slides count across all saved presentations.
  int get totalSlidesCount {
    return _recentPresentations.fold<int>(0, (sum, r) => sum + r.slideCount);
  }

  /// Keep this property for interface compatibility, returns total slides count.
  int get storageUsedBytes => totalSlidesCount;

  /// Fraction 0.0–1.0 for progress bars.
  double get storageFraction =>
      (totalSlidesCount / storageTotalSlides).clamp(0.0, 1.0);

  /// Human-readable used label based on slide count.
  String get storageUsedLabel => '$totalSlidesCount Slides';

  /// Human-readable total label based on slide count.
  String get storageTotalLabel => '$storageTotalSlides Slides';

  // ── Persistence Methods ────────────────────────────────────────────────────
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? _isDarkMode;
      _isOffline = prefs.getBool('isOffline') ?? _isOffline;
      final colorVal = prefs.getInt('primaryColor');
      if (colorVal != null) {
        _primaryColor = Color(colorVal);
      }
      _fontFamily = prefs.getString('fontFamily') ?? _fontFamily;
      _churchName = prefs.getString('churchName') ?? _churchName;
      _churchEmail = prefs.getString('churchEmail') ?? _churchEmail;
      _logoUrl = prefs.getString('logoUrl');

      final recentJson = prefs.getString('recentPresentations');
      if (recentJson != null) {
        final List<dynamic> list = json.decode(recentJson);
        _recentPresentations.clear();
        _recentPresentations.addAll(
          list.map((item) => PresentationRecord.fromJson(item as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setBool('isOffline', _isOffline);
      await prefs.setInt('primaryColor', _primaryColor.value);
      await prefs.setString('fontFamily', _fontFamily);
      await prefs.setString('churchName', _churchName);
      await prefs.setString('churchEmail', _churchEmail);
      if (_logoUrl != null) {
        await prefs.setString('logoUrl', _logoUrl!);
      } else {
        await prefs.remove('logoUrl');
      }

      // Loop to try saving, removing oldest presentation if QuotaExceededError or write failure occurs
      while (true) {
        try {
          final List<Map<String, dynamic>> recentListJson =
              _recentPresentations.map((r) => r.toJson()).toList();
          await prefs.setString('recentPresentations', json.encode(recentListJson));
          break; // successfully saved!
        } catch (e) {
          // If it is a QuotaExceededError or save failure, and we have presentations to remove, remove the oldest one
          if (_recentPresentations.isNotEmpty) {
            debugPrint('Storage quota exceeded. Evicting oldest presentation: ${_recentPresentations.last.title}');
            _recentPresentations.removeLast();
          } else {
            // Nothing left to evict, rethrow
            rethrow;
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}

// ── Base64 / Data URL Caching Decoder ──────────────────────────────────────────
final Map<String, Uint8List> _decodedBytesCache = {};
const int _maxCacheSize = 100;

/// Safely decode a base64 data-URL to bytes using an LRU-like cache to prevent
/// constant re-decoding of large image data.
Uint8List decodeDataUrl(String dataUrl) {
  if (dataUrl.isEmpty) return Uint8List(0);
  
  // Create a lightweight cache key from the data URL to avoid hashing megabytes of text
  final String key = dataUrl.length <= 1000 
      ? dataUrl 
      : '${dataUrl.length}_${dataUrl.substring(0, 200)}_${dataUrl.substring(dataUrl.length - 200)}';
      
  final cached = _decodedBytesCache[key];
  if (cached != null) {
    return cached;
  }
  
  Uint8List decoded;
  try {
    final uriData = Uri.parse(dataUrl).data;
    if (uriData != null) {
      decoded = uriData.contentAsBytes();
    } else {
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex != -1) {
        decoded = base64Decode(dataUrl.substring(commaIndex + 1));
      } else {
        decoded = Uint8List(0);
      }
    }
  } catch (_) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex != -1) {
      try {
        decoded = base64Decode(dataUrl.substring(commaIndex + 1));
      } catch (__) {
        decoded = Uint8List(0);
      }
    } else {
      decoded = Uint8List(0);
    }
  }
  
  if (_decodedBytesCache.length >= _maxCacheSize) {
    _decodedBytesCache.remove(_decodedBytesCache.keys.first);
  }
  _decodedBytesCache[key] = decoded;
  return decoded;
}

