import '../../models/movie_info.dart';

/// Get episode links from download links
/// In khdhub, episodes are already extracted as download links in info.dart
Future<List<Episode>> khdHubGetEpisodeLinks(
  String episodesLink,
  List<DownloadLink>? downloadLinks,
) async {
  try {
    print('khdHubGetEpisodeLinks called with: $episodesLink');
    
    // If download links are provided, convert them to episodes
    if (downloadLinks != null && downloadLinks.isNotEmpty) {
      print('Converting ${downloadLinks.length} download links to episodes');
      
      // Group by season for series, or return as single list for movies
      final Map<String, List<EpisodeLink>> seasonEpisodes = {};
      
      for (var link in downloadLinks) {
        final season = link.season ?? 'Episodes';
        
        if (!seasonEpisodes.containsKey(season)) {
          seasonEpisodes[season] = [];
        }
        
        seasonEpisodes[season]!.add(EpisodeLink(
          server: 'HubCloud',
          url: link.url,
          size: link.size,
        ));
      }
      
      // Convert to Episode list
      final episodes = <Episode>[];
      seasonEpisodes.forEach((seasonTitle, links) {
        for (var i = 0; i < links.length; i++) {
          final link = links[i];
          final downloadLink = downloadLinks.firstWhere(
            (dl) => dl.url == link.url,
            orElse: () => downloadLinks[0],
          );
          
          episodes.add(Episode(
            title: downloadLink.episodeInfo ?? downloadLink.quality,
            link: link.url,
            links: [link],
          ));
        }
      });
      
      print('Returning ${episodes.length} episodes');
      return episodes;
    }
    
    print('No download links provided');
    return [];
  } catch (error) {
    print('khdHubGetEpisodeLinks error: $error');
    return [];
  }
}
