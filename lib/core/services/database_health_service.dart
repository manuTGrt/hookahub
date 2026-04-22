import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_service.dart';
import '../utils/app_logger.dart';

class DatabaseHealthService {
  final SupabaseService _supabaseService;
  final Connectivity _connectivity = Connectivity();

  DatabaseHealthService(this._supabaseService);

  /// Verifica la conexión a internet y a la base de datos
  /// Retorna true si todo está conectado, false si hay algún fallo
  Future<bool> checkDatabaseConnection() async {
    try {
      // 1. Primero verificar si hay conexión a internet
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        AppLogger.warning('❌ Healthcheck: Sin conexión a internet');
        return false;
      }

      // 2. Luego verificar acceso a la base de datos con query ligera
      await _supabaseService.client
          .from('profiles')
          .select()
          .limit(1)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Database query timeout'),
          );

      AppLogger.info('✅ Healthcheck: Conexión exitosa');
      return true;
    } on TimeoutException catch (e) {
      AppLogger.error('⏱️ Healthcheck timeout: $e');
      return false;
    } on SocketException catch (e) {
      AppLogger.error('🌐 Healthcheck sin conexión de red: $e');
      return false;
    } on PostgrestException catch (e) {
      AppLogger.error('💾 Healthcheck error de BD: ${e.message}');
      return false;
    } on AuthException catch (e) {
      AppLogger.error('🔒 Healthcheck error de autenticación: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.error('❌ Healthcheck error genérico: $e');
      return false;
    }
  }
}
