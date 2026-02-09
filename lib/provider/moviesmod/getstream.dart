import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/gdflix_extractor.dart';
import '../extractors/stream_types.dart';
import '../extractors/gofile_extractor.dart';
import '../extractors/filepress_extractor.dart';
import 'tech_extractor.dart';
import 'headers.dart';

Future<List<Stream>> moviesmodGetStream(String url) async {
  try {
    print('Moviesmod getting streams for: $url');
    final streams = <Stream>[];
    
    // Handle links.modpro.blog or similar intermediate pages
    if (url.contains('links.modpro.blog') || url.contains('/archives/')) {
      print('Detected intermediate link page, fetching tech links...');
      
      try {
        final response = await http.get(Uri.parse(url), headers: MoviesmodHeaders.headers);
        if (response.statusCode == 200) {
          final document = html_parser.parse(response.body);
          
          // Extract tech.unblockedgames.world links from maxbutton elements
          final techLinks = <String>[];
          document.querySelectorAll('a.maxbutton').forEach((element) {
            final link = element.attributes['href'];
            if (link != null && link.contains('tech.unblockedgames.world') && !techLinks.contains(link)) {
              techLinks.add(link);
              print('Found tech link: $link');
            }
          });
          
          // Process each tech link found
          if (techLinks.isNotEmpty) {
            for (var techLink in techLinks) {
              final techStreams = await TechExtractor.extractStreams(techLink);
              streams.addAll(techStreams);
            }
            return streams;
          }
        }
      } catch (e) {
        print('Error fetching intermediate page: $e');
      }
    }
    
    // Handle tech.unblockedgames.world links directly
    if (url.contains('tech.unblockedgames.world')) {
       print('Detected tech.unblockedgames.world link, using TechExtractor');
       final techStreams = await TechExtractor.extractStreams(url);
       return techStreams;
    }
    
    // Handle HubCloud
    if (url.contains('hubcloud') || url.contains('hubdrive')) {
       final result = await HubCloudExtractor.extractLinks(url);
       if (result.success) {
         streams.addAll(result.streams);
       }
    } 
    // Handle GDFlix
    else if (url.contains('gdflix') || url.contains('driveleech') || url.contains('driveseed') || url.contains('drivebit')) {
       final gdStreams = await GdFlixExtractor.extractStreams(url);
       streams.addAll(gdStreams);
    }
    // Handle Gofile
    else if (url.contains('gofile')) {
       // Extract ID from URL e.g. https://gofile.io/d/123456
       final uri = Uri.parse(url);
       String? id;
       if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
           id = uri.pathSegments.last;
       }
       
       if (id != null) {
          final result = await GofileExtractor.extractLink(id);
          if (result.success) {
             streams.add(Stream(server: 'Gofile', link: result.link, type: 'Direct'));
          }
       }
    }
     // Handle FilePress
    else if (url.contains('filepress')) {
       final fpStreams = await FilepressExtractor.extractStreams(url);
       streams.addAll(fpStreams);
    }
    // Handle direct files
    else if (url.endsWith('.mkv') || url.endsWith('.mp4')) {
      streams.add(Stream(server: 'Direct', link: url, type: 'Video'));
    }
    else {
      // Return as generic stream, letting player try to handle or extract
      streams.add(Stream(server: 'Moviesmod', link: url, type: 'Unknown'));
    }

    return streams;
  } catch (e) {
    print('Error getting Moviesmod streams: $e');
    return [];
  }
}
