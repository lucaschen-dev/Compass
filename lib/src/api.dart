import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class CampusApi {
  final Uri base;
  final http.Client client;
  String? token;
  CampusApi(String url, {this.token, http.Client? client})
    : base = validate(url),
      client = client ?? http.Client();
  static Uri validate(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(uri.host)))) {
      throw ApiException(
        0,
        'Enter an HTTPS server URL. HTTP is only allowed for localhost development.',
      );
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  // Official Flutter networking recipe: https://docs.flutter.dev/cookbook/networking/fetch-data
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
    int timeout = 35,
  }) async {
    final req = http.Request(method, base.resolve(path));
    req.followRedirects = false;
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(req).timeout(Duration(seconds: timeout)),
    ).timeout(Duration(seconds: timeout));
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'The server returned an unreadable response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        data is Map
            ? data['error']?.toString() ?? 'Request failed.'
            : 'Request failed.',
      );
    }
    return data;
  }

  void close() => client.close();
}
