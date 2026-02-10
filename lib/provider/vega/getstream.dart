import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../extractors/stream_types.dart';
import '../extractors/gdirect_extractor.dart';
import '../extractors/filepress_extractor.dart';
import '../extractors/vcloud_extractor.dart';
import 'headers.dart';

Future<List<Stream>> vegaGetStream(String link, String type) async {
  try {
    print('vegaGetStream: $link, type: $type');

    // Check if link contains combined links (pipe-delimited)
    if (link.contains('|')) {
      print('Processing combined/pipe-delimited links: $link');
      final links = link.split('|').where((l) => l.trim().isNotEmpty).toList();
      print('Split into ${links.length} individual links');

      final futures = links.map((individualLink) async {
        final trimmedLink = individualLink.trim();
        print('Processing individual link: $trimmedLink');

        // Process fastdl.zip links via G-Direct extractor (uses redirect API)
        if (trimmedLink.contains('fastdl.zip')) {
          print('Detected fastdl.zip link, using GDirectExtractor');
          return await GDirectExtractor.extractStreams(trimmedLink);
        } 
        // Process vcloud links via VCloud extractor
        else if (trimmedLink.contains('vcloud.') || trimmedLink.contains('cloud.')) {
          print('Detected vcloud link, using VCloudExtractor');
          return await VCloudExtractor.extractStreams(trimmedLink);
        } 
        // Process filebee.xyz/filepress links via Filepress extractor (converts filebee first)
        else if (trimmedLink.contains('filebee.xyz') || trimmedLink.contains('filepress.')) {
          print('Detected filebee/filepress link, using FilepressExtractor');
          return await FilepressExtractor.extractStreams(trimmedLink);
        }
        
        print('Unknown link type: $trimmedLink');
        return <Stream>[];
      });

      final results = await Future.wait(futures);
      final allStreams = results.expand<Stream>((x) => x).toList();
      print('Total streams extracted from combined links: ${allStreams.length}');
      return allStreams;
    }

    // Handle direct link types (not pipe-delimited)
    if (link.contains('fastdl.zip')) {
      print('Direct G-Direct/fastdl link detected: $link');
      return await GDirectExtractor.extractStreams(link);
    }

    if (link.contains('filebee.xyz') || link.contains('filepress.')) {
      print('Direct Filepress/Filebee link detected: $link');
      return await FilepressExtractor.extractStreams(link);
    }

    if (link.contains('vcloud.') || link.contains('cloud.')) {
      print('Direct V-Cloud link detected: $link');
      return await VCloudExtractor.extractStreams(link);
    }

    // Legacy flow: nexdrive pages that need to be parsed
    print('Processing nexdrive page (legacy flow): $link');

    final response = await http.get(
      Uri.parse(link),
      headers: vegaHeaders,
    );

    if (response.statusCode != 200) {
      print('vegaGetStream: HTTP ${response.statusCode}');
      return [];
    }

    final document = html_parser.parse(response.body);
    final links = <String>[];

    // Extract G-Direct link (fastdl.zip)
    final gDirectLink = document.querySelector('a[href*="fastdl.zip"]')?.attributes['href'];
    if (gDirectLink != null && gDirectLink.isNotEmpty) {
      print('Found G-Direct link in page: $gDirectLink');
      links.add(gDirectLink);
    }

    // Extract V-Cloud link
    final vcloudButton = document.querySelector(
      'a[href*="cloud"] button[style*="background:linear-gradient(135deg,#ed0b0b,#f2d152)"]',
    );
    if (vcloudButton != null) {
      final vcloudLink = vcloudButton.parent?.attributes['href'];
      if (vcloudLink != null && vcloudLink.isNotEmpty) {
        print('Found V-Cloud link in page: $vcloudLink');
        links.add(vcloudLink);
      }
    }

    // Extract Filepress/Filebee link
    final filepressLink = document.querySelector('a[href*="filebee.xyz"], a[href*="filepress."]')?.attributes['href'];
    if (filepressLink != null && filepressLink.isNotEmpty) {
      print('Found Filepress/Filebee link in page: $filepressLink');
      links.add(filepressLink);
    }

    // Process all links in parallel
    if (links.isNotEmpty) {
      print('Found ${links.length} links in nexdrive page, processing in parallel');
      final futures = links.map((individualLink) async {
        if (individualLink.contains('fastdl.zip')) {
          print('Processing fastdl.zip link: $individualLink');
          return await GDirectExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('vcloud.') || individualLink.contains('cloud.')) {
          print('Processing vcloud link: $individualLink');
          return await VCloudExtractor.extractStreams(individualLink);
        } else if (individualLink.contains('filebee.xyz') || individualLink.contains('filepress.')) {
          print('Processing filepress/filebee link: $individualLink');
          return await FilepressExtractor.extractStreams(individualLink);
        }
        return <Stream>[];
      });

      final results = await Future.wait(futures);
      final allStreams = results.expand<Stream>((x) => x).toList();
      print('Total streams extracted from nexdrive page: ${allStreams.length}');
      return allStreams;
    }

    print('Warning: No links found in nexdrive page');
    return [];
  } catch (error) {
    print('vegaGetStream error: $error');
    return [];
  }
}
