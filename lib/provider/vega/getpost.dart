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
    final url = '$baseUrl';
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

    // New Vega layout: section .content-section -> .movies-grid -> a > .poster-card
    var cards = document.querySelectorAll('#moviesGridMain > a');
    if (cards.isEmpty) {
      cards = document.querySelectorAll('.movies-grid > a');
    }

    if (cards.isNotEmpty) {
      for (final card in cards) {
        final postLink = card.attributes['href']?.trim() ?? '';
        final img = card.querySelector('.poster-image img');
        final titleElement = card.querySelector('.poster-title');
        final qualityElement = card.querySelector('.poster-quality');

        var title = (titleElement?.text.trim().isNotEmpty ?? false)
            ? titleElement!.text.trim()
            : (img?.attributes['alt'] ?? '').trim();
        title = title.replaceAll(RegExp(r'^Download\s+', caseSensitive: false), '').trim();

        var image = img?.attributes['data-lazy-src'] ??
            img?.attributes['data-src'] ??
            img?.attributes['src'] ??
            '';

        if (image.startsWith('//')) {
          image = 'https:$image';
        }

        final quality = qualityElement?.text.trim() ?? '';

        if (title.isNotEmpty && postLink.isNotEmpty) {
          posts.add(
            Movie(
              title: title,
              link: postLink,
              imageUrl: image,
              quality: quality,
            ),
          );
        }
      }
    } else {
      // Legacy fallback layout.
      final listItems = document.querySelectorAll('#archive-container li.entry-list-item');

      for (final element in listItems) {
        final article = element.querySelector('article');
        if (article == null) continue;

        final link = article.querySelector('a.post-thumbnail');
        final img = link?.querySelector('img');
        final titleElement = article.querySelector('.entry-title a');

        if (titleElement == null || link == null) continue;

        var title = titleElement.attributes['title'] ?? titleElement.text;
        title = title.replaceAll(RegExp(r'^Download\s+', caseSensitive: false), '').trim();

        var image = img?.attributes['data-lazy-src'] ??
            img?.attributes['data-src'] ??
            img?.attributes['src'] ??
            '';

        if (image.startsWith('//')) {
          image = 'https:$image';
        }

        final postLink = link.attributes['href'] ?? '';

        if (title.isNotEmpty && postLink.isNotEmpty) {
          posts.add(
            Movie(
              title: title.trim(),
              link: postLink,
              imageUrl: image,
              quality: '',
            ),
          );
        }
      }
    }

    print('vegaGetPosts: Found ${posts.length} posts');
    return posts;
  } catch (error) {
    print('_fetchPosts error: $error');
    return [];
  }
}
