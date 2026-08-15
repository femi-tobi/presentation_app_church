import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'presentation_controller.dart';


enum SectionType {
  verse,
  chorus,
  bridge,
  preChorus,
  intro,
  outro,
  coda,
  medley,
  tag,
  unknown,
}

SectionType getSectionTypeFromName(String name) {
  final clean = name.trim().toUpperCase();
  if (clean.startsWith('CHORUS') || clean.startsWith('CHR') || clean == 'CHO' || clean == 'CH') {
    return SectionType.chorus;
  }
  if (clean.startsWith('VERSE') || clean.startsWith('VS') || clean.startsWith('V') || clean.startsWith('V_')) {
    return SectionType.verse;
  }
  if (clean.startsWith('BRIDGE') || clean.startsWith('BR')) {
    return SectionType.bridge;
  }
  if (clean.startsWith('PRECHORUS') || clean.startsWith('PRE-CHORUS') || clean.startsWith('PRE CHORUS') || clean.startsWith('PRE')) {
    return SectionType.preChorus;
  }
  if (clean.startsWith('INTRO') || clean.startsWith('INT')) {
    return SectionType.intro;
  }
  if (clean.startsWith('OUTRO') || clean.startsWith('OUT')) {
    return SectionType.outro;
  }
  if (clean.startsWith('CODA') || clean.startsWith('COD')) {
    return SectionType.coda;
  }
  if (clean.startsWith('MEDLEY') || clean.startsWith('MED')) {
    return SectionType.medley;
  }
  if (clean.startsWith('TAG')) {
    return SectionType.tag;
  }
  return SectionType.unknown;
}

Color getSectionColor(SectionType type, {bool isDarkMode = false}) {
  if (isDarkMode) {
    switch (type) {
      case SectionType.verse: return const Color(0xFF81C784); // Light Green
      case SectionType.chorus: return const Color(0xFF64B5F6); // Light Blue
      case SectionType.bridge: return const Color(0xFFFFB74D); // Light Orange
      case SectionType.preChorus: return const Color(0xFFBA68C8); // Light Purple
      case SectionType.intro: return const Color(0xFF4DD0E1); // Light Cyan
      case SectionType.outro: return const Color(0xFFF06292); // Light Pink
      case SectionType.coda: return const Color(0xFFE57373); // Light Red
      case SectionType.medley: return const Color(0xFFFFF176); // Light Yellow
      case SectionType.tag: return const Color(0xFF7986CB); // Light Indigo
      case SectionType.unknown: return const Color(0xFF90A4AE); // Light Gray
    }
  } else {
    switch (type) {
      case SectionType.verse: return const Color(0xFF2E7D32); // Dark Green
      case SectionType.chorus: return const Color(0xFF1565C0); // Dark Blue
      case SectionType.bridge: return const Color(0xFFE65100); // Dark Orange
      case SectionType.preChorus: return const Color(0xFF4A148C); // Dark Purple
      case SectionType.intro: return const Color(0xFF006064); // Dark Cyan
      case SectionType.outro: return const Color(0xFF880E4F); // Dark Pink
      case SectionType.coda: return const Color(0xFFB71C1C); // Dark Red
      case SectionType.medley: return const Color(0xFFF57F17); // Dark Yellow
      case SectionType.tag: return const Color(0xFF1A237E); // Dark Indigo
      case SectionType.unknown: return const Color(0xFF37474F); // Dark Gray
    }
  }
}

class SlideSection {
  final String id;
  String name;
  List<String> slideIds;
  bool isCollapsed;
  int? colorValue;
  String? notes;
  bool locked;
  String? rawLyrics; // Raw lyric text — single source of truth for outline editing
  SectionType sectionType; // Cached section type derived from name

  SlideSection({
    required this.id,
    required this.name,
    required this.slideIds,
    this.isCollapsed = false,
    this.colorValue,
    this.notes,
    this.locked = false,
    this.rawLyrics,
    SectionType? sectionType,
  }) : sectionType = sectionType ?? getSectionTypeFromName(name);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slideIds': slideIds,
      'isCollapsed': isCollapsed,
      'colorValue': colorValue,
      'notes': notes,
      'locked': locked,
      'rawLyrics': rawLyrics,
      'sectionType': sectionType.index,
    };
  }

  factory SlideSection.fromJson(Map<String, dynamic> json) {
    return SlideSection(
      id: json['id'] as String,
      name: json['name'] as String,
      slideIds: List<String>.from(json['slideIds'] as List<dynamic>),
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      colorValue: json['colorValue'] as int?,
      notes: json['notes'] as String?,
      locked: json['locked'] as bool? ?? false,
      rawLyrics: json['rawLyrics'] as String?,
      sectionType: json['sectionType'] != null
          ? SectionType.values[json['sectionType'] as int]
          : getSectionTypeFromName(json['name'] as String),
    );
  }
}

class PresentationRecord {
  final String id;
  final String title;
  final int slideCount;
  final String thumbnailUrl; // first slide bg image
  final DateTime createdAt;
  final List<SlideData> slides;
  final String outlineText;
  final List<SlideSection>? sections;

  PresentationRecord({
    required this.id,
    required this.title,
    required this.slideCount,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.slides,
    required this.outlineText,
    this.sections,
  });

  Map<String, dynamic> toJson({bool includeSlides = true}) {
    return {
      'id': id,
      'title': title,
      'slideCount': slideCount,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      if (includeSlides) 'slides': slides.map((s) => s.toJson()).toList(),
      'outlineText': outlineText,
      'sections': sections?.map((s) => s.toJson()).toList(),
    };
  }

  factory PresentationRecord.fromJson(Map<String, dynamic> json) {
    final slidesRaw = json['slides'] as List<dynamic>?;
    return PresentationRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      slideCount: json['slideCount'] as int,
      thumbnailUrl: json['thumbnailUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      slides: slidesRaw != null
          ? slidesRaw
              .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
      outlineText: json['outlineText'] as String? ?? '',
      sections: json['sections'] != null
          ? (json['sections'] as List<dynamic>)
              .map((s) => SlideSection.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
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
/// Represents a single shape parsed from a PowerPoint slide.
/// Positions/sizes are normalised fractions of slide width/height (0.0–1.0).
class PptxShape {
  final double left;
  final double top;
  final double width;
  final double height;

  /// Text content (joined runs). Empty for picture-only shapes.
  final String text;

  final double fontSize;
  final bool isBold;
  final bool isItalic;

  /// ARGB integer colour of the text (e.g. 0xFF000000 for black).
  final int colorValue;

  final TextAlign align;

  /// Non-empty base-64 data-URI when this shape is an image (e.g. `data:image/png;base64,...`).
  final String imageDataUri;

  /// Background fill color of the shape (0x00000000 = transparent / no fill).
  final int fillColorValue;

  /// The font family name parsed from PowerPoint (e.g. "Arial Black", "Calibri").
  final String fontFamily;

  /// Decoded image bytes (pre-populated to prevent lagging during UI builds).
  final Uint8List? imageBytes;

  const PptxShape({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.text = '',
    this.fontSize = 18.0,
    this.isBold = false,
    this.isItalic = false,
    this.colorValue = 0xFF000000,
    this.align = TextAlign.left,
    this.imageDataUri = '',
    this.fillColorValue = 0x00000000, // transparent by default
    this.fontFamily = 'Arial',
    this.imageBytes,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        'text': text,
        'fontSize': fontSize,
        'isBold': isBold,
        'isItalic': isItalic,
        'colorValue': colorValue,
        'align': align.name,
        'imageDataUri': imageDataUri,
        'fillColorValue': fillColorValue,
        'fontFamily': fontFamily,
      };

  factory PptxShape.fromJson(Map<String, dynamic> j) {
    final uri = j['imageDataUri'] as String? ?? '';
    Uint8List? bytes;
    if (uri.isNotEmpty) {
      try {
        final comma = uri.indexOf(',');
        if (comma != -1) {
          bytes = base64Decode(uri.substring(comma + 1));
        }
      } catch (_) {}
    }

    return PptxShape(
      left: (j['left'] as num).toDouble(),
      top: (j['top'] as num).toDouble(),
      width: (j['width'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
      text: j['text'] as String? ?? '',
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 18.0,
      isBold: j['isBold'] as bool? ?? false,
      isItalic: j['isItalic'] as bool? ?? false,
      colorValue: j['colorValue'] as int? ?? 0xFF000000,
      align: TextAlign.values.firstWhere(
        (e) => e.name == j['align'],
        orElse: () => TextAlign.left,
      ),
      imageDataUri: uri,
      fillColorValue: j['fillColorValue'] as int? ?? 0x00000000,
      fontFamily: j['fontFamily'] as String? ?? 'Arial',
      imageBytes: bytes,
    );
  }
}

class SlideData extends ChangeNotifier {
  final String id;

  String? _sectionId;
  String? get sectionId => _sectionId;
  set sectionId(String? value) {
    if (_sectionId != value) {
      _sectionId = value;
      notifyListeners();
    }
  }
  
  String _title;
  String get title => _title;
  set title(String value) {
    if (_title != value) {
      _title = value;
      notifyListeners();
    }
  }

  String _subtitle;
  String get subtitle => _subtitle;
  set subtitle(String value) {
    if (_subtitle != value) {
      _subtitle = value;
      notifyListeners();
    }
  }

  String _imageUrl;
  String get imageUrl => _imageUrl;
  set imageUrl(String value) {
    if (_imageUrl != value) {
      _imageUrl = value;
      notifyListeners();
    }
  }

  double _opacity;
  double get opacity => _opacity;
  set opacity(double value) {
    if (_opacity != value) {
      _opacity = value;
      notifyListeners();
    }
  }

  double _blur;
  double get blur => _blur;
  set blur(double value) {
    if (_blur != value) {
      _blur = value;
      notifyListeners();
    }
  }

  bool _isBold;
  bool get isBold => _isBold;
  set isBold(bool value) {
    if (_isBold != value) {
      _isBold = value;
      notifyListeners();
    }
  }

  bool _isItalic;
  bool get isItalic => _isItalic;
  set isItalic(bool value) {
    if (_isItalic != value) {
      _isItalic = value;
      notifyListeners();
    }
  }

  TextAlign _alignment;
  TextAlign get alignment => _alignment;
  set alignment(TextAlign value) {
    if (_alignment != value) {
      _alignment = value;
      notifyListeners();
    }
  }

  String _transition;
  String get transition => _transition;
  set transition(String value) {
    if (_transition != value) {
      _transition = value;
      notifyListeners();
    }
  }

  double _titleFontSize;
  double get titleFontSize => _titleFontSize;
  set titleFontSize(double value) {
    if (_titleFontSize != value) {
      _titleFontSize = value;
      notifyListeners();
    }
  }

  double _subtitleFontSize;
  double get subtitleFontSize => _subtitleFontSize;
  set subtitleFontSize(double value) {
    if (_subtitleFontSize != value) {
      _subtitleFontSize = value;
      notifyListeners();
    }
  }

  String? _logoUrl;
  String? get logoUrl => _logoUrl == "" ? "" : (_logoUrl ?? AppSettings.instance.logoUrl);
  set logoUrl(String? value) {
    if (_logoUrl != value) {
      _logoUrl = value;
      notifyListeners();
    }
  }

  double _logoX;
  double get logoX => _logoX;
  set logoX(double value) {
    if (_logoX != value) {
      _logoX = value;
      notifyListeners();
    }
  }

  double _logoY;
  double get logoY => _logoY;
  set logoY(double value) {
    if (_logoY != value) {
      _logoY = value;
      notifyListeners();
    }
  }

  double _logoSize;
  double get logoSize => _logoSize;
  set logoSize(double value) {
    if (_logoSize != value) {
      _logoSize = value;
      notifyListeners();
    }
  }

  double _textX;
  double get textX => _textX;
  set textX(double value) {
    if (_textX != value) {
      _textX = value;
      notifyListeners();
    }
  }

  double _textY;
  double get textY => _textY;
  set textY(double value) {
    if (_textY != value) {
      _textY = value;
      notifyListeners();
    }
  }

  int _bgColorValue;
  int get bgColorValue => _bgColorValue;
  set bgColorValue(int value) {
    if (_bgColorValue != value) {
      _bgColorValue = value;
      notifyListeners();
    }
  }

  int _textColorValue;
  int get textColorValue => _textColorValue;
  set textColorValue(int value) {
    if (_textColorValue != value) {
      _textColorValue = value;
      notifyListeners();
    }
  }

  /// Shapes parsed from an imported PPTX slide.
  /// Empty for non-imported slides — use title/subtitle rendering instead.
  List<PptxShape> pptxShapes;

  /// Original slide height in EMUs — used by [PptxSlideRenderer] for
  /// accurate font-size scaling. 0 for non-imported slides.
  double pptxSlideHeightEmu;

  /// Decoded background image bytes (pre-populated to prevent UI thread lag).
  final Uint8List? bgImageBytes;

  SlideData({
    required this.id,
    required String title,
    required String subtitle,
    required String imageUrl,
    double opacity = 0.85,
    double blur = 12.0,
    bool isBold = false,
    bool isItalic = true,
    TextAlign alignment = TextAlign.center,
    String transition = 'Cross Dissolve',
    double titleFontSize = 48.0,
    double subtitleFontSize = 20.0,
    String? logoUrl,
    double logoX = 0.85,
    double logoY = 0.05,
    double logoSize = 80.0,
    double textX = 0.0,
    double textY = 0.0,
    int bgColorValue = 0xFF000000,
    int textColorValue = 0xFFFFFFFF,
    String? sectionId,
    List<PptxShape>? pptxShapes,
    double pptxSlideHeightEmu = 0.0,
    this.bgImageBytes,
  })  : _title = title,
        _subtitle = subtitle,
        _imageUrl = imageUrl,
        _opacity = opacity,
        _blur = blur,
        _isBold = isBold,
        _isItalic = isItalic,
        _alignment = alignment,
        _transition = transition,
        _titleFontSize = titleFontSize,
        _subtitleFontSize = subtitleFontSize,
        _logoUrl = logoUrl,
        _logoX = logoX,
        _logoY = logoY,
        _logoSize = logoSize,
        _textX = textX,
        _textY = textY,
        _bgColorValue = bgColorValue,
        _textColorValue = textColorValue,
        _sectionId = sectionId,
        pptxShapes = pptxShapes ?? [],
        pptxSlideHeightEmu = pptxSlideHeightEmu;

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
      'textColorValue': textColorValue,
      'sectionId': sectionId,
      'pptxShapes': pptxShapes.map((s) => s.toJson()).toList(),
      'pptxSlideHeightEmu': pptxSlideHeightEmu,
    };
  }

  factory SlideData.fromJson(Map<String, dynamic> json) {
    final rawShapes = json['pptxShapes'] as List<dynamic>?;
    final imgUrl = json['imageUrl'] as String? ?? '';
    Uint8List? bgBytes;
    if (imgUrl.startsWith('data:')) {
      try {
        final comma = imgUrl.indexOf(',');
        if (comma != -1) {
          bgBytes = base64Decode(imgUrl.substring(comma + 1));
        }
      } catch (_) {}
    }

    return SlideData(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      imageUrl: imgUrl,
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
      textColorValue: json['textColorValue'] as int? ?? 0xFFFFFFFF,
      sectionId: json['sectionId'] as String?,
      pptxShapes: rawShapes != null
          ? rawShapes
              .cast<Map<String, dynamic>>()
              .map(PptxShape.fromJson)
              .toList()
          : [],
      pptxSlideHeightEmu: (json['pptxSlideHeightEmu'] as num?)?.toDouble() ?? 0.0,
      bgImageBytes: bgBytes,
    );
  }

  SlideData clone({String? newId}) {
    return SlideData(
      id: newId ?? id,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      opacity: opacity,
      blur: blur,
      isBold: isBold,
      isItalic: isItalic,
      alignment: alignment,
      transition: transition,
      titleFontSize: titleFontSize,
      subtitleFontSize: subtitleFontSize,
      logoUrl: logoUrl,
      logoX: logoX,
      logoY: logoY,
      logoSize: logoSize,
      textX: textX,
      textY: textY,
      bgColorValue: bgColorValue,
      textColorValue: textColorValue,
      sectionId: sectionId,
      pptxShapes: pptxShapes.map((s) => PptxShape(
        left: s.left,
        top: s.top,
        width: s.width,
        height: s.height,
        text: s.text,
        fontSize: s.fontSize,
        isBold: s.isBold,
        isItalic: s.isItalic,
        colorValue: s.colorValue,
        align: s.align,
        imageDataUri: s.imageDataUri,
        fillColorValue: s.fillColorValue,
        fontFamily: s.fontFamily,
        imageBytes: s.imageBytes,
      )).toList(),
      pptxSlideHeightEmu: pptxSlideHeightEmu,
      bgImageBytes: bgImageBytes,
    );
  }

  void update() {
    notifyListeners();
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

  bool _isOnboarded = false;
  bool get isOnboarded => _isOnboarded;
  set isOnboarded(bool value) {
    if (_isOnboarded != value) {
      _isOnboarded = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _userName = '';
  String get userName => _userName;
  set userName(String value) {
    if (_userName != value) {
      _userName = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _userMinistry = '';
  String get userMinistry => _userMinistry;
  set userMinistry(String value) {
    if (_userMinistry != value) {
      _userMinistry = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _userChurch = '';
  String get userChurch => _userChurch;
  set userChurch(String value) {
    if (_userChurch != value) {
      _userChurch = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _userEmail = '';
  String get userEmail => _userEmail;
  set userEmail(String value) {
    if (_userEmail != value) {
      _userEmail = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _userPhone = '';
  String get userPhone => _userPhone;
  set userPhone(String value) {
    if (_userPhone != value) {
      _userPhone = value;
      saveSettings();
      notifyListeners();
    }
  }

  DateTime? _lastFeedbackPromptTime;
  DateTime? get lastFeedbackPromptTime => _lastFeedbackPromptTime;
  set lastFeedbackPromptTime(DateTime? value) {
    if (_lastFeedbackPromptTime != value) {
      _lastFeedbackPromptTime = value;
      saveSettings();
      notifyListeners();
    }
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

  int _bibleBgColor = 0xFF2E0052; // Default to deep primary purple
  int get bibleBgColor => _bibleBgColor;
  set bibleBgColor(int value) {
    if (_bibleBgColor != value) {
      _bibleBgColor = value;
      saveSettings();
      notifyListeners();
    }
  }

  int _bibleTextColor = 0xFFFFFFFF; // Default to white
  int get bibleTextColor => _bibleTextColor;
  set bibleTextColor(int value) {
    if (_bibleTextColor != value) {
      _bibleTextColor = value;
      saveSettings();
      notifyListeners();
    }
  }

  double _bibleFontSize = 36.0;
  double get bibleFontSize => _bibleFontSize;
  set bibleFontSize(double value) {
    if (_bibleFontSize != value) {
      _bibleFontSize = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _bibleFontFamily = 'Libre Caslon Text';
  String get bibleFontFamily => _bibleFontFamily;
  set bibleFontFamily(String value) {
    if (_bibleFontFamily != value) {
      _bibleFontFamily = value;
      saveSettings();
      notifyListeners();
    }
  }

  bool _bibleIsBold = false;
  bool get bibleIsBold => _bibleIsBold;
  set bibleIsBold(bool value) {
    if (_bibleIsBold != value) {
      _bibleIsBold = value;
      saveSettings();
      notifyListeners();
    }
  }

  bool _bibleIsItalic = false;
  bool get bibleIsItalic => _bibleIsItalic;
  set bibleIsItalic(bool value) {
    if (_bibleIsItalic != value) {
      _bibleIsItalic = value;
      saveSettings();
      notifyListeners();
    }
  }

  // Automatic Verse Splitting
  bool _bibleAutoSplit = true;
  bool get bibleAutoSplit => _bibleAutoSplit;
  set bibleAutoSplit(bool value) {
    if (_bibleAutoSplit != value) {
      _bibleAutoSplit = value;
      saveSettings();
      notifyListeners();
    }
  }

  int _bibleMaxLines = 4;
  int get bibleMaxLines => _bibleMaxLines;
  set bibleMaxLines(int value) {
    if (_bibleMaxLines != value) {
      _bibleMaxLines = value;
      saveSettings();
      notifyListeners();
    }
  }

  int _bibleMaxChars = 150;
  int get bibleMaxChars => _bibleMaxChars;
  set bibleMaxChars(int value) {
    if (_bibleMaxChars != value) {
      _bibleMaxChars = value;
      saveSettings();
      notifyListeners();
    }
  }

  // Customizable Keyboard Shortcuts Map (Action Name -> Key Name / Code)
  Map<String, String> _customShortcuts = {
    'nextSlide': 'Arrow Right',
    'prevSlide': 'Arrow Left',
    'firstSlide': 'Home',
    'lastSlide': 'End',
    'toggleFullscreen': 'F',
    'exitPresentation': 'Escape',
    'blackScreen': 'B',
    'whiteScreen': 'W',
    'pausePresentation': 'P',
    'toggleTimer': 'T',
    'toggleLowerThird': 'L',
    'togglePiP': 'O',
    'openComparison': 'C',
    'showDailyVerse': 'D',
  };

  Map<String, String> get customShortcuts => _customShortcuts;

  void updateShortcut(String action, String keyName) {
    _customShortcuts[action] = keyName;
    saveSettings();
    notifyListeners();
  }

  // Livestream Overlays & Display settings
  bool _useLowerThird = false;
  bool get useLowerThird => _useLowerThird;
  set useLowerThird(bool val) {
    _useLowerThird = val;
    saveSettings();
    notifyListeners();
  }

  bool _usePiP = false;
  bool get usePiP => _usePiP;
  set usePiP(bool val) {
    _usePiP = val;
    saveSettings();
    notifyListeners();
  }

  // Countdown Timer Logic
  int _timerDurationSeconds = 300; // Default to 5 minutes
  int _timerRemainingSeconds = 300;
  bool _isTimerRunning = false;
  Timer? _countdownTimer;
  bool _showTimerOnAudience = true;
  double _timerOverlayWidth = 180.0;
  double _timerOverlayHeight = 70.0;
  double _timerOverlayFontSize = 24.0;

  int get timerRemainingSeconds => _timerRemainingSeconds;
  bool get isTimerRunning => _isTimerRunning;
  bool get showTimerOnAudience => _showTimerOnAudience;
  int get timerDurationSeconds => _timerDurationSeconds;
  double get timerOverlayWidth => _timerOverlayWidth;
  double get timerOverlayHeight => _timerOverlayHeight;
  double get timerOverlayFontSize => _timerOverlayFontSize;

  set timerOverlayWidth(double val) {
    _timerOverlayWidth = val;
    saveSettings();
    notifyListeners();
  }

  set timerOverlayHeight(double val) {
    _timerOverlayHeight = val;
    saveSettings();
    notifyListeners();
  }

  set timerOverlayFontSize(double val) {
    _timerOverlayFontSize = val;
    saveSettings();
    notifyListeners();
  }

  set showTimerOnAudience(bool val) {
    _showTimerOnAudience = val;
    saveSettings();
    notifyListeners();
  }

  set timerDurationSeconds(int val) {
    _timerDurationSeconds = val;
    _timerRemainingSeconds = val;
    saveSettings();
    notifyListeners();
  }

  void startCountdown() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerRemainingSeconds > 0) {
        _timerRemainingSeconds--;
        notifyListeners();
      } else {
        stopCountdown();
      }
    });
    notifyListeners();
  }

  void stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isTimerRunning = false;
    notifyListeners();
  }

  void resetCountdown() {
    stopCountdown();
    _timerRemainingSeconds = _timerDurationSeconds;
    notifyListeners();
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
  String? get logoUrl => _logoUrl;
  set logoUrl(String? value) {
    if (_logoUrl != value) {
      _logoUrl = value;
      saveSettings();
      notifyListeners();
    }
  }

  DateTime? _lastPdfConversionTime;
  DateTime? get lastPdfConversionTime => _lastPdfConversionTime;
  set lastPdfConversionTime(DateTime? value) {
    if (_lastPdfConversionTime != value) {
      _lastPdfConversionTime = value;
      saveSettings();
      notifyListeners();
    }
  }

  String _convertApiKey = const String.fromEnvironment('CONVERT_API_KEY', defaultValue: '');
  String get convertApiKey => _convertApiKey;
  set convertApiKey(String value) {
    final trimmed = value.trim();
    if (_convertApiKey != trimmed) {
      _convertApiKey = trimmed;
      saveSettings();
      notifyListeners();
    }
  }

  String _geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  String get geminiApiKey => _geminiApiKey;
  set geminiApiKey(String value) {
    final trimmed = value.trim();
    if (_geminiApiKey != trimmed) {
      _geminiApiKey = trimmed;
      saveSettings();
      notifyListeners();
    }
  }

  String _slidesGptApiKey = const String.fromEnvironment('SLIDESGPT_API_KEY', defaultValue: '');
  String get slidesGptApiKey => _slidesGptApiKey;
  set slidesGptApiKey(String value) {
    final trimmed = value.trim();
    if (_slidesGptApiKey != trimmed) {
      _slidesGptApiKey = trimmed;
      saveSettings();
      notifyListeners();
    }
  }

  String _gammaApiKey = const String.fromEnvironment('GAMMA_API_KEY', defaultValue: '');
  String get gammaApiKey => _gammaApiKey;
  set gammaApiKey(String value) {
    final trimmed = value.trim();
    if (_gammaApiKey != trimmed) {
      _gammaApiKey = trimmed;
      saveSettings();
      notifyListeners();
    }
  }

  String _presentationsAiApiKey = const String.fromEnvironment('PRESENTATIONS_AI_API_KEY', defaultValue: '');
  String get presentationsAiApiKey => _presentationsAiApiKey;
  set presentationsAiApiKey(String value) {
    final trimmed = value.trim();
    if (_presentationsAiApiKey != trimmed) {
      _presentationsAiApiKey = trimmed;
      saveSettings();
      notifyListeners();
    }
  }

  bool get canConvertPdf {
    if (_lastPdfConversionTime == null) return true;
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _lastPdfConversionTime!.isBefore(oneWeekAgo);
  }

  String get nextPdfConversionTimeRemaining {
    if (_lastPdfConversionTime == null) return '';
    final nextAvailableTime = _lastPdfConversionTime!.add(const Duration(days: 7));
    final diff = nextAvailableTime.difference(DateTime.now());
    if (diff.isNegative) return '';
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    } else {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    }
  }

  void recordPdfConversion() {
    _lastPdfConversionTime = DateTime.now();
    saveSettings();
    notifyListeners();
  }



  // Active Slides and selection tracking for Go Live feature
  late List<SlideData> _activeSlides;
  List<SlideData> get activeSlides => _activeSlides;
  void updateActiveSlides(List<SlideData> slides) {
    _activeSlides = List.from(slides);
    notifyListeners();
    PresentationController.instance.updateSlides(slides);
  }

  List<SlideSection> _activeSections = [];
  List<SlideSection> get activeSections => _activeSections;
  void updateActiveSections(List<SlideSection> sections) {
    _activeSections = List.from(sections);
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

  double _averageSlideDuration = 6.0;
  double get averageSlideDuration => _averageSlideDuration;
  set averageSlideDuration(double value) {
    if (_averageSlideDuration != value) {
      _averageSlideDuration = value;
      notifyListeners();
    }
  }

  // ── Recent Presentations ───────────────────────────────────────────────────
  bool _recentPresentationsDirty = false;
  final List<PresentationRecord> _recentPresentations = [];
  List<PresentationRecord> get recentPresentations =>
      List.unmodifiable(_recentPresentations);

  Future<void> _saveSlidesToPrefs(String presentationId, List<SlideData> slides) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'pres_slides_$presentationId';
      final slidesJson = slides.map((s) => s.toJson()).toList();
      await prefs.setString(key, json.encode(slidesJson));
    } catch (e) {
      debugPrint('Error saving slides to prefs: $e');
    }
  }

  Future<void> _deleteSlidesFromPrefs(String presentationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'pres_slides_$presentationId';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Error deleting slides from prefs: $e');
    }
  }

  Future<List<SlideData>> getSlidesForPresentation(String presentationId) async {
    // If the presentation is in memory and has slides loaded, return them
    final idx = _recentPresentations.indexWhere((r) => r.id == presentationId);
    if (idx != -1 && _recentPresentations[idx].slides.isNotEmpty) {
      return _recentPresentations[idx].slides;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'pres_slides_$presentationId';
      final slidesJson = prefs.getString(key);
      if (slidesJson != null) {
        final List<dynamic> decoded = json.decode(slidesJson);
        return decoded
            .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading slides from prefs: $e');
    }
    return [];
  }

  void addRecentPresentation(PresentationRecord record) {
    _recentPresentationsDirty = true;
    _recentPresentations.removeWhere((r) => r.id == record.id);
    
    // Save lightweight version in memory
    final lightweightRecord = PresentationRecord(
      id: record.id,
      title: record.title,
      slideCount: record.slideCount,
      thumbnailUrl: record.thumbnailUrl,
      createdAt: record.createdAt,
      slides: [], // Keep empty in memory to save 99% space!
      outlineText: record.outlineText,
      sections: record.sections,
    );

    _recentPresentations.insert(0, lightweightRecord); // newest first
    if (_recentPresentations.length > 12) {
      final removed = _recentPresentations.removeLast();
      _deleteSlidesFromPrefs(removed.id);
    }
    
    // Save slides dynamically to dedicated key
    _saveSlidesToPrefs(record.id, record.slides);
    
    saveSettings();
    notifyListeners();
  }

  void deleteRecentPresentation(String id) {
    _recentPresentationsDirty = true;
    _recentPresentations.removeWhere((r) => r.id == id);
    _deleteSlidesFromPrefs(id);
    saveSettings();
    notifyListeners();
  }

  void renameRecentPresentation(String id, String newTitle) {
    final index = _recentPresentations.indexWhere((r) => r.id == id);
    if (index != -1) {
      _recentPresentationsDirty = true;
      final oldRecord = _recentPresentations[index];
      _recentPresentations[index] = PresentationRecord(
        id: oldRecord.id,
        title: newTitle,
        slideCount: oldRecord.slideCount,
        thumbnailUrl: oldRecord.thumbnailUrl,
        createdAt: oldRecord.createdAt,
        slides: [], // Keep empty in memory
        outlineText: oldRecord.outlineText,
        sections: oldRecord.sections,
      );
      saveSettings();
      notifyListeners();
    }
  }

  void duplicateRecentPresentation(String id) async {
    final index = _recentPresentations.indexWhere((r) => r.id == id);
    if (index != -1) {
      final oldRecord = _recentPresentations[index];
      final slidesList = await getSlidesForPresentation(id);
      
      final String newId = '${oldRecord.id}_copy_${DateTime.now().millisecondsSinceEpoch}';
      final newRecord = PresentationRecord(
        id: newId,
        title: '${oldRecord.title} (Copy)',
        slideCount: oldRecord.slideCount,
        thumbnailUrl: oldRecord.thumbnailUrl,
        createdAt: DateTime.now(),
        slides: [], // Keep empty in memory
        outlineText: oldRecord.outlineText,
        sections: oldRecord.sections,
      );
      
      await _saveSlidesToPrefs(newId, slidesList.map((s) => s.clone()).toList());
      
      _recentPresentations.insert(index + 1, newRecord);
      _recentPresentationsDirty = true;
      saveSettings();
      notifyListeners();
    }
  }

  void clearCache() async {
    _recentPresentationsDirty = true;
    for (final r in _recentPresentations) {
      _deleteSlidesFromPrefs(r.id);
    }
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
      _isOnboarded = prefs.getBool('isOnboarded') ?? _isOnboarded;
      _userName = prefs.getString('userName') ?? _userName;
      _userMinistry = prefs.getString('userMinistry') ?? _userMinistry;
      _userChurch = prefs.getString('userChurch') ?? _userChurch;
      _userEmail = prefs.getString('userEmail') ?? _userEmail;
      _userPhone = prefs.getString('userPhone') ?? _userPhone;
      final lastFeedbackTimeStr = prefs.getString('lastFeedbackPromptTime');
      if (lastFeedbackTimeStr != null) {
        _lastFeedbackPromptTime = DateTime.parse(lastFeedbackTimeStr);
      }

      final colorVal = prefs.getInt('primaryColor');
      if (colorVal != null) {
        _primaryColor = Color(colorVal);
      }
      _fontFamily = prefs.getString('fontFamily') ?? _fontFamily;
      _churchName = prefs.getString('churchName') ?? _churchName;
      _churchEmail = prefs.getString('churchEmail') ?? _churchEmail;
      _logoUrl = prefs.getString('logoUrl');
      _convertApiKey = (prefs.getString('convertApiKey') ?? _convertApiKey).trim();
      _geminiApiKey = (prefs.getString('geminiApiKey') ?? _geminiApiKey).trim();
      _slidesGptApiKey = (prefs.getString('slidesGptApiKey') ?? _slidesGptApiKey).trim();
      _gammaApiKey = (prefs.getString('gammaApiKey') ?? _gammaApiKey).trim();
      _presentationsAiApiKey = (prefs.getString('presentationsAiApiKey') ?? _presentationsAiApiKey).trim();
      
      // Load Bible custom styles
      _bibleBgColor = prefs.getInt('bibleBgColor') ?? _bibleBgColor;
      _bibleTextColor = prefs.getInt('bibleTextColor') ?? _bibleTextColor;
      _bibleFontSize = prefs.getDouble('bibleFontSize') ?? _bibleFontSize;
      _bibleFontFamily = prefs.getString('bibleFontFamily') ?? _bibleFontFamily;
      _bibleIsBold = prefs.getBool('bibleIsBold') ?? _bibleIsBold;
      _bibleIsItalic = prefs.getBool('bibleIsItalic') ?? _bibleIsItalic;
      _bibleAutoSplit = prefs.getBool('bibleAutoSplit') ?? _bibleAutoSplit;
      _bibleMaxLines = prefs.getInt('bibleMaxLines') ?? _bibleMaxLines;
      _bibleMaxChars = prefs.getInt('bibleMaxChars') ?? _bibleMaxChars;

      _timerOverlayWidth = prefs.getDouble('timerOverlayWidth') ?? _timerOverlayWidth;
      _timerOverlayHeight = prefs.getDouble('timerOverlayHeight') ?? _timerOverlayHeight;
      _timerOverlayFontSize = prefs.getDouble('timerOverlayFontSize') ?? _timerOverlayFontSize;

      final shortcutsJson = prefs.getString('customShortcuts');
      if (shortcutsJson != null) {
        try {
          final Map<String, dynamic> map = json.decode(shortcutsJson);
          map.forEach((k, v) {
            _customShortcuts[k] = v.toString();
          });
        } catch (_) {}
      }

      final lastPdfTimeStr = prefs.getString('lastPdfConversionTime');
      if (lastPdfTimeStr != null) {
        _lastPdfConversionTime = DateTime.parse(lastPdfTimeStr);
      }

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

  Timer? _saveTimer;
  Completer<void>? _saveCompleter;

  /// Debounced saveSettings to batch disk writes and prevent UI stutter during user edits
  Future<void> saveSettings() async {
    _saveTimer?.cancel();
    _saveCompleter ??= Completer<void>();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      final completer = _saveCompleter;
      _saveCompleter = null;
      try {
        await saveSettingsImmediately();
        completer?.complete();
      } catch (e) {
        completer?.completeError(e);
      }
    });
    return _saveCompleter!.future;
  }

  /// Flushes settings to disk immediately (e.g. before exiting the page or app)
  Future<void> saveSettingsImmediately() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setBool('isOffline', _isOffline);
      await prefs.setBool('isOnboarded', _isOnboarded);
      await prefs.setString('userName', _userName);
      await prefs.setString('userMinistry', _userMinistry);
      await prefs.setString('userChurch', _userChurch);
      await prefs.setString('userEmail', _userEmail);
      await prefs.setString('userPhone', _userPhone);
      if (_lastFeedbackPromptTime != null) {
        await prefs.setString('lastFeedbackPromptTime', _lastFeedbackPromptTime!.toIso8601String());
      } else {
        await prefs.remove('lastFeedbackPromptTime');
      }

      await prefs.setInt('primaryColor', _primaryColor.value);
      await prefs.setString('fontFamily', _fontFamily);
      await prefs.setString('churchName', _churchName);
      await prefs.setString('churchEmail', _churchEmail);
      if (_logoUrl != null) {
        await prefs.setString('logoUrl', _logoUrl!);
      } else {
        await prefs.remove('logoUrl');
      }

      await prefs.setString('convertApiKey', _convertApiKey);
      await prefs.setString('geminiApiKey', _geminiApiKey);
      await prefs.setString('slidesGptApiKey', _slidesGptApiKey);
      await prefs.setString('gammaApiKey', _gammaApiKey);
      await prefs.setString('presentationsAiApiKey', _presentationsAiApiKey);

      // Save Bible custom styles
      await prefs.setInt('bibleBgColor', _bibleBgColor);
      await prefs.setInt('bibleTextColor', _bibleTextColor);
      await prefs.setDouble('bibleFontSize', _bibleFontSize);
      await prefs.setString('bibleFontFamily', _bibleFontFamily);
      await prefs.setBool('bibleIsBold', _bibleIsBold);
      await prefs.setBool('bibleIsItalic', _bibleIsItalic);
      await prefs.setBool('bibleAutoSplit', _bibleAutoSplit);
      await prefs.setInt('bibleMaxLines', _bibleMaxLines);
      await prefs.setInt('bibleMaxChars', _bibleMaxChars);
      await prefs.setString('customShortcuts', json.encode(_customShortcuts));

      await prefs.setDouble('timerOverlayWidth', _timerOverlayWidth);
      await prefs.setDouble('timerOverlayHeight', _timerOverlayHeight);
      await prefs.setDouble('timerOverlayFontSize', _timerOverlayFontSize);

      if (_lastPdfConversionTime != null) {
        await prefs.setString('lastPdfConversionTime', _lastPdfConversionTime!.toIso8601String());
      } else {
        await prefs.remove('lastPdfConversionTime');
      }

      if (_recentPresentationsDirty) {
        // Loop to try saving, removing oldest presentation if QuotaExceededError or write failure occurs
        while (true) {
          try {
            final List<Map<String, dynamic>> recentListJson =
                _recentPresentations.map((r) => r.toJson(includeSlides: false)).toList();
            await prefs.setString('recentPresentations', json.encode(recentListJson));
            _recentPresentationsDirty = false;
            break; // successfully saved!
          } catch (e) {
            // If it is a QuotaExceededError or save failure, and we have presentations to remove, remove the oldest one
            if (_recentPresentations.isNotEmpty) {
              final removed = _recentPresentations.removeLast();
              _deleteSlidesFromPrefs(removed.id);
            } else {
              // Nothing left to evict, rethrow
              rethrow;
            }
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

