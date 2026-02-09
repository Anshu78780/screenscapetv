import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'headers.dart';
import 'geteps.dart';
import '../../models/movie_info.dart' as app_models;

class ZinkMoviesInfo {
  final String title;
  final String image;
  final String synopsis;
  final String imdbId;
  final String type;
  final List<String> cast;
  final List<String> tags;
  final String rating;
  final List<ZinkMoviesLinkGroup> linkList;

  ZinkMoviesInfo({
    required this.title,
    required this.image,
    required this.synopsis,
    required this.imdbId,
    required this.type,
    required this.cast,
    required this.tags,
    required this.rating,
    required this.linkList,
  });
}

class ZinkMoviesLinkGroup {
  final String title;
  final String? episodesLink;
  final List<ZinkMoviesDirectLink>? directLinks;

  ZinkMoviesLinkGroup({
    required this.title,
    this.episodesLink,
    this.directLinks,
  });
}

class ZinkMoviesDirectLink {
  final String title;
  final String link;
  final String type;

  ZinkMoviesDirectLink({
    required this.title,
    required this.link,
    required this.type,
  });
}

Future<ZinkMoviesInfo> zinkmoviesGetInfo(String link) async {
  try {
    print('ZinkMovies getInfo: $link');

    final response = await http.get(
      Uri.parse(link),
      headers: zinkmoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('ZinkMovies getInfo failed with status: ${response.statusCode}');
      return _errorInfo();
    }

    final document = parser.parse(response.body);

    // Extract title
    final title = document.querySelector('h1.entry-title')?.text.trim() ??
        document.querySelector('.data h1')?.text.trim() ??
        document.querySelector('h1')?.text.trim() ??
        'Unknown';

    // Extract image
    final posterImg = document.querySelector('.poster img') ??
        document.querySelector('.wp-post-image');
    String image = posterImg?.attributes['data-src'] ??
        posterImg?.attributes['data-lazy-src'] ??
        posterImg?.attributes['data-original'] ??
        posterImg?.attributes['src'] ??
        '';

    if (image.startsWith('data:image/svg+xml')) {
      image = posterImg?.attributes['data-src'] ??
          posterImg?.attributes['data-lazy-src'] ??
          posterImg?.attributes['data-original'] ??
          '';
    }

    // Extract synopsis
    final synopsis = document.querySelector('.wp-content p')?.text.trim() ??
        document.querySelector('.summary .content')?.text.trim() ??
        document.querySelector('.entry-content p')?.text.trim() ??
        'No synopsis available';

    // Extract IMDB ID
    String imdbId = '';
    final imdbLink = document.querySelector('a[href*="imdb.com"]');
    if (imdbLink != null) {
      final imdbHref = imdbLink.attributes['href'] ?? '';
      final imdbMatch = RegExp(r'title/(tt\d+)').firstMatch(imdbHref);
      if (imdbMatch != null) {
        imdbId = imdbMatch.group(1) ?? '';
      }
    }

    // Extract cast
    final cast = <String>[];
    final castElements = document.querySelectorAll('.cast .person');
    for (var element in castElements) {
      final actor = element.querySelector('.name')?.text.trim() ?? '';
      if (actor.isNotEmpty) cast.add(actor);
    }

    // Extract genres/tags
    final tags = <String>[];
    final genreElements = document.querySelectorAll('.meta .genre a');
    for (var element in genreElements) {
      final genre = element.text.trim();
      if (genre.isNotEmpty) tags.add(genre);
    }

    // Extract rating
    final rating = document.querySelector('.rating')?.text.trim() ??
        document.querySelector('.imdb')?.text.trim() ??
        document.querySelector('.vote_average')?.text.trim() ??
        '';

    // Determine content type
    final type = link.contains('/movies/') ? 'movie' : 'series';

    // Extract download/stream links
    final linkList = <ZinkMoviesLinkGroup>[];

    // Check for season-based structure with quality grouping
    final seasonGroups = <String, List<Map<String, String>>>{};
    String? currentSeason;
    
    // Parse HTML to find season headers and their quality variants
    final wpContent = document.querySelector('#info .wp-content');
    if (wpContent != null) {
      final children = wpContent.children;
      
      for (var child in children) {
        // Check if this is a season header
        if (child.classes.contains('lgtagmessage')) {
          final seasonText = child.text.trim();
          // Extract season number/name (e.g., "Season 04: Hindi" -> "Season 04")
          final seasonMatch = RegExp(r'Season\s+(\d+)', caseSensitive: false)
              .firstMatch(seasonText);
          if (seasonMatch != null) {
            currentSeason = 'Season ${seasonMatch.group(1)}';
            seasonGroups[currentSeason] = [];
            print('Found season header: $currentSeason');
          }
        }
        // Check if this is a quality link for the current season
        else if (child.classes.contains('movie-button-container') && 
                 currentSeason != null) {
          final button = child.querySelector('a.movie-simple-button');
          final qualityLink = button?.attributes['href'] ?? '';
          final fullText = button?.querySelector('span')?.text.trim() ?? '';
          
          if (qualityLink.isNotEmpty && fullText.isNotEmpty) {
            // Extract quality from full text (e.g., "Season 04-480P AMZN WEB-DL H.264" -> "480P AMZN WEB-DL H.264")
            String qualityText = fullText;
            final qualityMatch = RegExp(r'Season\s+\d+-(.+)', caseSensitive: false)
                .firstMatch(fullText);
            if (qualityMatch != null) {
              qualityText = qualityMatch.group(1)?.trim() ?? fullText;
            }
            
            seasonGroups[currentSeason]!.add({
              'quality': qualityText,
              'link': qualityLink,
            });
            print('Added quality to $currentSeason: $qualityText');
          }
        }
      }
    }

    // Create link groups from season groups
    if (seasonGroups.isNotEmpty) {
      print('Found ${seasonGroups.length} seasons with quality variants');

      for (var entry in seasonGroups.entries) {
        final seasonName = entry.key;
        final qualityVariants = entry.value;
        
        if (qualityVariants.isNotEmpty) {
          // Create direct links for each quality variant
          final directLinks = qualityVariants.map((variant) {
            return ZinkMoviesDirectLink(
              title: variant['quality']!,
              link: variant['link']!,
              type: 'season',
            );
          }).toList();
          
          linkList.add(ZinkMoviesLinkGroup(
            title: seasonName,
            directLinks: directLinks,
          ));
        }
      }
    } else {
      // Check for individual episodes
      final episodeLinks = <Map<String, String>>[];
      final maxButtons = document.querySelectorAll('a.maxbutton-download-now');
      for (var button in maxButtons) {
        final episodeLink = button.attributes['href'] ?? '';
        final episodeText = button.querySelector('.mb-text')?.text.trim() ?? '';

        if (episodeLink.isNotEmpty &&
            episodeText.isNotEmpty &&
            episodeText.toUpperCase().contains('EPISODE')) {
          episodeLinks.add({
            'title': episodeText,
            'link': episodeLink,
            'type': 'series'
          });
        }
      }

      // Check for jiostar.work links and fetch episodes from them
      final jiostarLinks = <String>[];
      final jiostarElements = document.querySelectorAll('a[href*="jiostar.work"]');
      for (var element in jiostarElements) {
        final jiostarLink = element.attributes['href'] ?? '';
        if (jiostarLink.isNotEmpty) {
          jiostarLinks.add(jiostarLink);
        }
      }

      // Fetch episodes from jiostar links
      for (var jiostarLink in jiostarLinks) {
        try {
          print('Fetching episodes from jiostar.work: $jiostarLink');
          final jiostarEpisodes = await zinkmoviesGetEpisodeLinks(jiostarLink);
          for (var episode in jiostarEpisodes) {
            episodeLinks.add({
              'title': episode.title,
              'link': episode.link,
              'type': 'series'
            });
          }
        } catch (error) {
          print('Error fetching from jiostar.work: $error');
        }
      }

      // If episodes found, create episodes structure
      if (episodeLinks.isNotEmpty) {
        print('Found ${episodeLinks.length} episodes');
        linkList.add(ZinkMoviesLinkGroup(
          title: 'Episodes',
          directLinks: episodeLinks
              .map((ep) => ZinkMoviesDirectLink(
                    title: ep['title']!,
                    link: ep['link']!,
                    type: ep['type']!,
                  ))
              .toList(),
        ));
      } else {
        // Original movie download logic
        final infoButtons = document
            .querySelectorAll('#info .movie-button-container a.movie-simple-button');
        for (var button in infoButtons) {
          final downloadLink = button.attributes['href'] ?? '';
          final qualityText = button.querySelector('span')?.text.trim() ?? '';

          if (downloadLink.isNotEmpty && qualityText.isNotEmpty) {
            linkList.add(ZinkMoviesLinkGroup(
              title: qualityText,
              directLinks: [
                ZinkMoviesDirectLink(
                  title: 'Play',
                  link: downloadLink,
                  type: 'movie',
                ),
              ],
            ));
          }
        }

        // Check for table structure with download links
        if (linkList.isEmpty) {
          final tableLinks = document.querySelectorAll('td a');
          var index = 0;
          for (var element in tableLinks) {
            final linkText = element.text.trim();
            if (linkText.toUpperCase().contains('DOWNLOAD')) {
              final downloadLink = element.attributes['href'] ?? '';
              if (downloadLink.isNotEmpty) {
                final qualityText = element.parent
                        ?.previousElementSibling
                        ?.text
                        .trim() ??
                    'Download ${index + 1}';

                linkList.add(ZinkMoviesLinkGroup(
                  title: qualityText,
                  directLinks: [
                    ZinkMoviesDirectLink(
                      title: 'Play',
                      link: downloadLink,
                      type: 'movie',
                    ),
                  ],
                ));
                index++;
              }
            }
          }
        }

        // Fallback: look for general download links
        if (linkList.isEmpty) {
          final generalLinks = document.querySelectorAll(
              '.download-links a, .entry-content a[href*="download"], .wp-content a[href*="videosaver"], a[href*="/links/"]');
          for (var element in generalLinks) {
            final downloadLink = element.attributes['href'] ?? '';
            final qualityText = element.text.trim();

            if (downloadLink.isNotEmpty && qualityText.isNotEmpty) {
              final alreadyExists = linkList
                  .any((link) => link.episodesLink == downloadLink);
              if (!alreadyExists) {
                linkList.add(ZinkMoviesLinkGroup(
                  title: qualityText,
                  directLinks: [
                    ZinkMoviesDirectLink(
                      title: 'Play',
                      link: downloadLink,
                      type: 'movie',
                    ),
                  ],
                ));
              }
            }
          }
        }
      }
    }

    // Fallback: Check for iframe with embedded player
    if (linkList.isEmpty) {
      print('No download links found, checking for iframe player...');

      final iframe = document.querySelector('iframe[data-lazy-src*="/play/"]') ??
          document.querySelector('iframe[src*="/play/"]') ??
          document.querySelector('iframe');

      String? iframeSrc = iframe?.attributes['data-lazy-src'] ??
          iframe?.attributes['src'];

      if (iframeSrc != null &&
          iframeSrc.isNotEmpty &&
          iframeSrc != 'about:blank') {
        print('Found iframe with player: $iframeSrc');

        linkList.add(ZinkMoviesLinkGroup(
          title: 'Watch Online',
          directLinks: [
            ZinkMoviesDirectLink(
              title: 'Play',
              link: iframeSrc,
              type: 'movie',
            ),
          ],
        ));
      } else {
        print('No valid iframe player found');
      }
    }

    final info = ZinkMoviesInfo(
      title: title,
      image: image,
      synopsis: synopsis,
      imdbId: imdbId,
      type: type,
      cast: cast,
      tags: tags,
      rating: rating,
      linkList: linkList,
    );

    print('ZinkMovies info extracted: ${info.title}');
    return info;
  } catch (error) {
    print('ZinkMovies getInfo error: $error');
    return _errorInfo();
  }
}

ZinkMoviesInfo _errorInfo() {
  return ZinkMoviesInfo(
    title: 'Error loading content',
    image: '',
    synopsis: 'Failed to load content information',
    imdbId: '',
    type: 'movie',
    cast: [],
    tags: [],
    rating: '',
    linkList: [],
  );
}

/// Wrapper function that converts ZinkMoviesInfo to MovieInfo for the app
Future<app_models.MovieInfo> fetchMovieInfo(String link) async {
  try {
    final zinkInfo = await zinkmoviesGetInfo(link);
    
    // Convert to MovieInfo
    final downloadLinks = <app_models.DownloadLink>[];
    
    for (var linkGroup in zinkInfo.linkList) {
      if (linkGroup.episodesLink != null) {
        // This is a season link, need to fetch episodes
        try {
          final episodes = await zinkmoviesGetEpisodeLinks(linkGroup.episodesLink!);
          for (var episode in episodes) {
            downloadLinks.add(app_models.DownloadLink(
              quality: linkGroup.title,
              size: 'Episode',
              url: episode.link,
              episodeInfo: episode.title,
            ));
          }
        } catch (e) {
          print('Error fetching episodes for ${linkGroup.title}: $e');
        }
      } else if (linkGroup.directLinks != null) {
        // Check if these are season quality variants or direct episode links
        for (var directLink in linkGroup.directLinks!) {
          if (directLink.type == 'season') {
            // This is a quality variant for a season, fetch episodes for this quality
            try {
              final episodes = await zinkmoviesGetEpisodeLinks(directLink.link);
              for (var episode in episodes) {
                downloadLinks.add(app_models.DownloadLink(
                  quality: directLink.title,
                  size: 'Episode',
                  url: episode.link,
                  season: linkGroup.title, // Include season info
                  episodeInfo: episode.title,
                ));
              }
            } catch (e) {
              print('Error fetching episodes for ${linkGroup.title} - ${directLink.title}: $e');
            }
          } else {
            // Direct episode or movie links
            downloadLinks.add(app_models.DownloadLink(
              quality: linkGroup.title,
              size: directLink.type == 'series' ? 'Episode' : 'Movie',
              url: directLink.link,
              episodeInfo: directLink.title,
            ));
          }
        }
      }
    }
    
    return app_models.MovieInfo(
      title: zinkInfo.title,
      imageUrl: zinkInfo.image,
      imdbRating: zinkInfo.imdbId.isNotEmpty ? zinkInfo.imdbId : zinkInfo.rating,
      genre: zinkInfo.tags.join(', '),
      director: 'N/A',
      writer: 'N/A',
      stars: zinkInfo.cast.join(', '),
      language: 'N/A',
      quality: 'HD',
      format: 'MKV',
      storyline: zinkInfo.synopsis,
      downloadLinks: downloadLinks,
    );
  } catch (e) {
    print('Error converting ZinkMovies info: $e');
    return app_models.MovieInfo(
      title: 'Error loading content',
      imageUrl: '',
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: 'Failed to load content information',
      downloadLinks: [],
    );
  }
}

