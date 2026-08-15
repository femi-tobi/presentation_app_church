import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';

/// Renders an imported PPTX [SlideData] as a pixel-faithful Stack of shapes.
///
/// Every shape is placed at its exact fractional position/size.
/// Font sizes are scaled correctly using the original slide height in EMUs.
/// Shape background fills are rendered behind text.
///
/// Used in both the slide thumbnail card and the fullscreen presenter
/// whenever `slide.pptxShapes.isNotEmpty`.
 class PptxSlideRenderer extends StatelessWidget {
  final SlideData slide;
  final double width;
  final double height;
  final Function(int shapeIndex, double left, double top)? onShapePositionChanged;
  final Function(int shapeIndex)? onShapePositionChangedEnd;
  final Set<int> selectedShapeIndices;
  final Function(int shapeIndex)? onShapeTap;

  const PptxSlideRenderer({
    super.key,
    required this.slide,
    required this.width,
    required this.height,
    this.onShapePositionChanged,
    this.onShapePositionChangedEnd,
    this.selectedShapeIndices = const {},
    this.onShapeTap,
  });

  /// 1 pt = 12700 EMU.
  /// Converts a font size in points to screen pixels for this canvas.
  double _ptToPx(double fontPt) {
    final slideH = slide.pptxSlideHeightEmu > 0
        ? slide.pptxSlideHeightEmu
        : 6858000.0; // safe fallback (4:3)
    // pixels = fontPt * (12700 EMU/pt) / slideH_EMU * height_px
    return (fontPt * 12700.0 / slideH * height).clamp(4.0, height * 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Background ───────────────────────────────────────────────
            _buildBackground(),

            // ── Shapes in document order ─────────────────────────────────
            for (int k = 0; k < slide.pptxShapes.length; k++)
              Positioned(
                left:   slide.pptxShapes[k].left   * width,
                top:    slide.pptxShapes[k].top    * height,
                width:  slide.pptxShapes[k].width  * width,
                height: slide.pptxShapes[k].height * height,
                child:  _buildShapeWrapper(k, slide.pptxShapes[k]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeWrapper(int index, PptxShape shape) {
    final child = _buildShape(shape);
    if (onShapePositionChanged == null) return child;

    return _InteractiveShapeContainer(
      shape: shape,
      width: width,
      height: height,
      isSelected: selectedShapeIndices.contains(index),
      onTap: () => onShapeTap?.call(index),
      onPositionChanged: (newLeft, newTop) {
        onShapePositionChanged?.call(index, newLeft, newTop);
      },
      onPositionChangedEnd: () {
        onShapePositionChangedEnd?.call(index);
      },
      child: child,
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    if (slide.bgImageBytes != null && slide.bgImageBytes!.isNotEmpty) {
      return Positioned.fill(
        child: Image.memory(
          slide.bgImageBytes!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              ColoredBox(color: Color(slide.bgColorValue)),
        ),
      );
    }
    if (slide.imageUrl.isNotEmpty) {
      return Positioned.fill(
        child: slide.imageUrl.startsWith('data:')
            ? Image.memory(
                _decodeUri(slide.imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: Color(slide.bgColorValue)),
              )
            : Image.network(
                slide.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: Color(slide.bgColorValue)),
              ),
      );
    }
    return Positioned.fill(
      child: ColoredBox(color: Color(slide.bgColorValue)),
    );
  }

  // ── Shape dispatcher ──────────────────────────────────────────────────────

  Widget _buildShape(PptxShape shape) {
    if (shape.imageDataUri.isNotEmpty) {
      return _buildImage(shape);
    }

    // Text shape — possibly with a fill background
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Shape fill (colored rectangle)
        if (shape.fillColorValue != 0x00000000)
          Positioned.fill(
            child: ColoredBox(color: Color(shape.fillColorValue)),
          ),

        // Text content
        if (shape.text.isNotEmpty)
          Positioned.fill(
            child: _buildTextBox(shape),
          ),
      ],
    );
  }

  // ── Image shape ───────────────────────────────────────────────────────────

  Widget _buildImage(PptxShape shape) {
    if (shape.imageBytes != null && shape.imageBytes!.isNotEmpty) {
      return Image.memory(
        shape.imageBytes!,
        fit: BoxFit.cover, // preservation of aspect ratio for background/large pictures
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.memory(
      _decodeUri(shape.imageDataUri),
      fit: BoxFit.cover, // preservation of aspect ratio for background/large pictures
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  // ── Text box ──────────────────────────────────────────────────────────────

  Widget _buildTextBox(PptxShape shape) {
    final double pxSize = _ptToPx(shape.fontSize);

    final baseStyle = TextStyle(
      fontSize:   pxSize,
      fontWeight: shape.isBold   ? FontWeight.bold   : FontWeight.normal,
      fontStyle:  shape.isItalic ? FontStyle.italic  : FontStyle.normal,
      color:      Color(shape.colorValue),
      height:     1.15,
      shadows: const [
        Shadow(
          color:      Color(0x22000000),
          offset:     Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    TextStyle textStyle;
    try {
      textStyle = GoogleFonts.getFont(shape.fontFamily, textStyle: baseStyle);
    } catch (_) {
      textStyle = baseStyle.copyWith(fontFamily: shape.fontFamily);
    }

    return Align(
      alignment: _toAlignment(shape.align),
      child: Text(
        shape.text,
        textAlign:  shape.align,
        softWrap:   true,
        overflow:   TextOverflow.clip,
        style:      textStyle,
      ),
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  static Uint8List _decodeUri(String dataUri) {
    final comma = dataUri.indexOf(',');
    if (comma == -1) return Uint8List(0);
    return base64Decode(dataUri.substring(comma + 1));
  }

  static Alignment _toAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.center:  return Alignment.topCenter;
      case TextAlign.right:   return Alignment.topRight;
      default:                return Alignment.topLeft;
    }
  }
}

class _InteractiveShapeContainer extends StatefulWidget {
  final PptxShape shape;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback? onTap;
  final Function(double left, double top) onPositionChanged;
  final VoidCallback? onPositionChangedEnd;
  final Widget child;

  const _InteractiveShapeContainer({
    required this.shape,
    required this.width,
    required this.height,
    this.isSelected = false,
    this.onTap,
    required this.onPositionChanged,
    this.onPositionChangedEnd,
    required this.child,
  });

  @override
  State<_InteractiveShapeContainer> createState() => _InteractiveShapeContainerState();
}

class _InteractiveShapeContainerState extends State<_InteractiveShapeContainer> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final bool showBorder = widget.isSelected || _isHovered || _isDragging;
    final borderCol = widget.isSelected ? Colors.blue : Colors.blueAccent.withValues(alpha: 0.6);
    final borderWidth = widget.isSelected ? 2.0 : 1.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          final double deltaX = details.delta.dx / widget.width;
          final double deltaY = details.delta.dy / widget.height;
          widget.onPositionChanged(
            (widget.shape.left + deltaX).clamp(0.0, 1.0),
            (widget.shape.top + deltaY).clamp(0.0, 1.0),
          );
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onPositionChangedEnd?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: showBorder ? borderCol : Colors.transparent,
              width: borderWidth,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
