class Movie {
  final String title;
  final String imageUrl;
  final String quality;
  final String link;

  Movie({
    required this.title,
    required this.imageUrl,
    required this.quality,
    required this.link,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      quality: json['quality'] ?? '',
      link: json['link'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'quality': quality,
      'link': link,
    };
  }
}
