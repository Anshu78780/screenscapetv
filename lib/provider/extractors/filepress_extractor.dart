import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_types.dart';

class FilePressFileInfo {
  final bool status;
  final int statusCode;
  final String statusText;
  final FilePressData data;

  FilePressFileInfo({
    required this.status,
    required this.statusCode,
    required this.statusText,
    required this.data,
  });

  factory FilePressFileInfo.fromJson(Map<String, dynamic> json) {
    return FilePressFileInfo(
      status: json['status'] ?? false,
      statusCode: json['statusCode'] ?? 0,
      statusText: json['statusText'] ?? '',
      data: FilePressData.fromJson(json['data'] ?? {}),
    );
  }
}

class FilePressData {
  final String id;
  final String name;
  final String size;
  final String category;
  final String createdAt;
  final String mimeType;
  final List<AlternativeSource> alternativeSource;

  FilePressData({
    required this.id,
    required this.name,
    required this.size,
    required this.category,
    required this.createdAt,
    required this.mimeType,
    required this.alternativeSource,
  });

  factory FilePressData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> altSources = json['alternativeSource'] ?? [];
    return FilePressData(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      size: json['size'] ?? '',
      category: json['category'] ?? '',
      createdAt: json['createdAt'] ?? '',
      mimeType: json['mimeType'] ?? '',
      alternativeSource: altSources
          .map((source) => AlternativeSource.fromJson(source))
          .toList(),
    );
  }
}

class AlternativeSource {
  final String name;
  final String url;

  AlternativeSource({
    required this.name,
    required this.url,
  });

  factory AlternativeSource.fromJson(Map<String, dynamic> json) {
    return AlternativeSource(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class FilepressExtractor {
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Extracts download link from FilePress URL
  /// [link] - FilePress URL (e.g., https://new1.filepress.cloud/file/691b4061ab1e76e289e61b76)
  /// Returns Array of stream links
  static Future<List<Stream>> extractStreams(String link) async {
    try {
      print('filepressExtractor: $link');

      // If it's a filebee.xyz link, convert to filepress first using redirect API
      String processedLink = link;
      if (link.contains('filebee.xyz')) {
        print('filebee.xyz link detected, converting to filepress using redirect API');
        try {
          final encodedUrl = Uri.encodeComponent(link);
          final redirectApiUrl = 'https://ssbackend-2r7z.onrender.com/api/redirect?url=$encodedUrl';
          print('Redirect API URL: $redirectApiUrl');
          
          final redirectResponse = await http.get(
            Uri.parse(redirectApiUrl),
            headers: {
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 15));

          if (redirectResponse.statusCode == 200) {
            final redirectData = json.decode(redirectResponse.body);
            final finalUrl = redirectData['finalUrl'];
            
            if (finalUrl != null && finalUrl.isNotEmpty) {
              print('Converted filebee.xyz to: $finalUrl');
              processedLink = finalUrl;
            } else {
              print('No finalUrl in redirect response, using original link');
            }
          } else {
            print('Redirect API request failed: ${redirectResponse.statusCode}');
          }
        } catch (redirectError) {
          print('Error converting filebee to filepress: $redirectError');
          print('Continuing with original link');
        }
      }

      final fileIdMatch = RegExp(r'(?:filepress\.cloud|filepress\.wiki|filebee\.xyz)\/file\/([a-zA-Z0-9]+)')
          .firstMatch(processedLink);
      
      if (fileIdMatch == null) {
        print('Could not extract file ID from FilePress URL');
        return [];
      }

      final fileId = fileIdMatch.group(1)!;
      final baseUrlMatch = RegExp(r'(https:\/\/[^\/]+)').firstMatch(processedLink);
      final baseUrl = baseUrlMatch?.group(1) ?? 'https://new1.filepress.cloud';

      // Step 1: Get file information
      final fileInfoRes = await http.get(
        Uri.parse('$baseUrl/api/file/get/$fileId'),
        headers: {
          ...headers,
          'Referer': processedLink,
        },
      );

      if (fileInfoRes.statusCode != 200) {
        print('Failed to get file info from FilePress: ${fileInfoRes.statusCode}');
        return [];
      }

      final fileInfoData = json.decode(fileInfoRes.body);
      final fileInfo = FilePressFileInfo.fromJson(fileInfoData);

      if (!fileInfo.status) {
        print('Failed to get file info from FilePress - status false');
        return [];
      }

      print('📋 Step 2: Making first download request to get downloadId');

      // Step 2: First request to get downloadId
      final step2PostData = {
        'id': fileId,
        'method': 'cloudR2Downlaod',
        'captchaValue': '',
      };
      
      final step2Headers = {
        ...headers,
        'Content-Type': 'application/json',
        'Referer': processedLink,
        'Cookie': '_gid=GA1.2.44308207.1770031912; _ga=GA1.2.602607768.1768639441; _gat_gtag_UA_100946746_41=1; _ga_KLTKGHZXJG=GS2.1.s1770114360\$o3\$g1\$t1770115116\$j51\$l0\$h0; prefetchAd_9110779=true',
        'Origin': 'https://new5.filepress.cloud',
      };

      final step2Url = '$baseUrl/api/file/downlaod/';

      print('📤 POST URL: $step2Url');
      print('📤 POST Data: ${json.encode(step2PostData)}');

      final step2Res = await http.post(
        Uri.parse(step2Url),
        headers: step2Headers,
        body: json.encode(step2PostData),
      );

      print('📦 Step 2 Response Status: ${step2Res.statusCode}');
      print('📦 Step 2 Response Data: ${step2Res.body}');

      // Extract downloadId from first request
      String? downloadId;
      if (step2Res.statusCode == 200) {
        final step2Data = json.decode(step2Res.body);
        if (step2Data['status'] == true && 
            step2Data['data'] != null && 
            step2Data['data']['downloadId'] != null) {
          downloadId = step2Data['data']['downloadId'];
          print('✅ DownloadId extracted: $downloadId');
        } else {
          print('⚠️ No downloadId in response');
          return [];
        }
      } else {
        print('⚠️ Step 2 request failed: ${step2Res.statusCode}');
        return [];
      }

      print('📋 Step 3: Making second download request with downloadId');

      // Step 3: Second request with downloadId
      final step3PostData = {
        'id': downloadId,
        'method': 'cloudR2Downlaod',
        'captchaValue': null,
      };
      
      final step3Headers = {
        ...headers,
        'Content-Type': 'application/json',
        'Referer': processedLink,
      };

      final step3Url = '$baseUrl/api/file/downlaod2/';

      print('📤 POST URL: $step3Url');
      print('📤 POST Data: ${json.encode(step3PostData)}');

      final downloadRes = await http.post(
        Uri.parse(step3Url),
        headers: step3Headers,
        body: json.encode(step3PostData),
      );

      print('📦 Step 3 Response Status: ${downloadRes.statusCode}');
      print('📦 Step 3 Response Data: ${downloadRes.body}');

      String downloadLink = '';

      if (downloadRes.statusCode == 200) {
        final downloadData = json.decode(downloadRes.body);
        
        // Handle the response - data field contains the direct URL string
        if (downloadData['status'] == true && downloadData['data'] != null) {
          // The data field is a direct URL string
          if (downloadData['data'] is String) {
            downloadLink = downloadData['data'];
            print('✅ Extracted download link from data string: $downloadLink');
          }
          // Fallback: handle if data is an array
          else if (downloadData['data'] is List && (downloadData['data'] as List).isNotEmpty) {
            downloadLink = (downloadData['data'] as List)[0].toString();
            print('✅ Extracted download link from data array: $downloadLink');
          }
          // Fallback: handle if data is an object
          else if (downloadData['data'] is Map) {
            final dataMap = downloadData['data'] as Map<String, dynamic>;
            downloadLink = dataMap['link'] ?? 
                         dataMap['url'] ?? 
                         dataMap['downloadUrl'] ?? '';
            print('✅ Extracted download link from data object: $downloadLink');
          }
        }
        // Legacy fallback for old response format
        else if (downloadData is Map) {
          downloadLink = downloadData['link'] ?? 
                        downloadData['url'] ?? 
                        downloadData['downloadUrl'] ?? '';
          print('✅ Extracted download link from legacy format: $downloadLink');
        }
      } else if (downloadRes.body.isNotEmpty) {
        // Check if response body is a direct string
        if (!downloadRes.body.startsWith('{') && !downloadRes.body.startsWith('[')) {
          downloadLink = downloadRes.body;
          print('✅ Download response is a direct string: $downloadLink');
        }
      }

      // Only use fallback if we truly have nothing
      if (downloadLink.isEmpty) {
        print('⚠️ No download link found in API response, using fallback URL');
        final encodedName = Uri.encodeComponent(fileInfo.data.name);
        downloadLink = 'https://new1.filepress.cloud/download/$encodedName';
        print('❌ Using fallback constructed download link: $downloadLink');
      } else {
        print('🎉 Final download link to be used: $downloadLink');
      }

      final List<Stream> streamLinks = [];

      if (downloadLink.isNotEmpty) {
        streamLinks.add(Stream(
          server: 'FilePress',
          link: downloadLink,
          type: 'mkv',
          headers: {
            'Referer': processedLink,
            'Origin': 'https://new1.filepress.cloud',
          },
        ));
      }

      // Add alternative sources
      if (fileInfo.data.alternativeSource.isNotEmpty) {
        for (final altSource in fileInfo.data.alternativeSource) {
          if (altSource.url.isNotEmpty) {
            streamLinks.add(Stream(
              server: 'FilePress-${altSource.name}',
              link: altSource.url,
              type: 'mkv',
            ));
          }
        }
      }

      return streamLinks;
    } catch (error) {
      print('filepressExtractor error: $error');
      return [];
    }
  }

  /// Helper function to convert OxxFile URL to FilePress URL
  /// [oxxFileUrl] - OxxFile URL
  /// Returns FilePress file URL (e.g., https://new1.filepress.cloud/file/xxxxx)
  static Future<String> getFilePressUrlFromOxxFile(String oxxFileUrl) async {
    try {
      print('getFilePressUrlFromOxxFile - Input URL: $oxxFileUrl');

      final fileIdMatch = RegExp(r'oxxfile\.info\/s\/([a-zA-Z0-9]+)')
          .firstMatch(oxxFileUrl);
      
      if (fileIdMatch == null) {
        print('No fileId match found, returning original URL');
        return oxxFileUrl;
      }

      final fileId = fileIdMatch.group(1)!;
      final baseUrlMatch = RegExp(r'(https:\/\/[^\/]+)').firstMatch(oxxFileUrl);
      final baseUrl = baseUrlMatch?.group(1) ?? 'https://new5.oxxfile.info';
      final apiUrl = '$baseUrl/api/s/$fileId/filepress/';

      print('OxxFile conversion - File ID: $fileId');
      print('OxxFile conversion - Base URL: $baseUrl');
      print('OxxFile conversion - API URL: $apiUrl');

      final encodedApiUrl = Uri.encodeComponent(apiUrl);
      final redirectApiUrl = 'https://net-cookie-kacj.vercel.app/api/redirect?url=$encodedApiUrl';
      print('OxxFile conversion - Redirect API URL: $redirectApiUrl');

      final response = await http.get(
        Uri.parse(redirectApiUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('OxxFile conversion - Response status: ${response.statusCode}');
      print('OxxFile conversion - Response data: ${response.body}');

      if (response.statusCode != 200) {
        print('Redirect API request failed: ${response.statusCode}');
        return oxxFileUrl;
      }

      final responseData = json.decode(response.body);
      final filepressUrl = responseData['data']?['finalUrl'] ?? '';
      print('OxxFile conversion - Extracted FilePress URL: $filepressUrl');

      if (filepressUrl.isNotEmpty && filepressUrl.contains('filepress.cloud/file/')) {
        print('Successfully converted OxxFile to FilePress: $filepressUrl');
        return filepressUrl;
      }

      print('FilePress URL not valid, returning original URL');
      return oxxFileUrl;
    } catch (error) {
      print('Error converting OxxFile to FilePress: $error');
      print('Original OxxFile URL that failed: $oxxFileUrl');
      return oxxFileUrl;
    }
  }
}