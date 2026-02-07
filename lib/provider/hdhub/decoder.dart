import 'dart:convert';

/// ROT13 cipher decoder
String _rot13(String str) {
  return str.split('').map((char) {
    final charCode = char.codeUnitAt(0);
    
    // Check if character is a letter
    if ((charCode >= 65 && charCode <= 90) || (charCode >= 97 && charCode <= 122)) {
      final isUpperCase = charCode <= 90;
      final baseCharCode = isUpperCase ? 65 : 97;
      return String.fromCharCode(((charCode - baseCharCode + 13) % 26) + baseCharCode);
    }
    
    return char;
  }).join('');
}

/// Decode encrypted string from hdhub4u
/// Flow: base64 -> base64 -> ROT13 -> base64 -> JSON
Map<String, dynamic>? decodeString(String encryptedString) {
  try {
    print('Starting decode with: $encryptedString');
    
    // First base64 decode - use latin1 instead of utf8 for binary data
    var bytes = base64.decode(encryptedString);
    String decoded = latin1.decode(bytes);
    print('After first base64 decode: $decoded');

    // Second base64 decode - again use latin1 for binary data
    bytes = base64.decode(decoded);
    decoded = latin1.decode(bytes);
    print('After second base64 decode: $decoded');

    // ROT13 decode
    decoded = _rot13(decoded);
    print('After ROT13 decode: $decoded');

    // Third base64 decode - now we can use utf8 as result should be JSON
    bytes = base64.decode(decoded);
    decoded = utf8.decode(bytes);
    print('After third base64 decode: $decoded');

    // Parse JSON
    final result = json.decode(decoded) as Map<String, dynamic>;
    print('Final parsed result: $result');
    return result;
  } catch (error) {
    print('Error decoding string: $error');
    
    // Try alternative decoding approach (just double base64)
    try {
      print('Trying alternative decode approach...');
      var altBytes = base64.decode(encryptedString);
      String altDecoded = latin1.decode(altBytes);
      altBytes = base64.decode(altDecoded);
      altDecoded = utf8.decode(altBytes);
      final altResult = json.decode(altDecoded) as Map<String, dynamic>;
      print('Alternative decode successful: $altResult');
      return altResult;
    } catch (altError) {
      print('Alternative decode also failed: $altError');
      return null;
    }
  }
}
