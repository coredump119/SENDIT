import 'package:flutter/material.dart';

/// 英伦优雅：奶油纸色、墨棕、细线、圆角、柔和阴影、衬线。
/// 品牌三色：墨棕 #492D22 / 苔棕 #4E3D28 / 奶油 #F2E3C6。
class Tone {
  static const ink = Color(0xFF492D22);
  static const moss = Color(0xFF4E3D28);
  static const cream = Color(0xFFF2E3C6); // 选中 / 高亮
  static const bg = Color(0xFFF7EEDD); // 页面底
  static const paper = Color(0xFFFCF8F0); // 卡片 / 输入区
  static const inkSoft = Color(0xA6492D22);
  static const inkMute = Color(0x73492D22);
  static const hair = Color(0x2E492D22); // 细线
  static const hairSoft = Color(0x1A492D22);
  static const inkFaint = Color(0x0F492D22);

  static const serif = 'EBGaramond';
  static const mono = 'SpaceMono';
  static const cjk = 'NotoSansSC';
  static const fallback = [cjk];

  static const rPanel = 14.0;
  static const rSmall = 9.0;

  static const display = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 36, height: 1.05, fontWeight: FontWeight.w500, color: ink, letterSpacing: -0.2);
  static const h2 = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 22, height: 1.15, fontWeight: FontWeight.w500, color: ink);
  static const h3 = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 18, height: 1.2, fontWeight: FontWeight.w500, color: ink);
  static const numeral = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 30, height: 1, fontWeight: FontWeight.w500, color: ink, fontFeatures: [FontFeature.tabularFigures()]);
  static const body = TextStyle(fontFamilyFallback: fallback, fontSize: 13.5, height: 1.55, color: ink);
  static const bodySoft = TextStyle(fontFamilyFallback: fallback, fontSize: 12.5, height: 1.5, color: inkSoft);
  /// 小标签：衬线大写、宽字距
  static const label = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 12, letterSpacing: 1.6, color: inkSoft, fontWeight: FontWeight.w500, height: 1.2);
  static const button = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 14.5, letterSpacing: 0.4, fontWeight: FontWeight.w500, height: 1);
  static const monoText = TextStyle(fontFamilyFallback: fallback, fontFamily: mono, fontSize: 12.5, color: ink, height: 1.6);
  static const monoSmall = TextStyle(fontFamilyFallback: fallback, fontFamily: mono, fontSize: 10.5, color: inkSoft, height: 1.3);
  static const num = TextStyle(fontFamilyFallback: fallback, fontFamily: serif, fontSize: 15, color: ink, fontWeight: FontWeight.w500, height: 1.1, fontFeatures: [FontFeature.tabularFigures()]);

  static const softShadow = [BoxShadow(color: Color(0x14492D22), blurRadius: 18, offset: Offset(0, 6))];
  static const tinyShadow = [BoxShadow(color: Color(0x1F492D22), blurRadius: 10, offset: Offset(0, 3))];

  static OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(rSmall), borderSide: BorderSide(color: c, width: w));

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(primary: ink, onPrimary: paper, secondary: moss, onSecondary: paper, surface: bg, onSurface: ink, error: moss),
      textTheme: const TextTheme(bodyMedium: body, bodySmall: bodySoft).apply(fontFamily: cjk, fontFamilyFallback: fallback),
      splashFactory: NoSplash.splashFactory,
      highlightColor: inkFaint,
      hoverColor: inkFaint,
      textSelectionTheme: const TextSelectionThemeData(cursorColor: ink, selectionColor: cream, selectionHandleColor: ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: _border(hair),
        enabledBorder: _border(hair),
        focusedBorder: _border(inkSoft),
        hintStyle: const TextStyle(color: inkMute, fontSize: 12.5, fontFamilyFallback: fallback),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: hair)),
        textStyle: body,
      ),
      dividerTheme: const DividerThemeData(color: hairSoft, thickness: 1, space: 1),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStateProperty.all(inkMute), radius: const Radius.circular(4), thickness: WidgetStateProperty.all(4)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink, linearTrackColor: inkFaint),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: paper, fontSize: 11.5),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
