import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../libs/baseurl.dart';
import '../../models/movie.dart';
import 'headers.dart';

Future<List<Movie>> vegaGetPosts(
  String filter,
  int page,
  String providerValue,
) async {
  try {
    final baseUrl = await BaseUrl.getProviderUrl('Vega');
    if (baseUrl == null) {
      print('vegaGetPosts: Failed to get base URL');
      return [];
    }

    print('vegaGetPosts baseUrl: $providerValue, $baseUrl');
    final url = '$baseUrl/$filter/page/$page/';
    print('vegaGetPosts url: $url');

    return await _fetchPosts(baseUrl, url);
  } catch (error) {
    print('vegaGetPosts error: $error');
    return [];
  }
}

Future<List<Movie>> vegaGetPostsSearch(
  String searchQuery,
  int page,
  String providerValue,
) async {
  try {
    final baseUrl = await BaseUrl.getProviderUrl('Vega');
    if (baseUrl == null) {
      print('vegaGetPostsSearch: Failed to get base URL');
      return [];
    }

    print('vegaGetPostsSearch baseUrl: $providerValue, $baseUrl');
    final url = '$baseUrl/page/$page/?s=$searchQuery';
    print('vegaGetPostsSearch url: $url');

    return await _fetchPosts(baseUrl, url);
  } catch (error) {
    print('vegaGetPostsSearch error: $error');
    return [];
  }
}

Future<List<Movie>> _fetchPosts(String baseUrl, String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        ...vegaHeaders,
        'Referer': baseUrl,
      },
    );

    if (response.statusCode != 200) {
      print('vegaGetPosts: HTTP ${response.statusCode}');
      return [];
    }

    final document = html_parser.parse(response.body);
    final posts = <Movie>[];

    final listItems = document.querySelectorAll('#archive-container li.entry-list-item');
    
    for (var element in listItems) {
      final article = element.querySelector('article');
      if (article == null) continue;

      final link = article.querySelector('a.post-thumbnail');
      final img = link?.querySelector('img');
      final titleElement = article.querySelector('.entry-title a');

      if (titleElement == null || link == null) continue;

      var title = titleElement.attributes['title'] ?? titleElement.text;
      title = title.replaceAll('Download', '').trim();

      // Extract year or season from title if present
      final titleMatch = RegExp(r'^(.*?)\s*\((\d{4})\)|^(.*?)\s*\((Season \d+)\)').firstMatch(title);
      if (titleMatch != null) {
        title = titleMatch.group(0) ?? title;
      }

      var image = img?.attributes['data-lazy-src'] ?? 
                 img?.attributes['data-src'] ?? 
                 img?.attributes['src'] ?? 
                 '';

      if (image.startsWith('//')) {
        image = 'https:$image';
      }

      final postLink = link.attributes['href'] ?? '';

      if (title.isNotEmpty && postLink.isNotEmpty) {
        posts.add(Movie(
          title: title.trim(),
          link: postLink,
          imageUrl: image,
          quality: '',
        ));
      }
    }

    print('vegaGetPosts: Found ${posts.length} posts');
    return posts;
  } catch (error) {
    print('_fetchPosts error: $error');
    return [];
  }
}
