import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../provider/extractors/hubcloud_extractor.dart';
import '../provider/extractors/gdflix_extractor.dart';
import '../provider/extractors/filepress_extractor.dart' show FilepressExtractor;
import '../provider/extractors/gdirect_extractor.dart';
import '../provider/extractors/vcloud_extractor.dart';
import '../utils/key_event_handler.dart';

class ExtractorTestScreen extends StatefulWidget {
  const ExtractorTestScreen({super.key});

  @override
  State<ExtractorTestScreen> createState() => _ExtractorTestScreenState();
}

class _ExtractorTestScreenState extends State<ExtractorTestScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  
  String _selectedExtractor = 'HubCloud';
  bool _isExtracting = false;
  List<stream_types.Stream> _extractedStreams = [];
  String _errorMessage = '';
  
  final List<Map<String, dynamic>> _extractors = [
    {
      'name': 'HubCloud',
      'icon': Icons.cloud_outlined,
      'description': 'Extract from HubCloud links',
      'color': const Color(0xFF00BCD4),
    },
    {
      'name': 'GdFlix',
      'icon': Icons.movie_outlined,
      'description': 'Extract from GdFlix links',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': 'FilePress',
      'icon': Icons.file_present_outlined,
      'description': 'Extract from FilePress links',
      'color': const Color(0xFFFF9800),
    },
    {
      'name': 'GDirect',
      'icon': Icons.drive_file_rename_outline,
      'description': 'Extract from Google Drive links',
      'color': const Color(0xFF9C27B0),
    },
    {
      'name': 'VCloud',
      'icon': Icons.cloud_download_outlined,
      'description': 'Extract from VCloud links',
      'color': const Color(0xFFE91E63),
    },
  ];

  int _selectedExtractorIndex = 0;
  int _selectedStreamIndex = 0;
  bool _isExtractorFocused = false;

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _extractStreams() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _extractedStreams = [];
      _errorMessage = '';
      _selectedStreamIndex = 0;
    });

    try {
      List<stream_types.Stream> streams = [];
      final url = _urlController.text.trim();

      switch (_selectedExtractor) {
        case 'HubCloud':
          final response = await HubCloudExtractor.extractLinks(url);
          streams = response.streams;
          break;
        case 'GdFlix':
          streams = await GdFlixExtractor.extractStreams(url);
          break;
        case 'FilePress':
          streams = await FilepressExtractor.extractStreams(url);
          break;
        case 'GDirect':
          streams = await GDirectExtractor.extractStreams(url);
          break;
        case 'VCloud':
          streams = await VCloudExtractor.extractStreams(url);
          break;
      }

      setState(() {
        _isExtracting = false;
        _extractedStreams = streams;
        if (streams.isEmpty) {
          _errorMessage = 'No streams found';
        }
      });
    } catch (e) {
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard!'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateExtractors(int delta) {
    setState(() {
      _selectedExtractorIndex = (_selectedExtractorIndex + delta) % _extractors.length;
      if (_selectedExtractorIndex < 0) {
        _selectedExtractorIndex = _extractors.length - 1;
      }
      _selectedExtractor = _extractors[_selectedExtractorIndex]['name'] as String;
    });
  }

  void _navigateStreams(int delta) {
    if (_extractedStreams.isEmpty) return;
    
    setState(() {
      _selectedStreamIndex = (_selectedStreamIndex + delta) % _extractedStreams.length;
      if (_selectedStreamIndex < 0) {
        _selectedStreamIndex = _extractedStreams.length - 1;
      }
    });
  }

  void _navigateVertical(int delta) {
    if (_urlFocusNode.hasFocus) {
      if (delta > 0) {
        _urlFocusNode.unfocus();
        setState(() {
          _isExtractorFocused = true;
        });
      }
    } else if (_isExtractorFocused) {
      if (delta < 0) {
        setState(() {
          _isExtractorFocused = false;
        });
        _urlFocusNode.requestFocus();
      } else if (delta > 0 && _extractedStreams.isNotEmpty) {
        setState(() {
          _isExtractorFocused = false;
        });
      }
    } else if (_extractedStreams.isNotEmpty) {
      if (delta < 0) {
        setState(() {
          _isExtractorFocused = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onLeftKey: () {
        if (_urlFocusNode.hasFocus) return;
        if (_isExtractorFocused) {
          _navigateExtractors(-1);
        } else if (_extractedStreams.isNotEmpty) {
          _navigateStreams(-1);
        }
      },
      onRightKey: () {
        if (_urlFocusNode.hasFocus) return;
        if (_isExtractorFocused) {
          _navigateExtractors(1);
        } else if (_extractedStreams.isNotEmpty) {
          _navigateStreams(1);
        }
      },
      onUpKey: () {
        if (!_urlFocusNode.hasFocus) {
          _navigateVertical(-1);
        }
      },
      onDownKey: () {
        if (!_urlFocusNode.hasFocus) {
          _navigateVertical(1);
        }
      },
      onEnterKey: () {
        if (_urlFocusNode.hasFocus) {
          _extractStreams();
        } else if (_isExtractorFocused) {
          _extractStreams();
        } else if (_extractedStreams.isNotEmpty) {
          _copyToClipboard(_extractedStreams[_selectedStreamIndex].link);
        }
      },
      onBackKey: () {
        if (_urlFocusNode.hasFocus) {
          Navigator.pop(context);
        } else {
          _urlFocusNode.requestFocus();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Extractor Test Lab',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL Input Section
              _buildUrlInputSection(),
              
              const SizedBox(height: 32),
              
              // Extractor Selection
              _buildExtractorSelection(),
              
              const SizedBox(height: 32),
              
              // Extract Button
              _buildExtractButton(),
              
              const SizedBox(height: 32),
              
              // Results Section
              if (_isExtracting)
                _buildLoadingIndicator()
              else if (_errorMessage.isNotEmpty)
                _buildErrorMessage()
              else if (_extractedStreams.isNotEmpty)
                _buildResultsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.link,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Enter URL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _urlFocusNode.hasFocus 
                ? Colors.white.withOpacity(0.1) 
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _urlFocusNode.hasFocus 
                  ? const Color(0xFFFFD700) 
                  : Colors.white.withOpacity(0.1),
              width: 2,
            ),
          ),
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste your link here (e.g., hubcloud.link/...)',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _extractStreams(),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.settings_suggest,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Select Extractor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _extractors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final extractor = _extractors[index];
              final isSelected = _selectedExtractor == extractor['name'];
              final isFocused = _isExtractorFocused && _selectedExtractorIndex == index;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedExtractor = extractor['name'] as String;
                    _selectedExtractorIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected || isFocused
                        ? LinearGradient(
                            colors: [
                              (extractor['color'] as Color).withOpacity(0.3),
                              (extractor['color'] as Color).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected || isFocused ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFocused 
                          ? const Color(0xFFFFD700)
                          : (isSelected 
                              ? (extractor['color'] as Color) 
                              : Colors.white.withOpacity(0.1)),
                      width: isFocused ? 2.5 : 2,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        extractor['icon'] as IconData,
                        color: isSelected || isFocused 
                            ? extractor['color'] as Color 
                            : Colors.grey[500],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        extractor['name'] as String,
                        style: TextStyle(
                          color: isSelected || isFocused ? Colors.white : Colors.grey[400],
                          fontSize: 16,
                          fontWeight: isSelected || isFocused ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        extractor['description'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExtractButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isExtracting ? null : _extractStreams,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isExtracting ? Icons.hourglass_empty : Icons.play_arrow,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _isExtracting ? 'Extracting...' : 'Extract Streams',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFFD700),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Extracting streams...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: const Color(0xFF4CAF50),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Extracted Streams (${_extractedStreams.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _extractedStreams.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final stream = _extractedStreams[index];
            final isSelected = !_isExtractorFocused && 
                              !_urlFocusNode.hasFocus && 
                              _selectedStreamIndex == index;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withOpacity(0.1) 
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFFFFD700) 
                      : Colors.white.withOpacity(0.1),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _copyToClipboard(stream.link),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stream.server,
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stream.type.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue[300],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _copyToClipboard(stream.link),
                              icon: const Icon(
                                Icons.copy,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  stream.link,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (stream.headers != null && stream.headers!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Headers',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: stream.headers!.entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${entry.key}: ',
                                              style: TextStyle(
                                                color: Colors.blue[300],
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            TextSpan(
                                              text: entry.value,
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
