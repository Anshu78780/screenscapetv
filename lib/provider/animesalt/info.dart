import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';

class AnimeSaltEpisode {
  final String id;
  final String title;
  final String link;
  final int season;
  final int number;
  final String imageUrl;

  AnimeSaltEpisode({
    required this.id,
    required this.title,
    required this.link,
    required this.season,
    required this.number,
    required this.imageUrl,
  });

  factory AnimeSaltEpisode.fromJson(Map<String, dynamic> json) {
    return AnimeSaltEpisode(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      season: json['season'] ?? 0,
      number: json['number'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class AnimeSaltSeason {
  final int seasonNumber;
  final List<AnimeSaltEpisode> episodes;

  AnimeSaltSeason({
    required this.seasonNumber,
    required this.episodes,
  });

  factory AnimeSaltSeason.fromJson(Map<String, dynamic> json) {
    return AnimeSaltSeason(
      seasonNumber: json['seasonNumber'] ?? 0,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => AnimeSaltEpisode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AnimeSaltAnimeData {
  final String postId;
  final String title;
  final String image;
  final String description;
  final String type;
  final String? releaseDate;
  final List<String>? genres;
  final List<String>? languages;
  final String? duration;
  final int? totalSeasons;
  final int? totalEpisodes;
  final List<AnimeSaltSeason>? seasons;

  AnimeSaltAnimeData({
    required this.postId,
    required this.title,
    required this.image,
    required this.description,
    required this.type,
    this.releaseDate,
    this.genres,
    this.languages,
    this.duration,
    this.totalSeasons,
    this.totalEpisodes,
    this.seasons,
  });

  factory AnimeSaltAnimeData.fromJson(Map<String, dynamic> json) {
    return AnimeSaltAnimeData(
      postId: json['postId'] ?? '',
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'unknown',
      releaseDate: json['releaseDate'],
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      languages: (json['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      duration: json['duration'],
      totalSeasons: json['totalSeasons'],
      totalEpisodes: json['totalEpisodes'],
      seasons: (json['seasons'] as List<dynamic>?)
          ?.map((e) => AnimeSaltSeason.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnimeSaltApiResponse {
  final bool success;
  final AnimeSaltAnimeData data;

  AnimeSaltApiResponse({
    required this.success,
    required this.data,
  });

  factory AnimeSaltApiResponse.fromJson(Map<String, dynamic> json) {
    return AnimeSaltApiResponse(
      success: json['success'] ?? false,
      data: AnimeSaltAnimeData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

Future<MovieInfo> animesaltGetInfo(String url) async {
  print('animesaltGetInfo called with url: $url');
  try {
    final apiUrl = 'https://scarperapi.onrender.com/api/animesalt/details?url=${Uri.encodeComponent(url)}';
    print('Requesting API: $apiUrl');

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'x-api-key': 'sk_PEOMP8TQLYDXmBmQAqWLyJA2cp9nRyss',
        'Content-Type': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch anime info: ${response.statusCode} ${response.reasonPhrase}');
    }

    final Map<String, dynamic> jsonData = json.decode(response.body);
    final apiData = AnimeSaltApiResponse.fromJson(jsonData);

    if (!apiData.success) {
      throw Exception('API request was not successful');
    }

    final data = apiData.data;

    // Check if it's a movie (no seasons data or type is unknown/movie)
    final isMovie = data.seasons == null || data.seasons!.isEmpty || data.type == 'unknown';

    // Create download links based on type
    final List<DownloadLink> downloadLinks = [];

    if (isMovie) {
      // For movies, create a single download link
      downloadLinks.add(DownloadLink(
        quality: 'Movie',
        size: '',
        url: url,
      ));
    } else {
      // For series, organize by seasons
      for (var season in data.seasons!) {
        for (var episode in season.episodes) {
          downloadLinks.add(DownloadLink(
            quality: 'Season ${season.seasonNumber}',
            size: '',
            url: 'https://animesalt.cc${episode.link}',
            season: 'Season ${season.seasonNumber}',
            episodeInfo: 'Episode ${episode.number}: ${episode.title}',
          ));
        }
      }
    }

    return MovieInfo(
      title: data.title,
      imageUrl: data.image,
      imdbRating: data.releaseDate ?? 'N/A',
      genre: (data.genres ?? ['Anime']).join(', '),
      director: '',
      writer: '',
      stars: (data.languages ?? []).join(', '),
      language: (data.languages ?? ['Japanese']).join(', '),
      quality: 'HD',
      format: data.type == 'unknown' ? 'Movie' : 'Series',
      storyline: data.description.isEmpty ? 'No description available' : data.description,
      downloadLinks: downloadLinks,
    );
  } catch (error) {
    print('AnimeSalt getInfo error: $error');
    rethrow;
  }
}
