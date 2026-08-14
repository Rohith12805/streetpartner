import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Reusable Brand Text widget for "Sheild" where "She" is colored in the app's primary blue
/// and "ild" (plus any suffix) uses the base styling.
class SheildBrandText extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final Color? suffixColor;
  final String? suffix;
  final double? letterSpacing;
  final TextAlign textAlign;

  const SheildBrandText({
    super.key,
    this.fontSize = 22,
    this.fontWeight = FontWeight.bold,
    this.suffixColor,
    this.suffix,
    this.letterSpacing,
    this.textAlign = TextAlign.start,
  });

  /// Helper to get an inline TextSpan for "SHEild"
  static TextSpan span({
    TextStyle? baseStyle,
    Color blueColor = AppTheme.primary,
    String suffix = '',
  }) {
    final style = baseStyle ?? GoogleFonts.inter();
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: 'SHE',
          style: style.copyWith(
            color: blueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: 'ild$suffix',
          style: style,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSuffixColor = suffixColor ?? AppTheme.onBackground;

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing ?? -0.3,
        ),
        children: [
          const TextSpan(
            text: 'SHE',
            style: TextStyle(
              color: AppTheme.primary,
            ),
          ),
          TextSpan(
            text: 'ild${suffix != null ? ' $suffix' : ''}',
            style: TextStyle(
              color: effectiveSuffixColor,
            ),
          ),
        ],
      ),
    );
  }
}
