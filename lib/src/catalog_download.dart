import 'dart:convert';
import 'dart:io';

final _catalogUri = Uri.https(
  'raw.githubusercontent.com',
  '/dangvusontung/my-fish-tank/main/catalog/fish-v1.json',
);
const _timeout = Duration(seconds: 6);
const maxCatalogBytes = 256 * 1024;

Future<String> fetchFishCatalog() async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    return await _download(client).timeout(_timeout);
  } finally {
    client.close(force: true);
  }
}

Future<String> _download(HttpClient client) async {
  final request = await client.getUrl(_catalogUri);
  request.followRedirects = false;
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Fish catalog HTTP ${response.statusCode}');
  }
  if (response.contentLength > maxCatalogBytes) {
    throw const FormatException('Fish catalog is too large');
  }
  final bytes = <int>[];
  await for (final chunk in response) {
    if (bytes.length + chunk.length > maxCatalogBytes) {
      throw const FormatException('Fish catalog is too large');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}
