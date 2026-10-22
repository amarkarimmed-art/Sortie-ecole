import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

import '../../domain/failures/arrival_exceptions.dart';
import '../../domain/repositories/arrival_repository.dart';
import '../datasources/arrival_remote_datasource.dart';

class ArrivalRepositoryImpl implements ArrivalRepository {
  final ArrivalRemoteDataSource remoteDataSource;

  ArrivalRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request) async {
    try {
      return await remoteDataSource.signalArrival(request);
    } on DioException catch (dioError) {
      throw _mapDioErrorToException(dioError);
    } catch (e) {
      if (e is ArrivalException) rethrow;
      throw ServerArrivalException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getArrivalStatus() async {
    try {
      return await remoteDataSource.getArrivalStatus();
    } on DioException catch (dioError) {
      throw _mapDioErrorToException(dioError);
    } catch (e) {
      if (e is ArrivalException) rethrow;
      throw ServerArrivalException(e.toString());
    }
  }

  ArrivalException _mapDioErrorToException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? serverMessage;

    if (responseData is Map<String, dynamic>) {
      serverMessage = responseData['message'] as String?;
    }

    if (statusCode == 429) {
      return RateLimitException(
        serverMessage ?? 'Trop de tentatives rapprochées. Veuillez patienter avant de signaler à nouveau.',
      );
    }

    if (statusCode == 400 || statusCode == 422) {
      return OutOfRadiusException(
        serverMessage ?? 'Vous devez être dans le rayon autorisé autour de l\'école pour signaler votre arrivée.',
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      return UnauthorizedArrivalException(
        serverMessage ?? 'Accès non autorisé ou session expirée.',
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerArrivalException(
        serverMessage ?? 'Erreur interne du serveur lors du traitement de l\'arrivée.',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkArrivalException(
          'Impossible de joindre le serveur. Veuillez vérifier votre connexion Internet.',
        );
      case DioExceptionType.cancel:
        return const NetworkArrivalException('La requête a été annulée.');
      default:
        return ServerArrivalException(
          serverMessage ?? error.message ?? 'Une erreur réseau inattendue est survenue.',
        );
    }
  }
}
