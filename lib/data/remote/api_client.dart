import '../../core/app_config.dart';

class ApiClient {
  ApiClient({this.accessToken});

  final String? accessToken;

  Uri buildUri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }
}
