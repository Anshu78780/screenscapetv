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
import 'nf/nf_provider_service.dart';

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
      case 'Drive':
      default:
        return DriveProviderService();
    }
  }
}
