import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_types.dart';
import '../extractors/gdflix_extractor.dart';
import '../extractors/gofile_extractor.dart';
import '../extractors/gdirect_extractor.dart';
import '../extractors/filepress_extractor.dart';
import '../extractors/vcloud_extractor.dart';
import 'headers.dart';

Future<List<Stream>> zeeflizGetStream(String link, String type) async {
  try {
    print('Zeefliz getting stream for: $link, type: $type');

    // Check if link contains combined links (pipe-delimited)
    if (link.contains('|')) {
      print('Zeefliz: Processing combined/pipe-delimited links: $link');
      final links = link.split('|').where((l) => l.trim().isNotEmpty).toList();
      print('Zeefliz: Split into ${links.length} individual links');

      final futures = links.map((individualLink) async {
        final trimmedLink = individualLink.trim();
        print('Zeefliz: Processing individual link: $trimmedLink');

        // Process fastdl.zip links via G-Direct extractor
        if (trimmedLink.contains('fastdl.zip')) {
          print('Zeefliz: Detected fastdl.zip link, using GDirectExtractor');
          return await GDirectExtractor.extractStreams(trimmedLink);
        }
        // Process vcloud links via VCloud extractor
        else if (trimmedLink.contains('vcloud.') ||
            trimmedLink.contains('cloud.')) {
          print('Zeefliz: Detected vcloud link, using VCloudExtractor');
          return await VCloudExtractor.extractStreams(trimmedLink);
        }
        // Process filebee.xyz/filepress links via Filepress extractor
        else if (trimmedLink.contains('filebee.xyz') ||
            trimmedLink.contains('filepress.')) {
          print(
            'Zeefliz: Detected filebee/filepress link, using FilepressExtractor',
          );
          return await FilepressExtractor.extractStreams(trimmedLink);
        }
        // Process hubcloud links
        else if (trimmedLink.contains('hubcloud')) {
          print('Zeefliz: Detected hubcloud link');
          final res = await HubCloudExtractor.extractLinks(trimmedLink);
          return res.streams;
        }
        // Process gdflix links
        else if (trimmedLink.contains('gdflix')) {
          print('Zeefliz: Detected gdflix link');
          return await GdFlixExtractor.extractStreams(trimmedLink);
        }
        // Process gofile links
        else if (trimmedLink.contains('gofile.io')) {
          print('Zeefliz: Detected gofile link');
          final gofileId = trimmedLink.split('/d/').length > 1
              ? trimmedLink.split('/d/')[1]
              : null;
          if (gofileId != null) {
            final result = await GofileExtractor.extractLink(gofileId);
            if (result.success && result.link.isNotEmpty) {
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
        }

        print('Zeefliz: Unknown link type: $trimmedLink');
        return <Stream>[];
      });

      final results = await Future.wait(futures);
      final allStreams = results.expand<Stream>((x) => x).toList();
      print(
        'Zeefliz: Total streams extracted from combined links: ${allStreams.length}',
      );
      return allStreams;
    }

    // Handle direct link types (not pipe-delimited)
    if (link.contains('fastdl.zip')) {
      print('Zeefliz: Direct G-Direct/fastdl link detected');
      return await GDirectExtractor.extractStreams(link);
    }

    if (link.contains('filebee.xyz') || link.contains('filepress.')) {
      print('Zeefliz: Direct Filepress/Filebee link detected');
      return await FilepressExtractor.extractStreams(link);
    }

    if (link.contains('vcloud.') || link.contains('cloud.')) {
      print('Zeefliz: Direct V-Cloud link detected');
      return await VCloudExtractor.extractStreams(link);
    }

    // Check if the link is already a hubcloud link
    if (link.contains('hubcloud')) {
      print('Zeefliz: Processing hubcloud link directly');
      try {
        final res = await HubCloudExtractor.extractLinks(link);
        if (res.streams.isNotEmpty) {
          print('Zeefliz: Successfully extracted streams via hubcloud');
          return res.streams;
        }
      } catch (e) {
        print('Zeefliz: Hubcloud extraction failed: $e');
      }
      return [];
    }

    // Check if the link is already a gdflix link
    if (link.contains('gdflix')) {
      print('Zeefliz: Processing gdflix link directly');
      try {
        final streams = await GdFlixExtractor.extractStreams(link);
        if (streams.isNotEmpty) {
          print('Zeefliz: Successfully extracted streams via gdflix');
          return streams;
        }
      } catch (e) {
        print('Zeefliz: GDFlix extraction failed: $e');
      }
      return [];
    }

    // Check if the link is already a gofile link
    if (link.contains('gofile.io')) {
      print('Zeefliz: Processing gofile link directly');
      try {
        final gofileId = link.split('/d/').length > 1
            ? link.split('/d/')[1]
            : null;
        if (gofileId != null) {
          final result = await GofileExtractor.extractLink(gofileId);
          if (result.success && result.link.isNotEmpty) {
            print('Zeefliz: Successfully extracted stream via gofile');
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
        print('Zeefliz: GoFile extraction failed: $e');
      }
      return [];
    }

    // If it's a page URL, fetch and parse it to find download links
    print('Zeefliz: Fetching page to find download links');

    // Replace .store with .pro before making request
    final processedLink = link.replaceAll('.store', '.pro');
    print('Zeefliz: Using URL: $processedLink');

    final response = await http.get(
      Uri.parse(processedLink),
      headers: ZeeflizHeaders.headers,
    );

    if (response.statusCode != 200) {
      print('Zeefliz: Failed to fetch page');
      return [];
    }

    final document = html_parser.parse(response.body);
    final links = <String>[];

    // Extract G-Direct link (fastdl.zip)
    final gDirectLink = document
        .querySelector('a[href*="fastdl.zip"]')
        ?.attributes['href'];
    if (gDirectLink != null && gDirectLink.isNotEmpty) {
      print('Zeefliz: Found G-Direct link in page: $gDirectLink');
      links.add(gDirectLink);
    }

    // Extract V-Cloud link
    final vcloudLink = document
        .querySelector('a[href*="vcloud."], a[href*="cloud."]')
        ?.attributes['href'];
    if (vcloudLink != null && vcloudLink.isNotEmpty) {
      print('Zeefliz: Found V-Cloud link in page: $vcloudLink');
      links.add(vcloudLink);
    }

    // Extract Filepress/Filebee link
    final filepressLink = document
        .querySelector('a[href*="filebee.xyz"], a[href*="filepress."]')
        ?.attributes['href'];
    if (filepressLink != null && filepressLink.isNotEmpty) {
      print('Zeefliz: Found Filepress/Filebee link in page: $filepressLink');
      links.add(filepressLink);
    }

    // Extract HubCloud link
    final hubcloudLink = document
        .querySelector('a[href*="hubcloud"]')
        ?.attributes['href'];
    if (hubcloudLink != null && hubcloudLink.isNotEmpty) {
      print('Zeefliz: Found HubCloud link in page: $hubcloudLink');
      links.add(hubcloudLink);
    }

    // Extract GDFlix link
    final gdflixLink = document
        .querySelector('a[href*="gdflix"]')
        ?.attributes['href'];
    if (gdflixLink != null && gdflixLink.isNotEmpty) {
      print('Zeefliz: Found GDFlix link in page: $gdflixLink');
      links.add(gdflixLink);
    }

    // Extract GoFile link
    final gofileLink = document
        .querySelector('a[href*="gofile.io"]')
        ?.attributes['href'];
    if (gofileLink != null && gofileLink.isNotEmpty) {
      print('Zeefliz: Found GoFile link in page: $gofileLink');
      links.add(gofileLink);
    }

    // Process all links in parallel
    if (links.isNotEmpty) {
      print(
        'Zeefliz: Found ${links.length} links in page, processing in parallel',
      );
      final futures = links.map((individualLink) async {
        if (individualLink.contains('fastdl.zip')) {
          print('Zeefliz: Processing fastdl.zip link: $individualLink');
          return await GDirectExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('vcloud.') ||
            individualLink.contains('cloud.')) {
          print('Zeefliz: Processing vcloud link: $individualLink');
          return await VCloudExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('filebee.xyz') ||
            individualLink.contains('filepress.')) {
          print('Zeefliz: Processing filepress/filebee link: $individualLink');
          return await FilepressExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('hubcloud')) {
          print('Zeefliz: Processing hubcloud link: $individualLink');
          final res = await HubCloudExtractor.extractLinks(individualLink);
          return res.streams;
        } else if (individualLink.contains('gdflix')) {
          print('Zeefliz: Processing gdflix link: $individualLink');
          return await GdFlixExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('gofile.io')) {
          print('Zeefliz: Processing gofile link: $individualLink');
          final gofileId = individualLink.split('/d/').length > 1
              ? individualLink.split('/d/')[1]
              : null;
          if (gofileId != null) {
            final result = await GofileExtractor.extractLink(gofileId);
            if (result.success && result.link.isNotEmpty) {
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
        }
        return <Stream>[];
      });

      final results = await Future.wait(futures);
      final allStreams = results.expand<Stream>((x) => x).toList();
      print('Zeefliz: Total streams extracted from page: ${allStreams.length}');
      return allStreams;
    }

    print('Zeefliz: Warning - No links found in page');
    return [];
  } catch (e) {
    print('Zeefliz getStream error: $e');
    return [];
  }
}
