import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';
import 'geteps.dart';

class MoviesmodInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final titleFromUrl = url.split('/').last.replaceAll('-', ' ');
    
    try {
      print('Getting info for: $url');
      final response = await http.get(Uri.parse(url), headers: MoviesmodHeaders.headers);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract metadata
      // TS: $('.imdbwp__title').text()
      final title = document.querySelector('.imdbwp__title')?.text.trim() ?? titleFromUrl;
      final synopsis = document.querySelector('.imdbwp__teaser')?.text.trim() ?? title;
      final image = document.querySelector('.imdbwp__thumb img')?.attributes['src'] ?? '';
      
      final imdbLink = document.querySelector('.imdbwp__link')?.attributes['href'];
      final imdbId = (imdbLink != null && imdbLink.split('/').length > 4) 
          ? imdbLink.split('/')[4] 
          : 'N/A';
          
      // TS: $('.thecontent').text().toLocaleLowerCase().includes('season') ? 'series' : 'movie'
      final contentText = document.querySelector('.thecontent')?.text.toLowerCase() ?? '';
      final type = contentText.contains('season') ? 'series' : 'movie';
      
      final downloadLinks = <DownloadLink>[];
      
      /*
        $('h3,h4').map...
          seriesTitle = text
          episodesLink = .next('p').find('.maxbutton-episode-links,.maxbutton-g-drive,.maxbutton-af-download').attr('href')
          movieLink = .next('p').find('.maxbutton-download-links').attr('href')
      */
      
      final headers = document.querySelectorAll('h3, h4');
      
      for (var element in headers) {
        final seriesTitle = element.text.trim();
        // find next sibling 'p'
        // HTML parser in Dart doesn't have jquery .next(), we rely on parent structure or index
        // Typically h3/h4 are siblings in .thecontent
        
        final parent = element.parent;
        if (parent == null) continue;
        
        // Find index of current header
        final index = parent.children.indexOf(element);
        if (index == -1 || index + 1 >= parent.children.length) continue;
        
        final nextElement = parent.children[index + 1];
        if (nextElement.localName != 'p') continue; // Should be p
        
        // Check for links in this p
        final movieLinkElem = nextElement.querySelector('.maxbutton-download-links');
        final episodeLinkElem = nextElement.querySelector('.maxbutton-episode-links, .maxbutton-g-drive, .maxbutton-af-download');
        
        final movieLink = movieLinkElem?.attributes['href'];
        final episodesLink = episodeLinkElem?.attributes['href'];
        
        final qualityMatch = RegExp(r'\d+p\b').firstMatch(seriesTitle);
        final quality = qualityMatch?.group(0) ?? 'HD';
        final cleanTitle = seriesTitle.replaceAll('Download', '').trim();

        if (movieLink != null) {
          downloadLinks.add(DownloadLink(
            quality: quality,
            size: 'Movie',
            url: movieLink,
            episodeInfo: cleanTitle.isEmpty ? 'Movie' : cleanTitle,
          ));
        }
        
        if (episodesLink != null && episodesLink != 'javascript:void(0);') {
           // We found a link to episodes/season page.
           // We must fetch it to get actual episodes
           try {
             final episodeList = await MoviesmodGetEpisodes.getEpisodeLinks(episodesLink);
             for (var ep in episodeList) {
               downloadLinks.add(DownloadLink(
                 quality: quality, 
                 size: 'Episode',
                 url: ep['link']!,
                 episodeInfo: '${cleanTitle} - ${ep['title']}',
               ));
             }
           } catch (e) {
             print('Error fetching sub-episodes for $seriesTitle: $e');
           }
        }
      }
      
      // Fallback: Check for any maxbuttons if headers loop failed or structure diff
      if (downloadLinks.isEmpty) {
         document.querySelectorAll('a.maxbutton').forEach((el) {
           final link = el.attributes['href'];
           final text = el.text.trim();
           if (link != null && link.startsWith('http')) {
             downloadLinks.add(DownloadLink(
               quality: 'HD',
               size: 'Unknown',
               url: link,
               episodeInfo: text.isNotEmpty ? text : 'Download',
             ));
           }
         });
      }

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: imdbId, // Using ID as rating placeholder or N/A
        genre: type == 'series' ? 'Series' : 'Movie',
        director: 'N/A',
        writer: 'N/A',
        stars: 'N/A',
        language: 'N/A',
        quality: downloadLinks.isNotEmpty ? downloadLinks.first.quality : 'HD',
        format: 'MKV',
        storyline: synopsis,
        downloadLinks: downloadLinks,
      );

    } catch (e) {
      print('Error parsing Moviesmod info: $e');
      return MovieInfo(
        title: titleFromUrl, 
        imageUrl: '',
        imdbRating: '',
        genre: '',
        director: '',
        writer: '',
        stars: '',
        language: '',
        quality: '',
        format: '',
        storyline: titleFromUrl,
        downloadLinks: [],
      );
    }
  }
}
