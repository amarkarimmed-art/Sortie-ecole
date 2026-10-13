import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

abstract class ArrivalRemoteDataSource {
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request);
}

class ArrivalRemoteDataSourceImpl implements ArrivalRemoteDataSource {
  final Dio dio;

  ArrivalRemoteDataSourceImpl({required this.dio});

  @override
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request) async {
    final response = await dio.post(
      '/v1/arrivals',
      data: request.toJson(),
    );

    return ArrivalResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
