import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/gdflix_extractor.dart';
import '../extractors/stream_types.dart' as stream_types;

class ZinkMoviesStream {
  final String server;
  final String link;
  final String type;
  final Map<String, String>? headers;

  ZinkMoviesStream({
    required this.server,
    required this.link,
    required this.type,
    this.headers,
  });
}

/// Wrapper function that converts ZinkMoviesStream to stream_types.Stream
Future<List<stream_types.Stream>> getStream(String link, String type) async {
  final zinkStreams = await zinkmoviesGetStream(link, type);
  return zinkStreams.map((s) => stream_types.Stream(
    server: s.server,
    link: s.link,
    type: s.type,
    headers: s.headers,
  )).toList();
}

Future<List<ZinkMoviesStream>> zinkmoviesGetStream(
  String link,
  String type,
) async {
  try {
    print('ZinkMovies getStream: $link');

    // Check if this is an iframe player URL
    if (link.contains('/play/') &&
        (link.contains('ensta') || link.contains('zij.com'))) {
      return await _processIframePlayer(link);
    }

    // Check if this is a ZinkCloud file URL
    if (link.contains('zinkcloud.net/file/') ||
        link.contains('new1.zinkcloud.net/file/')) {
      return await _processZinkCloudFile(link);
    }

    // Check if this is a ZinkMovies internal link redirect
    if (link.contains('zinkmovies') && link.contains('/links/')) {
      return await _processInternalRedirect(link);
    }

    // Check if this is a videosaver.me link
    if (link.contains('videosaver.me')) {
      return await _processVideoSaver(link);
    }

    // Fallback for regular ZinkMovies page scraping
    return await _processRegularPage(link);
  } catch (error) {
    print('ZinkMovies getStream error: $error');
    return [];
  }
}

Future<List<ZinkMoviesStream>> _processIframePlayer(String link) async {
  print('Processing iframe player URL: $link');

  try {
    final response = await http.get(
      Uri.parse(link),
      headers: {
       'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );

    print('Iframe response received, searching for p3 variable...');

    // Look for the p3 variable with file URL
    final iframeHtml = response.body;
    final p3Regex = RegExp(r'let\s+p3\s*=\s*({[\s\S]*?"file":\s*"([^"]+)"[\s\S]*?});');
    final p3Match = p3Regex.firstMatch(iframeHtml);

    if (p3Match != null && p3Match.group(2) != null) {
      final fileUrl = p3Match.group(2)!.replaceAll(r'\/', '/');
      print('Found file URL in p3: $fileUrl');

      // Fetch the file URL to get the actual m3u8 link
      final fileResponse = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
          'Referer': link,
        },
      );

      final m3u8Link = fileResponse.body.trim();
      print('Got m3u8 link from file URL: $m3u8Link');

      if (m3u8Link.contains('.m3u8')) {
        return [
          ZinkMoviesStream(
            server: 'ZinkMovies Player',
            link: m3u8Link,
            type: 'm3u8',
            headers: {
              'Origin': 'null',
              'Priority': 'u=1, i',
              'Referer': 'https://new2.zinkmovies.vip/',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
        ];
      }
    } else {
      print('Could not find p3 variable with file URL in iframe');
    }
  } catch (error) {
    print('Error processing iframe player: $error');
  }

  return [];
}

Future<List<ZinkMoviesStream>> _processZinkCloudFile(String link) async {
  print('Processing ZinkCloud file URL: $link');

  // Extract file ID from URL (for potential future use)
  final fileIdMatch = RegExp(r'/file/([a-zA-Z0-9]+)').firstMatch(link);
  if (fileIdMatch == null) {
    print('Could not extract file ID from ZinkCloud URL');
    return [];
  }

  // Note: fileId and baseDomain extracted but primarily using direct page parsing
  final processedLinks = <ZinkMoviesStream>[];

  // Try to extract mirror links directly from page HTML
  try {
    final sessionResponse = await http.get(Uri.parse(link));
    final document = parser.parse(sessionResponse.body);

    // Look for HubCloud mirror button
    final hubcloudMirror = document
        .querySelector('#mirror-buttons .mirror-buttons a.btn.hubcloud')
        ?.attributes['href'];
    if (hubcloudMirror != null) {
      print('Found HubCloud mirror in page HTML: $hubcloudMirror');
      final hubResult = await HubCloudExtractor.extractLinks(hubcloudMirror);
      for (var s in hubResult.streams) {
        processedLinks.add(ZinkMoviesStream(
          server: s.server,
          link: s.link,
          type: s.type,
          headers: s.headers,
        ));
      }
    }

    // Try GDFlix if HubCloud failed
    if (processedLinks.isEmpty) {
      final gdflixMirror = document
          .querySelector('#mirror-buttons .mirror-buttons a.btn.gdflix')
          ?.attributes['href'];
      if (gdflixMirror != null) {
        print('Found GDFlix mirror in page HTML: $gdflixMirror');
        final gdStreams = await GdFlixExtractor.extractStreams(gdflixMirror);
        for (var s in gdStreams) {
          processedLinks.add(ZinkMoviesStream(
            server: s.server,
            link: s.link,
            type: s.type,
            headers: s.headers,
          ));
        }
      }
    }
  } catch (error) {
    print('Error extracting mirrors from page: $error');
  }

  return processedLinks;
}

Future<List<ZinkMoviesStream>> _processInternalRedirect(String link) async {
  print('Processing ZinkMovies internal link redirect: $link');

  try {
    final response = await http.get(Uri.parse(link));
    final document = parser.parse(response.body);

    final processedLinks = <ZinkMoviesStream>[];

    // Look for HubCloud mirrors
    final hubcloudMirror = document
        .querySelector('#mirror-buttons .mirror-buttons a.btn.hubcloud')
        ?.attributes['href'];
    if (hubcloudMirror != null) {
      print('Found HubCloud mirror: $hubcloudMirror');
      final hubResult = await HubCloudExtractor.extractLinks(hubcloudMirror);
      for (var s in hubResult.streams) {
        processedLinks.add(ZinkMoviesStream(
          server: s.server,
          link: s.link,
          type: s.type,
          headers: s.headers,
        ));
      }
    }

    // Try GDFlix if HubCloud failed
    if (processedLinks.isEmpty) {
      final gdflixMirror = document
          .querySelector('#mirror-buttons .mirror-buttons a.btn.gdflix')
          ?.attributes['href'];
      if (gdflixMirror != null) {
        print('Found GDFlix mirror: $gdflixMirror');
        final gdStreams = await GdFlixExtractor.extractStreams(gdflixMirror);
        for (var s in gdStreams) {
          processedLinks.add(ZinkMoviesStream(
            server: s.server,
            link: s.link,
            type: s.type,
            headers: s.headers,
          ));
        }
      }
    }

    return processedLinks;
  } catch (error) {
    print('Error processing internal redirect: $error');
    return [];
  }
}

Future<List<ZinkMoviesStream>> _processVideoSaver(String link) async {
  print('Processing videosaver.me link: $link');

  try {
    final response = await http.get(Uri.parse(link));
    final document = parser.parse(response.body);

    final processedLinks = <ZinkMoviesStream>[];

    // Look for HubCloud mirrors
    final hubcloudMirror = document
        .querySelector('#mirror-buttons .mirror-buttons a.btn.hubcloud')
        ?.attributes['href'];
    if (hubcloudMirror != null) {
      print('Found HubCloud mirror: $hubcloudMirror');
      final hubResult = await HubCloudExtractor.extractLinks(hubcloudMirror);
      for (var s in hubResult.streams) {
        processedLinks.add(ZinkMoviesStream(
          server: s.server,
          link: s.link,
          type: s.type,
          headers: s.headers,
        ));
      }
    }

    // Try GDFlix if HubCloud failed
    if (processedLinks.isEmpty) {
      final gdflixMirror = document
          .querySelector('#mirror-buttons .mirror-buttons a.btn.gdflix')
          ?.attributes['href'];
      if (gdflixMirror != null) {
        print('Found GDFlix mirror: $gdflixMirror');
        final gdStreams = await GdFlixExtractor.extractStreams(gdflixMirror);
        for (var s in gdStreams) {
          processedLinks.add(ZinkMoviesStream(
            server: s.server,
            link: s.link,
            type: s.type,
            headers: s.headers,
          ));
        }
      }
    }

    return processedLinks;
  } catch (error) {
    print('Error processing videosaver: $error');
    return [];
  }
}

Future<List<ZinkMoviesStream>> _processRegularPage(String link) async {
  print('Processing regular ZinkMovies page: $link');

  try {
    final response = await http.get(Uri.parse(link));
    final document = parser.parse(response.body);

    final processedLinks = <ZinkMoviesStream>[];

    // Look for HubCloud and GDFlix links in the page
    final allLinks = document.querySelectorAll('a');
    for (var element in allLinks) {
      final href = element.attributes['href'] ?? '';
      if (href.contains('hubcloud') || href.contains('vifix.site/hubcloud')) {
        print('Found HubCloud link: $href');
        try {
          final hubResult = await HubCloudExtractor.extractLinks(href);
          for (var s in hubResult.streams) {
            processedLinks.add(ZinkMoviesStream(
              server: s.server,
              link: s.link,
              type: s.type,
              headers: s.headers,
            ));
          }
          if (processedLinks.isNotEmpty) break;
        } catch (error) {
          print('Error processing HubCloud link: $error');
        }
      } else if (href.contains('gdflix') || href.contains('gdlink.dev')) {
        print('Found GDFlix link: $href');
        try {
          final gdStreams = await GdFlixExtractor.extractStreams(href);
          for (var s in gdStreams) {
            processedLinks.add(ZinkMoviesStream(
              server: s.server,
              link: s.link,
              type: s.type,
              headers: s.headers,
            ));
          }
          if (processedLinks.isNotEmpty) break;
        } catch (error) {
          print('Error processing GDFlix link: $error');
        }
      }
    }

    return processedLinks;
  } catch (error) {
    print('Error processing regular page: $error');
    return [];
  }
}
