import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

/// A widget that displays text with clickable links
class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// Regular expression to match URLs
  static final RegExp _urlRegex = RegExp(
    r'(?:(?:https?|ftp):\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? DefaultTextStyle.of(context).style;
    // Use a link color that contrasts well with the text color
    final textColor = textStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final isLightText = textColor.computeLuminance() > 0.5;
    final linkColor = isLightText 
        ? Colors.blue.shade300  // Lighter blue for dark backgrounds
        : Colors.blue.shade700; // Darker blue for light backgrounds
    final linkStyle = textStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
    );

    // Find all URLs in the text
    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      // No URLs found, return regular text
      return Text(
        text,
        style: textStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Build TextSpan list with clickable links
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: textStyle,
        ));
      }

      // Add the clickable URL
      final url = match.group(0)!;
      final urlToLaunch = url.startsWith(RegExp(r'https?://|ftp://'))
          ? url
          : 'https://$url';

      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(urlToLaunch);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastEnd = match.end;
    }

    // Add remaining text after the last URL
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: textStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

