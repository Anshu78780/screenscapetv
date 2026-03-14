import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import 'headers.dart';

Future<MovieInfo> vegaGetInfo(String link) async {
  try {
    final url = link;
    print('vegaGetInfo url: $url');
    final baseUrl = Uri.parse(url).origin;

    final response = await http.get(
      Uri.parse(url),
      headers: {...vegaHeaders, 'Referer': baseUrl},
    );

    if (response.statusCode != 200) {
      print('vegaGetInfo: HTTP ${response.statusCode}');
      return _emptyMovieInfo();
    }

    final document = html_parser.parse(response.body);

    // Try multiple selectors to find the content container
    Element? infoContainer =
      document.querySelector('.post-layout .post-content .page-body') ??
      document.querySelector('article.post-content main.page-body') ??
      document.querySelector('main.page-body') ??
        document.querySelector('#primary .entry-content') ??
        document.querySelector('main .entry-content') ??
        document.querySelector('.entry-content') ??
        document.querySelector('.post-inner');

    if (infoContainer == null) {
      print('vegaGetInfo: No info container found');
      return _emptyMovieInfo();
    }

    // Extract IMDB ID
    final heading = infoContainer.querySelector('h3');
    String imdbId = '';

    if (heading != null) {
      final nextP = heading.nextElementSibling;
      if (nextP?.localName == 'p') {
        final imdbLink = nextP?.querySelector('a')?.attributes['href'];
        if (imdbLink != null) {
          final match = RegExp(r'tt\d+').firstMatch(imdbLink);
          imdbId = match?.group(0) ?? '';
        }
      }
    }

    // Fallback: search in text content
    if (imdbId.isEmpty) {
      final textMatch = RegExp(r'tt\d+').firstMatch(infoContainer.text);
      imdbId = textMatch?.group(0) ?? '';
    }

    // Extract title from new layout first, then fallback to old pattern.
    var title =
        document.querySelector('.post-header .post-title')?.text.trim() ?? '';

    if (title.isEmpty) {
      final typeText = heading?.nextElementSibling?.text ?? '';
      final titleMatch = RegExp(r'Name:\s*(.+)').firstMatch(typeText);
      title = titleMatch?.group(1)?.trim() ?? '';
    }

    if (title.isEmpty) {
      title = document.querySelector('h1')?.text.trim() ?? '';
    }

    title = title.replaceAll(RegExp(r'^Download\s+', caseSensitive: false), '').trim();

    // Extract synopsis
    String synopsis = '';
    final synopsisHeader = infoContainer.querySelectorAll('h2, h3, h4').firstWhere(
      (h) => h.text.toLowerCase().contains('synopsis') || h.text.toLowerCase().contains('plot'),
      orElse: () => Element.tag('empty'),
    );

    if (synopsisHeader.localName != 'empty') {
      final synopsisP = synopsisHeader.nextElementSibling;
      if (synopsisP?.localName == 'p') {
        synopsis = synopsisP?.text.trim() ?? '';
      }
    }

    // Fallback synopsis: first substantial paragraph in page body.
    if (synopsis.isEmpty) {
      final paragraphs = infoContainer.querySelectorAll('p');
      for (final p in paragraphs) {
        final text = p.text.trim();
        if (text.length > 80 && !text.toLowerCase().contains('download')) {
          synopsis = text;
          break;
        }
      }
    }

    // Extract image
    var imageUrl =
      document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
      document.querySelector('meta[name="twitter:image"]')?.attributes['content'] ??
      infoContainer.querySelector('img[data-lazy-src]')?.attributes['data-lazy-src'] ??
      infoContainer.querySelector('img[src]')?.attributes['src'] ??
      '';
    if (imageUrl.startsWith('//')) {
      imageUrl = 'https:$imageUrl';
    }

    // Extract links from headers (Season + Quality based) and h5 headers (Quality only)
    final links = <DownloadLink>[];

    // First, try h3/h4 headers for season-based content
    final headers = infoContainer.querySelectorAll('h2, h3, h4');

    for (var element in headers) {
      final headerTitle = element.text.trim();

      // Skip headers that don't contain quality info (480p, 720p, 1080p)
      if (!RegExp(r'\d+p').hasMatch(headerTitle)) {
        continue;
      }

      // Parse season information
      final seasonMatch = RegExp(
        r'Season\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(headerTitle);
      final seasonNum = seasonMatch?.group(1) ?? '';

      // Extract episode count like [S01E52 – Added]
      final episodeMatch = RegExp(
        r'\[S\d+E(\d+)(?:\s*[–-]\s*Added)?\]',
        caseSensitive: false,
      ).firstMatch(headerTitle);
      final episodeCount = episodeMatch?.group(1) ?? '';

      // Extract quality (480p, 720p, 1080p, etc)
      final qualityMatch = RegExp(r'(\d+p)\b').firstMatch(headerTitle);
      final quality = qualityMatch?.group(1) ?? '';

      // Extract codec and other info
      final codecMatch = RegExp(
        r'(x264|x265|10Bit|H264|HEVC|WEB-DL)',
        caseSensitive: false,
      ).firstMatch(headerTitle);
      final codec = codecMatch?.group(1) ?? '';

      // Extract size info like [80MB/E]
      final sizeMatch = RegExp(r'\[([^\]]+/E)\]').firstMatch(headerTitle);
      final size = sizeMatch?.group(1) ?? '';

      // Find the next paragraph with the episode links button
      final parent = element.parent;
      if (parent == null) continue;

      final index = parent.children.indexOf(element);
      if (index == -1 || index + 1 >= parent.children.length) continue;

      final nextElement = parent.children[index + 1];
      if (nextElement.localName != 'p') continue;

      // Look for episode links in the following paragraph.
      final episodeLinks = <String>[];

      // Extract G-Direct link (by green gradient style)
      final gDirectButton = nextElement.querySelector(
        'button[style*="background:linear-gradient(135deg,#0ebac3,#09d261)"]',
      );
      final gDirectLink = gDirectButton?.parent?.attributes['href'];
      if (gDirectLink != null &&
          gDirectLink.isNotEmpty &&
          gDirectLink != 'javascript:void(0);') {
        episodeLinks.add(gDirectLink);
      }

      // Extract V-Cloud link (by red/yellow gradient style)
      final vcloudButton = nextElement.querySelector(
        'button[style*="background:linear-gradient(135deg,#ed0b0b,#f2d152)"]',
      );
      final vcloudLink = vcloudButton?.parent?.attributes['href'];
      if (vcloudLink != null &&
          vcloudLink.isNotEmpty &&
          vcloudLink != 'javascript:void(0);') {
        episodeLinks.add(vcloudLink);
      }

      // Fallback: Check for dwd-button with "Episode Links" text
      if (episodeLinks.isEmpty) {
        final dwdButtons = nextElement.querySelectorAll('.dwd-button');
        for (var button in dwdButtons) {
          final buttonText = button.text.toLowerCase();
          if (buttonText.contains('episode')) {
            final link = button.parent?.attributes['href'];
            if (link != null &&
                link.isNotEmpty &&
                link != 'javascript:void(0);') {
              episodeLinks.add(link);
              break;
            }
          }
        }
      }

      // Fallback: collect every valid anchor in paragraph.
      if (episodeLinks.isEmpty) {
        final anchors = nextElement.querySelectorAll('a[href]');
        for (final anchor in anchors) {
          final link = anchor.attributes['href'];
          if (link != null && link.isNotEmpty && link != 'javascript:void(0);') {
            episodeLinks.add(link);
          }
        }
      }

      // Combine links with pipe delimiter
      final combinedEpisodesLink = episodeLinks.join('|');

      if (combinedEpisodesLink.isNotEmpty) {
        // Build descriptive info
        final episodeInfo = episodeCount.isNotEmpty
            ? 'E$episodeCount ${codec.isNotEmpty ? codec : ""} ${size.isNotEmpty ? size : ""}'
                  .trim()
            : '${codec.isNotEmpty ? codec : ""} ${size.isNotEmpty ? size : ""}'
                  .trim();

        links.add(
          DownloadLink(
            quality: quality,
            size: size.isNotEmpty ? size : episodeInfo,
            url: combinedEpisodesLink,
            season: seasonNum.isNotEmpty ? 'Season $seasonNum' : null,
            episodeInfo: episodeInfo.isNotEmpty ? episodeInfo : null,
          ),
        );
      }
    }

    // If no h2/h3/h4 links found, try h5 headers for direct quality downloads.
    if (links.isEmpty) {
      print(
        'vegaGetInfo: No season-based links found, looking for direct quality downloads',
      );
      final h5Headers = infoContainer.querySelectorAll('h5');

      for (var h5 in h5Headers) {
        final headerText = h5.text.trim();

        // Extract quality like "480p x264 [270MB]"
        final qualityMatch = RegExp(r'(\d+p)\s+').firstMatch(headerText);
        final quality = qualityMatch?.group(1) ?? '';

        if (quality.isEmpty) continue;

        // Extract size like [270MB] or [1.1GB]
        final sizeMatch = RegExp(r'\[([^\]]+)\]').firstMatch(headerText);
        final size = sizeMatch?.group(1) ?? '';

        // Extract codec
        final codecMatch = RegExp(
          r'(x264|x265|10Bit|HEVC|H\.264)',
          caseSensitive: false,
        ).firstMatch(headerText);
        final codec = codecMatch?.group(1) ?? '';

        // Find the next paragraph with download button
        final parent = h5.parent;
        if (parent == null) continue;

        final index = parent.children.indexOf(h5);
        if (index == -1 || index + 1 >= parent.children.length) continue;

        final nextP = parent.children[index + 1];
        if (nextP.localName != 'p') continue;

        // Extract download links (both G-Direct and V-Cloud if available)
        final downloadLinks = <String>[];

        // Extract G-Direct link (by green gradient style)
        final gDirectButton = nextP.querySelector(
          'button[style*="background:linear-gradient(135deg,#0ebac3,#09d261)"]',
        );
        final gDirectLink = gDirectButton?.parent?.attributes['href'];
        if (gDirectLink != null &&
            gDirectLink.isNotEmpty &&
            gDirectLink != 'javascript:void(0);') {
          downloadLinks.add(gDirectLink);
        }

        // Extract V-Cloud link (by red/yellow gradient style)
        final vcloudButton = nextP.querySelector(
          'button[style*="background:linear-gradient(135deg,#ed0b0b,#f2d152)"]',
        );
        final vcloudLink = vcloudButton?.parent?.attributes['href'];
        if (vcloudLink != null &&
            vcloudLink.isNotEmpty &&
            vcloudLink != 'javascript:void(0);') {
          downloadLinks.add(vcloudLink);
        }

        // Fallback: check for all valid links.
        if (downloadLinks.isEmpty) {
          final anchors = nextP.querySelectorAll('a[href]');
          for (final anchor in anchors) {
            final link = anchor.attributes['href'];
            if (link != null &&
                link.isNotEmpty &&
                link != 'javascript:void(0);') {
              downloadLinks.add(link);
            }
          }
        }

        // Combine links with pipe delimiter
        final combinedLink = downloadLinks.join('|');

        if (combinedLink.isNotEmpty) {
          final qualityInfo = codec.isNotEmpty ? '$quality $codec' : quality;

          links.add(
            DownloadLink(
              quality: quality,
              size: size,
              url: combinedLink,
              season: null,
              episodeInfo: qualityInfo,
            ),
          );
        }
      }
    }

    // Deduplicate links by URL payload while preserving order.
    final uniqueLinks = <String>{};
    final dedupedLinks = <DownloadLink>[];
    for (final item in links) {
      if (item.url.isEmpty || uniqueLinks.contains(item.url)) continue;
      uniqueLinks.add(item.url);
      dedupedLinks.add(item);
    }

    print('vegaGetInfo: Found ${dedupedLinks.length} links');
    return MovieInfo(
      title: title,
      imageUrl: imageUrl,
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: synopsis,
      downloadLinks: dedupedLinks,
    );
  } catch (error) {
    print('vegaGetInfo error: $error');
    return _emptyMovieInfo();
  }
}

MovieInfo _emptyMovieInfo() {
  return MovieInfo(
    title: '',
    imageUrl: '',
    imdbRating: '',
    genre: '',
    director: '',
    writer: '',
    stars: '',
    language: '',
    quality: '',
    format: '',
    storyline: '',
    downloadLinks: [],
  );
}
