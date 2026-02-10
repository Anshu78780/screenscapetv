import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_types.dart';
import '../extractors/gdflix_extractor.dart';
import '../extractors/gofile_extractor.dart';
import 'headers.dart';

Future<List<Stream>> filmyCabGetStream(String link, String type) async {
  try {
    print('FilmyCab getting stream for: $link, type: $type');

    // Check if the link is already a hubcloud link
    if (link.contains('hubcloud')) {
      print('FilmyCab: Processing hubcloud link directly');
      try {
        final res = await HubCloudExtractor.extractLinks(link);
        if (res.streams.isNotEmpty) {
          print('FilmyCab: Successfully extracted streams via hubcloud');
          return res.streams;
        }
      } catch (e) {
        print('FilmyCab: Hubcloud extraction failed: $e');
      }
      return [];
    }

    // Check if the link is already a gdflix link
    if (link.contains('gdflix')) {
      print('FilmyCab: Processing gdflix link directly');
      try {
        final streams = await GdFlixExtractor.extractStreams(link);
        if (streams.isNotEmpty) {
          print('FilmyCab: Successfully extracted streams via gdflix');
          return streams;
        }
      } catch (e) {
        print('FilmyCab: GDFlix extraction failed: $e');
      }
      return [];
    }

    // Check if the link is already a gofile link
    if (link.contains('gofile.io')) {
      print('FilmyCab: Processing gofile link directly');
      try {
        final gofileId = link.split('/d/').length > 1
            ? link.split('/d/')[1]
            : null;
        if (gofileId != null) {
          final result = await GofileExtractor.extractLink(gofileId);
          if (result.success && result.link.isNotEmpty) {
            print('FilmyCab: Successfully extracted stream via gofile');
            return [
              Stream(
                server: 'GoFile',
                link: result.link,
                type: 'mkv',
                headers: {
                  'referer': 'https://gofile.io/',
                  'cookie': 'accountToken=${result.token}',
                },
              ),
            ];
          }
        }
      } catch (e) {
        print('FilmyCab: GoFile extraction failed: $e');
      }
      return [];
    }

    // If it's a redirect page, fetch and parse it to find download links
    print('FilmyCab: Fetching redirect page to find download links');
    final response = await http.get(
      Uri.parse(link),
      headers: FilmyCabHeaders.headers,
    );

    if (response.statusCode != 200) {
      print('FilmyCab: Failed to fetch redirect page');
      return [];
    }

    final document = html_parser.parse(response.body);
    final directStreams = <Stream>[];

    // Extract HubCloud, GDFlix, and GoFile links
    final hubcloudLink = document
        .querySelector('a.button3[href*="hubcloud"]')
        ?.attributes['href'];
    final gdflixLink = document
        .querySelector('a.button1[href*="gdflix"]')
        ?.attributes['href'];
    final gofileLink = document
        .querySelector('a.button2[href*="gofile.io"]')
        ?.attributes['href'];

    // Extract direct download links
    // Ultra Fast Download (AWS storage) - button2 but not gofile or telegram
    for (var element in document.querySelectorAll('a.button2')) {
      final href = element.attributes['href'];
      final text = element.text.trim();

      if (href != null &&
          !href.contains('gofile.io') &&
          !href.contains('t.me') &&
          !text.toLowerCase().contains('telegram')) {
        print('Found Ultra Fast Download link: $href');
        directStreams.add(
          Stream(server: 'Ultra Fast Download', link: href, type: 'mkv'),
        );
      }
    }

    // Direct Download - button class
    for (var element in document.querySelectorAll('a.button')) {
      final href = element.attributes['href'];
      final text = element.text.trim();

      if (href != null && text.contains('Direct Download')) {
        print('Found Direct Download link: $href');
        directStreams.add(
          Stream(server: 'Direct Download', link: href, type: 'mkv'),
        );
      }
    }

    print(
      'FilmyCab extracted links: hubcloud=$hubcloudLink, gdflix=$gdflixLink, gofile=$gofileLink, directStreams=${directStreams.length}',
    );

    // Process extracted links using extractors
    final allStreams = <Stream>[...directStreams];

    if (hubcloudLink != null) {
      print('Processing HubCloud link: $hubcloudLink');
      try {
        final res = await HubCloudExtractor.extractLinks(hubcloudLink);
        allStreams.addAll(res.streams);
      } catch (e) {
        print('HubCloud extraction error: $e');
      }
    }

    if (gdflixLink != null) {
      print('Processing GDFlix link: $gdflixLink');
      try {
        final streams = await GdFlixExtractor.extractStreams(gdflixLink);
        allStreams.addAll(streams);
      } catch (e) {
        print('GDFlix extraction error: $e');
      }
    }

    if (gofileLink != null) {
      print('Processing GoFile link: $gofileLink');
      final gofileId = gofileLink.split('/d/').length > 1
          ? gofileLink.split('/d/')[1]
          : null;
      if (gofileId != null) {
        try {
          final result = await GofileExtractor.extractLink(gofileId);
          if (result.success && result.link.isNotEmpty) {
            allStreams.add(
              Stream(
                server: 'GoFile',
                link: result.link,
                type: 'mkv',
                headers: {
                  'referer': 'https://gofile.io/',
                  'cookie': 'accountToken=${result.token}',
                },
              ),
            );
          }
        } catch (e) {
          print('GoFile extraction error: $e');
        }
      }
    }

    print('FilmyCab total extracted streams: ${allStreams.length}');
    return allStreams;
  } catch (e) {
    print('FilmyCab getStream error: $e');
    return [];
  }
}
