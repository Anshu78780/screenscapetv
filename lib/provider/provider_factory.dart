import 'provider_service.dart';
import 'drive/drive_provider_service.dart';
import 'hdhub/hdhub_provider_service.dart';
import 'xdmovies/xdmovies_provider_service.dart';
import 'desiremovies/desiremovies_provider_service.dart';
import 'moviesmod/moviesmod_provider_service.dart';
import 'zinkmovies/zinkmovies_provider_service.dart';
import 'animesalt/animesalt_provider_service.dart';
import 'movies4u/movies4u_provider_service.dart';
import 'vega/vega_provider_service.dart';
import 'filmycab/filmycab_provider_service.dart';
import 'zeefliz/zeefliz_provider_service.dart';
import 'animepahe/animepahe_provider_service.dart';
import 'yomovies/yomovies_provider_service.dart';
import 'khdhub/khdhub_provider_service.dart';

// Legacy provider imports for backward compatibility
import 'drive/index.dart';
import 'hdhub/index.dart';
import 'xdmovies/index.dart';
import 'desiremovies/index.dart';
import 'moviesmod/index.dart';
import 'zinkmovies/index.dart';
import 'animesalt/index.dart';
import 'movies4u/index.dart';
import 'vega/index.dart';
import 'filmycab/index.dart';
import 'zeefliz/index.dart';
import 'nf/index.dart';
import 'animepahe/index.dart';
import 'yomovies/index.dart';
import 'khdhub/index.dart';
import '../models/movie.dart';

/// Factory class to create the appropriate provider service
class ProviderFactory {
  static ProviderService getProvider(String providerName) {
    switch (providerName) {
      case 'Hdhub':
        return HdhubProviderService();
      case 'Xdmovies':
        return XdmoviesProviderService();
      case 'Desiremovies':
        return DesireMoviesProviderService();
      case 'Moviesmod':
        return MoviesmodProviderService();
      case 'Zinkmovies':
        return ZinkmoviesProviderService();
      case 'Animesalt':
        return AnimesaltProviderService();
      case 'Movies4u':
        return Movies4uProviderService();
      case 'Vega':
        return VegaProviderService();
      case 'Filmycab':
        return FilmycabProviderService();
      case 'Zeefliz':
        return ZeeflizProviderService();
      case 'NfMirror':
        return NfProviderService();
      case 'Animepahe':
        return AnimePaheProviderService();
      case 'YoMovies':
        return YoMoviesProviderService();
      case 'KhdHub':
        return KhdHubProviderService();
      case 'Drive':
      default:
        return DriveProviderService();
    }
  }

  /// Get categories for a provider
  static List<Map<String, String>> getCategories(String providerName) {
    switch (providerName) {
      case 'Hdhub':
        return HdhubCatalog.categories;
      case 'Xdmovies':
        return XdmoviesCatalog.categories;
      case 'Desiremovies':
        return DesireMoviesCatalog.categories;
      case 'Moviesmod':
        return MoviesmodCatalog.categories;
      case 'Zinkmovies':
        return ZinkMoviesCatalog.categories;
      case 'Animesalt':
        return AnimeSaltCatalog.categories;
      case 'Movies4u':
        return Movies4uCatalog.categories;
      case 'Vega':
        return VegaCatalog.categories;
      case 'Filmycab':
        return FilmyCabCatalog.categories;
      case 'Zeefliz':
        return ZeeflizCatalog.categories;
      case 'NfMirror':
        return NfCatalog.categories;
      case 'Animepahe':
        return AnimePaheCatalog.categories;
      case 'YoMovies':
        return YoMoviesCatalog.categories;
      case 'KhdHub':
        return KhdHubCatalog.categories;
      case 'Drive':
      default:
        return DriveCatalog.categories;
    }
  }

  /// Load movies for a provider and category
  static Future<List<Movie>> loadMovies(
    String providerName,
    Map<String, String> category,
  ) async {
    switch (providerName) {
      case 'Hdhub':
        final categoryUrl = await HdhubCatalog.getCategoryUrl(
          category['path']!,
        );
        return await HdhubGetPost.fetchMovies(categoryUrl);
      case 'Xdmovies':
        final categoryUrl = await XdmoviesCatalog.getCategoryUrl(
          category['path']!,
        );
        return await XdmoviesGetPost.fetchMovies(categoryUrl);
      case 'Desiremovies':
        final categoryUrl = await DesireMoviesCatalog.getCategoryUrl(
          category['path']!,
        );
        return await DesireMoviesGetPost.fetchMovies(categoryUrl);
      case 'Moviesmod':
        final categoryUrl = await MoviesmodCatalog.getCategoryUrl(
          category['path']!,
        );
        return await MoviesmodGetPost.fetchMovies(categoryUrl);
      case 'Zinkmovies':
        return await zinkmoviesGetPosts(category['filter']!, 1);
      case 'Animesalt':
        return await animesaltGetPosts(category['filter']!, 1);
      case 'Movies4u':
        final categoryUrl = await Movies4uCatalog.getCategoryUrl(
          category['path']!,
        );
        return await Movies4uGetPost.fetchMovies(categoryUrl);
      case 'Vega':
        return await vegaGetPosts(category['filter']!, 1, 'Vega');
      case 'Filmycab':
        return await FilmyCabGetPost.fetchMovies(category['path']!);
      case 'Zeefliz':
        return await ZeeflizGetPost.fetchMovies(category['path']!);
      case 'NfMirror':
        return await NfGetPost.fetchMovies(category['path']!);
      case 'Animepahe':
        return await animepaheGetPosts(category['filter']!, 1);
      case 'YoMovies':
        return await yoMoviesGetPosts(category['filter']!, 1);
      case 'KhdHub':
        return await khdHubGetPosts(category['filter']!, 1);
      case 'Drive':
      default:
        final categoryUrl = await DriveCatalog.getCategoryUrl(
          category['path']!,
        );
        return await GetPost.fetchMovies(categoryUrl);
    }
  }

  /// Search movies for a provider
  static Future<List<Movie>> searchMovies(
    String providerName,
    String query,
  ) async {
    switch (providerName) {
      case 'Hdhub':
        return await HdhubGetPost.searchMovies(query);
      case 'Desiremovies':
        return await DesireMoviesGetPost.searchMovies(query);
      case 'Moviesmod':
        return await MoviesmodGetPost.searchMovies(query);
      case 'Zinkmovies':
        return await zinkmoviesGetPostsSearch(query, 1);
      case 'Animesalt':
        return await animesaltGetPostsSearch(query, 1);
      case 'Movies4u':
        return await Movies4uGetPost.searchMovies(query);
      case 'Vega':
        return await vegaGetPostsSearch(query, 1, 'Vega');
      case 'Filmycab':
        return await FilmyCabGetPost.searchMovies(query);
      case 'NfMirror':
        return await NfGetPost.searchMovies(query);
      case 'Zeefliz':
        return await ZeeflizGetPost.searchMovies(query);
      case 'Xdmovies':
        return await XdmoviesGetPost.searchMovies(query);
      case 'Animepahe':
        return await animepaheGetPostsSearch(query, 1);
      case 'YoMovies':
        return await yoMoviesGetPostsSearch(query, 1);
      case 'KhdHub':
        return await khdHubGetPostsSearch(query, 1);
      case 'Drive':
      default:
        return await GetPost.searchMovies(query);
    }
  }
}
