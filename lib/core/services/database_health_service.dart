import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_service.dart';

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
        debugPrint('❌ Healthcheck: Sin conexión a internet');
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

      debugPrint('✅ Healthcheck: Conexión exitosa');
      return true;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Healthcheck timeout: $e');
      return false;
    } on SocketException catch (e) {
      debugPrint('🌐 Healthcheck sin conexión de red: $e');
      return false;
    } on PostgrestException catch (e) {
      debugPrint('💾 Healthcheck error de BD: ${e.message}');
      return false;
    } on AuthException catch (e) {
      debugPrint('🔒 Healthcheck error de autenticación: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Healthcheck error genérico: $e');
      return false;
    }
  }
}
