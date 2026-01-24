import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../local/models.dart';

class PosCustomerApi {
  PosCustomerApi(this.apiClient);

  final ApiClient apiClient;

  Future<MemberModel> searchOnlineMember(String storeId, String phone) async {
    final uri = apiClient.buildUri('/customers/search/$storeId', {'phone': phone});
    
    final response = await http.get(
      uri,
      headers: apiClient.headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _mapToMember(data, storeId);
    } else if (response.statusCode == 404) {
      throw Exception('회원을 찾을 수 없습니다.');
    } else {
      throw Exception('회원 검색 실패: ${response.statusCode}');
    }
  }

  Future<MemberModel> registerMember(String storeId, String name, String phone) async {
    final uri = apiClient.buildUri('/customers/register/$storeId');
    
    final response = await http.post(
      uri,
      headers: apiClient.headers,
      body: json.encode({
        'name': name,
        'phoneNumber': phone,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return _mapToMember(data, storeId);
    } else {
      throw Exception('회원 등록 실패: ${response.statusCode}');
    }
  }

  MemberModel _mapToMember(Map<String, dynamic> data, String storeId) {
    // API returns Membership object with Customer included
    final customer = data['customer'];
    return MemberModel(
      id: data['id'],
      storeId: storeId,
      name: customer['name'] ?? '고객',
      phone: customer['phoneNumber'],
      points: (data['pointsBalance'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
    );
  }
}
