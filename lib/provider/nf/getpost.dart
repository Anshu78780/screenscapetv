import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import '../../models/movie.dart';
import 'catalog.dart';
import 'headers.dart';

class NfGetPost {
  /// Unified search function to be used everywhere
  static Future<List<Movie>> _unifiedSearch({
    required String searchQuery,
    required int page,
    bool isForCatalog = false,
  }) async {
    try {
      final catalog = <Movie>[];
      final baseUrl = await NfCatalog.baseUrl;
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();

      print('\n=== ${isForCatalog ? 'Catalog' : 'Search'} Request ===');
      print('Search Query: $searchQuery');

      final searchUrl =
          '$baseUrl/search.php?s=${Uri.encodeComponent(searchQuery)}&t=$timestamp';
      print('Search URL: $searchUrl');

      final headers = await NfHeaders.getSearchHeaders();
      final searchRes = await http
          .get(
            Uri.parse(searchUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(searchRes.body);
      print('Search results: ${data['searchResult']?.length ?? 0}');

      // Process search results
      if (data['searchResult'] != null &&
          data['searchResult'] is List &&
          (data['searchResult'] as List).isNotEmpty) {
        final searchResults = data['searchResult'] as List;

        // Limit results for catalog view to avoid overwhelming
        // For non-catalog (search), limit to 40 posts for performance
        final resultLimit = isForCatalog ? 8 : 40;
        final limitedResults = searchResults.take(resultLimit.clamp(0, searchResults.length));

        for (var result in limitedResults) {
          final id = result['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final imageUrl = 'https://img.nfmirrorcdn.top/poster/h/$id.jpg';
            final postTimestamp =
                (DateTime.now().millisecondsSinceEpoch / 1000).round();

            catalog.add(
              Movie(
                title: '',
                link: '$baseUrl/post.php?id=$id&t=$postTimestamp',
                imageUrl: imageUrl,
                quality: '',
              ),
            );
          }
        }
      }

      return catalog;
    } catch (err) {
      print('${isForCatalog ? 'Catalog' : 'Search'} error: $err');
      return [];
    }
  }

  /// Function to extract Top 10 from home page
  static Future<List<Movie>> _getTop10({
    required String type, // 'movies' or 'series'
  }) async {
    try {
      final baseUrl = await NfCatalog.baseUrl;
      final catalog = <Movie>[];

      final url = '$baseUrl/home';
      print('Fetching Top 10 from: $url');

      final headers = await NfHeaders.getCatalogHeaders('$baseUrl/mobile/movies');
      final res = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      final document = html_parser.parse(res.body);

      // Find the Top 10 section based on type
      final searchText = type == 'movies'
          ? 'Top 10 Movies in Netflix Today'
          : 'Top 10 Series in Netflix Today';

      final lolomoRows = document.querySelectorAll('.lolomoRow');

      for (var rowElement in lolomoRows) {
        final rowTitle =
            rowElement.querySelector('.row-header-title')?.text.trim() ?? '';

        if (rowTitle == searchText) {
          print('Found Top 10 section: $searchText');

          // Extract all slider items with top-10 class
          final sliderItems =
              rowElement.querySelectorAll('.slider-item.open-modal[data-post]');

          for (var element in sliderItems) {
            final id = element.attributes['data-post'] ?? '';
            final imgElement =
                element.querySelector('img.boxart-image-in-padded-container');
            final image = imgElement?.attributes['data-src'] ??
                imgElement?.attributes['src'] ??
                '';

            if (id.isNotEmpty && image.isNotEmpty) {
              final timestamp =
                  (DateTime.now().millisecondsSinceEpoch / 1000).round();
              catalog.add(
                Movie(
                  title: '',
                  link: '$baseUrl/post.php?id=$id&t=$timestamp',
                  imageUrl: image,
                  quality: '',
                ),
              );
            }
          }

          break; // Break the loop once we find the section
        }
      }

      print('Found ${catalog.length} items in Top 10 $type');
      return catalog;
    } catch (err) {
      print('Top 10 error: $err');
      return [];
    }
  }

  /// Fetch posts based on filter and page
  static Future<List<Movie>> fetchMovies(String filter, {int page = 1}) async {
    try {
      final baseUrl = await NfCatalog.baseUrl;
      final catalog = <Movie>[];

      // Netflix Mirror returns all content on page 1, no real pagination support
      if (page > 1) {
        return [];
      }

      // Check if this is a search-based filter for East Asian dramas or other categories
      if (filter.startsWith('search:')) {
        final searchQuery = filter.replaceFirst('search:', '');
        print('Using unified search API for catalog: $searchQuery');

        // Use the unified search function for home screen population
        return await _unifiedSearch(
          searchQuery: searchQuery,
          page: page,
          isForCatalog: true,
        );
      }

      // Check if this is a Top 10 filter
      if (filter.startsWith('top10:')) {
        final type = filter.replaceFirst('top10:', ''); // 'movies' or 'series'
        print('Fetching Top 10 for: $type');

        // Use /home page to extract Top 10 data
        return await _getTop10(type: type);
      }

      // Original logic for non-search filters
      final url = baseUrl + filter;

      print('Home request URL: $url');

      final headers = await NfHeaders.getCatalogHeaders('$baseUrl/mobile/movies');
      final res = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      final document = html_parser.parse(res.body);

      // Skip the main billboard/hero content to avoid duplicate posts in categories
      // Parse slider content items within each row
      final lolomoRows = document.querySelectorAll('.lolomoRow');

      // Limit to 40 posts for performance on low-end devices
      const maxPosts = 40;
      
      for (var rowElement in lolomoRows) {
        if (catalog.length >= maxPosts) break;
        
        final sliderItems =
            rowElement.querySelectorAll('.slider-item.open-modal[data-post]');

        for (var element in sliderItems) {
          if (catalog.length >= maxPosts) break;
          
          final id = element.attributes['data-post'] ?? '';
          final imgElement = element.querySelector('img.boxart-image');
          final image = imgElement?.attributes['data-src'] ??
              imgElement?.attributes['src'] ??
              '';

          if (id.isNotEmpty && image.isNotEmpty) {
            final timestamp =
                (DateTime.now().millisecondsSinceEpoch / 1000).round();
            catalog.add(
              Movie(
                title: '',
                link: '$baseUrl/post.php?id=$id&t=$timestamp',
                imageUrl: image,
                quality: '',
              ),
            );
          }
        }
      }

      // Remove duplicates based on link
      final uniqueCatalog = <String, Movie>{};
      for (var item in catalog) {
        uniqueCatalog[item.link] = item;
      }

      print('Found ${uniqueCatalog.length} items for filter: $filter');
      return uniqueCatalog.values.toList();
    } catch (err) {
      print('NF error: $err');
      return [];
    }
  }

  /// Search movies using the unified search function
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    return await _unifiedSearch(
      searchQuery: query,
      page: page,
      isForCatalog: false,
    );
  }
}
