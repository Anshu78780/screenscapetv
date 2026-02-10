import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class ZeeflizInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final titleFromUrl = url.split('/').last.replaceAll('-', ' ');

    try {
      print('Getting Zeefliz info for: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: ZeeflizHeaders.headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract title from h3 tag first (main content title)
      var title = document.querySelector('h3')?.text.trim();
      if (title == null || title.isEmpty) {
        title =
            document
                .querySelector('h1.entry-title, .post-title, .movie-title')
                ?.text
                .trim() ??
            titleFromUrl;
      }

      // Extract image from lazyload data-src attribute
      String image = '';
      final postThumbnail = document.querySelector('.post-thumbnail img');
      if (postThumbnail != null) {
        image =
            postThumbnail.attributes['data-src'] ??
            postThumbnail.attributes['src'] ??
            '';
      }
      if (image.isEmpty) {
        image = document.querySelector('img')?.attributes['src'] ?? '';
      }

      // Extract storyline from specific paragraph structure
      String storyline = '';
      final paragraphs = document.querySelectorAll('p');
      for (var p in paragraphs) {
        final text = p.text;
        if (text.contains('Download') &&
            text.contains('movie') &&
            text.contains('available in')) {
          storyline = text.trim();
          break;
        }
      }

      // If not found, look for series synopsis
      if (storyline.isEmpty) {
        final h3Elements = document.querySelectorAll('h3');
        for (var h3 in h3Elements) {
          final text = h3.text;
          if (text.contains('SYNOPSIS') || text.contains('PLOT')) {
            final nextP = h3.nextElementSibling;
            if (nextP != null && nextP.localName == 'p') {
              storyline = nextP.text.trim();
              break;
            }
          }
        }
      }

      if (storyline.isEmpty) {
        storyline =
            document
                .querySelector('.post-content p, .synopsis, .description')
                ?.text
                .trim() ??
            'No description available';
      }

      String imdbRating = 'N/A';
      String genre = 'N/A';
      String language = 'N/A';
      String director = 'N/A';
      String writer = 'N/A';
      String stars = 'N/A';
      String quality = 'N/A';
      String format = 'N/A';

      // Extract download links
      final downloadLinks = <DownloadLink>[];

      // First try to extract movie quality links (h5 with quality info)
      final h5Elements = document.querySelectorAll('h5');
      for (var h5 in h5Elements) {
        final qualityText = h5.text;
        final nextP = h5.nextElementSibling;

        if (nextP != null && nextP.localName == 'p') {
          // Get the first download link
          final firstLink = nextP.querySelector('a')?.attributes['href'];

          // Accept h5 sections that have quality info (480p, 720p, 1080p, 2160p)
          final qualityMatch = RegExp(
            r'(\d+p)',
            caseSensitive: false,
          ).firstMatch(qualityText);

          if (firstLink != null && qualityMatch != null) {
            final qualityLabel = qualityMatch.group(1)!;

            // Extract file size from text inside brackets []
            final sizeMatch = RegExp(r'\[([^\]]+)\]').firstMatch(qualityText);
            final size = sizeMatch?.group(1) ?? 'N/A';

            downloadLinks.add(
              DownloadLink(
                quality: '$qualityLabel${size != 'N/A' ? ' ($size)' : ''}',
                size: size,
                url: firstLink,
              ),
            );
          }
        }
      }

      // Extract series/season quality links (h3 with quality info and episode links)
      final h3Elements = document.querySelectorAll('h3');
      for (var h3 in h3Elements) {
        final qualityHeader = h3.text;

        // Check if this h3 contains quality info
        final qualityMatch = RegExp(r'(\d+p)').firstMatch(qualityHeader);
        final seasonMatch = RegExp(
          r'Season\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(qualityHeader);
        final volMatch = RegExp(
          r'Vol\.\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(qualityHeader);

        if (qualityMatch != null) {
          final qualityLabel = qualityMatch.group(1)!;
          final nextP = h3.nextElementSibling;

          if (nextP != null && nextP.localName == 'p') {
            // Look for both G-Direct (batch) and V-Cloud (episode) links
            final links = nextP.querySelectorAll('a');
            String gDirectLink = '';
            String vCloudLink = '';
            String genericLink = '';

            for (var link in links) {
              final href = link.attributes['href'] ?? '';
              final button = link.querySelector('button');
              final buttonText = button?.text.toLowerCase() ?? '';
              final buttonStyle = button?.attributes['style'] ?? '';
              final buttonClass = button?.classes.join(' ') ?? '';

              // G-Direct link (green gradient)
              if (buttonText.contains('g-direct') ||
                  buttonText.contains('instant') ||
                  buttonStyle.contains('#0ebac3') ||
                  buttonStyle.contains('#09d261')) {
                gDirectLink = href;
              }
              // V-Cloud/Zee-Cloud link (red-orange gradient)
              else if (buttonText.contains('v-cloud') ||
                  buttonText.contains('zee-cloud') ||
                  buttonText.contains('resumable') ||
                  href.contains('zcloud.lol') ||
                  href.contains('zee-cloud') ||
                  buttonStyle.contains('#ed0b0b')) {
                vCloudLink = href;
              }
              // Generic "Download Now" button (fallback)
              else if (button != null &&
                  (buttonText.contains('download') ||
                      buttonClass.contains('dwd-button')) &&
                  href.isNotEmpty &&
                  genericLink.isEmpty) {
                genericLink = href;
              }
            }

            // Build title with season/volume info
            String titlePrefix = '';
            if (seasonMatch != null) {
              titlePrefix = 'Season ${seasonMatch.group(1)}';
              if (volMatch != null) {
                titlePrefix += ' Vol. ${volMatch.group(1)}';
              }
            }

            // Store BOTH links separated by | for processing both sources
            // If no G-Direct/V-Cloud found, use generic link
            var combinedLink = [
              gDirectLink,
              vCloudLink,
            ].where((l) => l.isNotEmpty).join('|');

            if (combinedLink.isEmpty && genericLink.isNotEmpty) {
              combinedLink = genericLink;
            }

            if (combinedLink.isNotEmpty) {
              downloadLinks.add(
                DownloadLink(
                  quality:
                      '${titlePrefix.isNotEmpty ? '$titlePrefix - ' : ''}$qualityLabel',
                  size: 'N/A',
                  url: combinedLink,
                  season: titlePrefix.isNotEmpty ? titlePrefix : null,
                ),
              );
            }
          }
        }
      }

      // If no quality links found, create fallback dummy links
      if (downloadLinks.isEmpty) {
        for (var qual in ['480p', '720p', '1080p']) {
          downloadLinks.add(
            DownloadLink(quality: qual, size: 'N/A', url: '$url#$qual'),
          );
        }
      }

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: imdbRating,
        genre: genre,
        director: director,
        writer: writer,
        stars: stars,
        language: language,
        quality: quality,
        format: format,
        storyline: storyline,
        downloadLinks: downloadLinks,
      );
    } catch (e) {
      print('Zeefliz fetchMovieInfo error: $e');
      throw Exception('Error fetching movie info: $e');
    }
  }
}
