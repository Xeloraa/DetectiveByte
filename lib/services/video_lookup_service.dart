import 'dart:convert';

import 'package:http/http.dart' as http;

/// Metadata Byte fetched about a TikTok / YouTube / Reels link.
class VideoInfo {
  const VideoInfo({
    required this.platform,
    required this.title,
    this.author,
    this.thumbnailUrl,
  });

  final String platform;
  final String title;
  final String? author;
  final String? thumbnailUrl;
}

/// Looks up real title/author/thumbnail for a pasted video link via each
/// platform's public oEmbed endpoint — no scraping, no API key required.
abstract final class VideoLookupService {
  static final RegExp _youtube = RegExp(
    r'(youtube\.com/(watch\?v=|shorts/)|youtu\.be/)',
    caseSensitive: false,
  );
  static final RegExp _tiktok = RegExp(r'tiktok\.com/', caseSensitive: false);
  static final RegExp _instagram =
      RegExp(r'instagram\.com/(reel|p)/', caseSensitive: false);

  /// Returns null if [text] isn't a recognized video link or the lookup fails.
  static Future<VideoInfo?> lookup(String text) async {
    final url = text.trim();
    if (!url.startsWith('http')) return null;

    final Uri oembedUri;
    final String platform;
    if (_youtube.hasMatch(url)) {
      platform = 'YouTube';
      oembedUri = Uri.parse(
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
      );
    } else if (_tiktok.hasMatch(url)) {
      platform = 'TikTok';
      oembedUri = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}',
      );
    } else if (_instagram.hasMatch(url)) {
      // Instagram oEmbed requires an app token for most accounts — skip the
      // network call and just tag the platform so the UI can say so.
      return VideoInfo(platform: 'Reels', title: url);
    } else {
      return null;
    }

    try {
      final response = await http.get(oembedUri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (json['title'] as String?)?.trim();

      return VideoInfo(
        platform: platform,
        title: (title == null || title.isEmpty) ? url : title,
        author: json['author_name'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
