import 'nf_get_cookie.dart';

class NfHeaders {
  /// Get headers for search requests
  static Future<Map<String, String>> getSearchHeaders() async {
    final cookie = await NfCookieManager.getCookie();
    return {
      'accept': 'application/json',
      'accept-language': 'en-US,en;q=0.9',
      'cache-control': 'no-cache, no-store, must-revalidate',
      'cookie': '${cookie} hd=on; ott=nf;',
      'pragma': 'no-cache',
      'sec-ch-ua':
          '"Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
    };
  }

  /// Get headers for home/catalog page requests
  static Future<Map<String, String>> getCatalogHeaders(String referer) async {
    final cookie = await NfCookieManager.getCookie();
    return {
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'accept-language': 'en-US,en;q=0.9,en-IN;q=0.8',
      'cache-control': 'no-cache, no-store, must-revalidate',
      'pragma': 'no-cache',
      'cookie': '${cookie}ott=nf;',
      'priority': 'u=0, i',
      'sec-ch-ua':
          '"Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-user': '?1',
      'upgrade-insecure-requests': '1',
      'Referer': referer,
    };
  }

  /// Get headers for info/post requests
  static Future<Map<String, String>> getInfoHeaders() async {
    final cookie = await NfCookieManager.getCookie();
    return {
      'cookie': cookie,
    };
  }

  /// Get headers for stream requests
  static Future<Map<String, String>> getStreamHeaders(
    String streamBaseUrl,
  ) async {
    final cookie = await NfCookieManager.getCookie();
    return {
      'cookie': '${cookie}ott=nf; hd=on;',
      'Referer': streamBaseUrl,
      'Origin': streamBaseUrl,
    };
  }
}
