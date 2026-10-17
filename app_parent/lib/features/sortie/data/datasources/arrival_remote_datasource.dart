import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';

abstract class ArrivalRemoteDataSource {
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request);
}

class ArrivalRemoteDataSourceImpl implements ArrivalRemoteDataSource {
  final Dio dio;
  final String? schoolId;
  final FlutterSecureStorage? secureStorage;

  ArrivalRemoteDataSourceImpl({
    required this.dio,
    this.schoolId,
    this.secureStorage,
  });

  @override
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request) async {
    String? resolvedSchoolId = schoolId;
    if (resolvedSchoolId == null || resolvedSchoolId.isEmpty) {
      resolvedSchoolId = await secureStorage?.read(key: 'auth_school_id');
    }

    final path = (resolvedSchoolId != null && resolvedSchoolId.isNotEmpty)
        ? '/v1/schools/$resolvedSchoolId/arrivals'
        : '/v1/arrivals';

    final payload = {
      'child_ids': request.childIds,
      'in_radius': request.inRadius,
      if (request.distanceMeters != null) 'distance_meters': request.distanceMeters,
    };

    final response = await dio.post(
      path,
      data: payload,
    );

    return ArrivalResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
