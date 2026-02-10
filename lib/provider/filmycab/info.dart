import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class FilmyCabInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final titleFromUrl = url.split('/').last.replaceAll('-', ' ');

    try {
      print('Getting FilmyCab info for: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: FilmyCabHeaders.headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract title from page title or meta tags
      final title =
          document.querySelector('title')?.text.trim() ?? titleFromUrl;

      // Extract poster from cover div or thumbb div
      String image = '';
      final coverImage = document
          .querySelector('.pmain .cover img')
          ?.attributes['src'];
      final thumbImage = document
          .querySelector('.pmain .thumbb img')
          ?.attributes['src'];
      final ogImage = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      image = coverImage ?? thumbImage ?? ogImage ?? '';

      // Extract synopsis from meta description
      final storyline =
          document
              .querySelector('meta[property="og:description"]')
              ?.attributes['content'] ??
          'No description available';

      // Extract IMDB rating
      final imdbRating =
          document.querySelector('.imdb-rating')?.text.trim() ?? 'N/A';

      String genre = 'N/A';
      String language = 'N/A';
      String director = 'N/A';
      String writer = 'N/A';
      String stars = 'N/A';
      String quality = 'N/A';
      String format = 'N/A';

      // Extract download links by first getting the redirect page
      final downloadLinks = <DownloadLink>[];
      final downloadButtons = document.querySelectorAll('.dlbtn a');

      if (downloadButtons.isNotEmpty) {
        // Get the first download button URL (redirect page)
        final redirectUrl = downloadButtons.first.attributes['href'];

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          try {
            print('FilmyCab fetching redirect page: $redirectUrl');
            final redirectRes = await http.get(
              Uri.parse(redirectUrl),
              headers: FilmyCabHeaders.headers,
            );

            if (redirectRes.statusCode == 200) {
              final redirectDoc = html_parser.parse(redirectRes.body);
              final pageText = redirectDoc.body?.text ?? '';

              // Check if this is a web series with episodes
              final hasEpisodes = RegExp(
                r'\*+Episode\s+\d+|\*+Episode\s+\d+-\d+',
                caseSensitive: false,
              ).hasMatch(pageText);

              if (hasEpisodes) {
                print('FilmyCab: Detected web series with episodes');
                // Parse episodes with their download links
                final pageHtml = redirectDoc.body?.innerHtml ?? '';
                final episodeSections = pageHtml.split(
                  RegExp(r'\*+Episode\s+', caseSensitive: false),
                );

                for (var i = 1; i < episodeSections.length; i++) {
                  final section = episodeSections[i];
                  final episodeMatch = RegExp(
                    r'^(\d+(?:-\d+)?)',
                  ).firstMatch(section);

                  if (episodeMatch != null) {
                    final episodeInfo = episodeMatch.group(1);
                    final sectionDoc = html_parser.parseFragment(section);

                    // Parse download links in this episode section
                    final episodeLinks = sectionDoc.querySelectorAll(
                      '.dlink.dl a',
                    );
                    for (var link in episodeLinks) {
                      final linkUrl = link.attributes['href'];
                      final qualityText =
                          link.querySelector('.dll')?.text.trim() ?? '';

                      if (linkUrl != null && linkUrl.isNotEmpty) {
                        final qualityMatch = RegExp(
                          r'(\d+p(?:\s+(?:HEVC|HQ))?)',
                          caseSensitive: false,
                        ).firstMatch(qualityText);
                        final qualityLabel = qualityMatch?.group(1) ?? 'HD';

                        downloadLinks.add(
                          DownloadLink(
                            quality: 'Episode $episodeInfo - $qualityLabel',
                            size: 'N/A',
                            url: linkUrl,
                            episodeInfo: 'Episode $episodeInfo',
                          ),
                        );
                      }
                    }
                  }
                }
              } else {
                // Parse quality-based download links for movies
                final qualityLinks = redirectDoc.querySelectorAll(
                  '.dlink.dl a',
                );
                for (var link in qualityLinks) {
                  final linkUrl = link.attributes['href'];
                  final qualityText =
                      link.querySelector('.dll')?.text.trim() ?? '';

                  if (linkUrl != null &&
                      linkUrl.isNotEmpty &&
                      qualityText.isNotEmpty) {
                    // Extract quality from text (e.g., "Download Now 480p" -> "480p")
                    final qualityMatch = RegExp(
                      r'(\d+p(?:\s+(?:HEVC|HQ))?)',
                      caseSensitive: false,
                    ).firstMatch(qualityText);
                    final qualityLabel = qualityMatch?.group(1) ?? qualityText;

                    downloadLinks.add(
                      DownloadLink(
                        quality: qualityLabel,
                        size: 'N/A',
                        url: linkUrl,
                      ),
                    );
                  }
                }
              }
            }
          } catch (redirectError) {
            print('FilmyCab redirect page error: $redirectError');
            // Fallback to original redirect link if parsing fails
            downloadLinks.add(
              DownloadLink(quality: 'Download', size: 'N/A', url: redirectUrl),
            );
          }
        }
      }

      // If no download links found, use the original link as fallback
      if (downloadLinks.isEmpty) {
        downloadLinks.add(
          DownloadLink(quality: 'Download', size: 'N/A', url: url),
        );
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
      print('FilmyCab fetchMovieInfo error: $e');
      throw Exception('Error fetching movie info: $e');
    }
  }
}
