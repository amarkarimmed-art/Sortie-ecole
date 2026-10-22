import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth_session_memory.dart';

abstract class ArrivalRemoteDataSource {
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request);
  Future<Map<String, dynamic>> getArrivalStatus();
}

class ArrivalRemoteDataSourceImpl implements ArrivalRemoteDataSource {
  final Dio dio;
  final String? schoolId;
  final FlutterSecureStorage? secureStorage;
  static const _uuid = Uuid();

  ArrivalRemoteDataSourceImpl({
    required this.dio,
    this.schoolId,
    this.secureStorage,
  });

  @override
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request) async {
    String? resolvedSchoolId = schoolId ?? AuthSessionMemory.schoolId;
    if (resolvedSchoolId == null || resolvedSchoolId.isEmpty) {
      resolvedSchoolId = await secureStorage?.read(key: 'auth_school_id');
    }

    final token = AuthSessionMemory.token ?? await secureStorage?.read(key: 'auth_token');
    final idempotencyKey = _uuid.v4();

    final path = (resolvedSchoolId != null && resolvedSchoolId.isNotEmpty)
        ? '/v1/schools/$resolvedSchoolId/arrivals'
        : '/v1/arrivals';

    final options = Options(
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Idempotency-Key': idempotencyKey,
      },
    );

    final response = await dio.post(
      path,
      data: request.toJson(),
      options: options,
    );

    return ArrivalResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getArrivalStatus() async {
    String? resolvedSchoolId = schoolId ?? AuthSessionMemory.schoolId;
    if (resolvedSchoolId == null || resolvedSchoolId.isEmpty) {
      resolvedSchoolId = await secureStorage?.read(key: 'auth_school_id');
    }

    final token = AuthSessionMemory.token ?? await secureStorage?.read(key: 'auth_token');
    final path = (resolvedSchoolId != null && resolvedSchoolId.isNotEmpty)
        ? '/v1/schools/$resolvedSchoolId/arrivals/status'
        : '/v1/arrivals/status';

    final options = Options(
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    final response = await dio.get(
      path,
      options: options,
    );

    return response.data as Map<String, dynamic>;
  }
}
