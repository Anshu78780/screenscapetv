class Stream {
  final String server;
  final String link;
  final String type;
  final Map<String, String>? headers;

  Stream({
    required this.server,
    required this.link,
    required this.type,
    this.headers,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      server: json['server'] ?? '',
      link: json['link'] ?? '',
      type: json['type'] ?? '',
      headers: json['headers'] != null 
          ? Map<String, String>.from(json['headers'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'server': server,
      'link': link,
      'type': type,
    };
    if (headers != null) {
      data['headers'] = headers;
    }
    return data;
  }
}