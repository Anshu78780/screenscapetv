class MovieInfo {
  final String title;
  final String imageUrl;
  final String imdbRating;
  final String genre;
  final String director;
  final String writer;
  final String stars;
  final String language;
  final String quality;
  final String format;
  final String storyline;
  final List<DownloadLink> downloadLinks;

  MovieInfo({
    required this.title,
    required this.imageUrl,
    required this.imdbRating,
    required this.genre,
    required this.director,
    required this.writer,
    required this.stars,
    required this.language,
    required this.quality,
    required this.format,
    required this.storyline,
    required this.downloadLinks,
  });
}

class DownloadLink {
  final String quality;
  final String size;
  final String url;
  final String? hubCloudUrl;
  final String? season;
  final String? episodeInfo;

  DownloadLink({
    required this.quality,
    required this.size,
    required this.url,
    this.hubCloudUrl,
    this.season,
    this.episodeInfo,
  });
}

class Episode {
  final String title;
  final String link; // Primary link (for backward compatibility)
  final List<EpisodeLink>? links; // Multiple links with different servers

  Episode({required this.title, required this.link, this.links});
}

class EpisodeLink {
  final String server; // e.g., 'HubCloud', 'GDFlix'
  final String url;
  final String? size; // Optional size info

  EpisodeLink({required this.server, required this.url, this.size});
}
