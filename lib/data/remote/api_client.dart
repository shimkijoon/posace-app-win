import '../../core/app_config.dart';

class ApiClient {
  ApiClient({this.accessToken});

  final String? accessToken;

  Uri buildUri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }
}
