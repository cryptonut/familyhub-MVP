import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/services/logger_service.dart';
import '../models/chat_message.dart';

/// Service for fetching URL preview metadata (Open Graph, Twitter Cards)
class UrlPreviewService {
  static final Map<String, UrlPreview> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Fetch URL preview metadata
  Future<UrlPreview?> fetchPreview(String url) async {
    try {
      // Check cache first
      if (_cache.containsKey(url)) {
        return _cache[url];
      }

      // Fetch the URL
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; FamilyHub/1.0)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        Logger.warning('Failed to fetch URL preview: ${response.statusCode}', tag: 'UrlPreviewService');
        return null;
      }

      final html = response.body;
      final preview = _parseHtml(html, url);

      if (preview != null) {
        _cache[url] = preview;
      }

      return preview;
    } catch (e) {
      Logger.error('Error fetching URL preview', error: e, tag: 'UrlPreviewService');
      return null;
    }
  }

  /// Parse HTML for Open Graph and Twitter Card metadata
  UrlPreview? _parseHtml(String html, String url) {
    try {
      String? title;
      String? description;
      String? imageUrl;
      String? siteName;

      // Extract Open Graph tags
      final ogTitleMatch = RegExp(r'<meta\s+property=["\']og:title["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
      if (ogTitleMatch != null) {
        title = _decodeHtml(ogTitleMatch.group(1));
      }

      final ogDescriptionMatch = RegExp(r'<meta\s+property=["\']og:description["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
      if (ogDescriptionMatch != null) {
        description = _decodeHtml(ogDescriptionMatch.group(1));
      }

      final ogImageMatch = RegExp(r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
      if (ogImageMatch != null) {
        imageUrl = ogImageMatch.group(1);
        // Make relative URLs absolute
        if (imageUrl != null && !imageUrl!.startsWith('http')) {
          final uri = Uri.parse(url);
          imageUrl = '${uri.scheme}://${uri.host}${imageUrl!.startsWith('/') ? '' : '/'}$imageUrl';
        }
      }

      final ogSiteNameMatch = RegExp(r'<meta\s+property=["\']og:site_name["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
      if (ogSiteNameMatch != null) {
        siteName = _decodeHtml(ogSiteNameMatch.group(1));
      }

      // Fallback to Twitter Card tags if Open Graph not found
      if (title == null) {
        final twitterTitleMatch = RegExp(r'<meta\s+name=["\']twitter:title["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
        if (twitterTitleMatch != null) {
          title = _decodeHtml(twitterTitleMatch.group(1));
        }
      }

      if (description == null) {
        final twitterDescriptionMatch = RegExp(r'<meta\s+name=["\']twitter:description["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
        if (twitterDescriptionMatch != null) {
          description = _decodeHtml(twitterDescriptionMatch.group(1));
        }
      }

      if (imageUrl == null) {
        final twitterImageMatch = RegExp(r'<meta\s+name=["\']twitter:image["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
        if (twitterImageMatch != null) {
          imageUrl = twitterImageMatch.group(1);
        }
      }

      // Fallback to standard HTML meta tags
      if (title == null) {
        final titleMatch = RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(html);
        if (titleMatch != null) {
          title = _decodeHtml(titleMatch.group(1));
        }
      }

      if (description == null) {
        final metaDescriptionMatch = RegExp(r'<meta\s+name=["\']description["\']\s+content=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(html);
        if (metaDescriptionMatch != null) {
          description = _decodeHtml(metaDescriptionMatch.group(1));
        }
      }

      // Extract site name from URL if not found
      if (siteName == null) {
        try {
          final uri = Uri.parse(url);
          siteName = uri.host.replaceAll('www.', '');
        } catch (e) {
          // Ignore
        }
      }

      // Only return preview if we have at least a title
      if (title != null || description != null || imageUrl != null) {
        return UrlPreview(
          url: url,
          title: title,
          description: description,
          imageUrl: imageUrl,
          siteName: siteName,
        );
      }

      return null;
    } catch (e) {
      Logger.error('Error parsing HTML for preview', error: e, tag: 'UrlPreviewService');
      return null;
    }
  }

  /// Decode HTML entities
  String _decodeHtml(String html) {
    return html
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
  }

  /// Get cached preview
  static UrlPreview? getCached(String url) {
    return _cache[url];
  }
}


