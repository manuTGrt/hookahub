import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/app_toast.dart';
import '../../features/catalog/data/tobacco_repository.dart';
import '../../features/catalog/presentation/tobacco_detail_page.dart';
import '../../features/community/data/community_repository.dart';
import '../../features/community/presentation/mix_detail_page.dart';

/// Servicio centralizado para la captura, generación y navegación de Deep Links en Hookahub.
///
/// Soporta esquemas personalizados como:
/// - Tabaco: `hookahub://share/tobacco?id=<TOBACCO_ID>`
/// - Mezcla: `hookahub://share/mix?id=<MIX_ID>`
class DeepLinkService {
  DeepLinkService._();

  /// Instancia única del servicio.
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final TobaccoRepository _tobaccoRepository = TobaccoRepository(SupabaseService());
  final CommunityRepository _communityRepository = CommunityRepository(SupabaseService());

  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;
  String? _lastHandledUri;
  DateTime? _lastHandledAt;

  // ─── Generadores Estáticos de URLs ──────────────────────────────────────────

  /// Dominio web oficial para compartir recursos mediante enlaces HTTPS compatibles con mensajería (WhatsApp, Telegram, etc.).
  static const String webBaseUrl = 'https://hookahub.manutech.duckdns.org';

  /// Genera un enlace web HTTPS para compartir un tabaco específico.
  /// Reconocido por aplicaciones de mensajería como enlace interactivo (clicable).
  static String buildTobaccoShareUrl(String id) => '$webBaseUrl/share/tobacco?id=$id';

  /// Genera un enlace web HTTPS para compartir una mezcla específica.
  /// Reconocido por aplicaciones de mensajería como enlace interactivo (clicable).
  static String buildMixShareUrl(String id) => '$webBaseUrl/share/mix?id=$id';

  /// Genera el URI de esquema nativo interno para tabaco (`hookahub://`).
  static String buildNativeTobaccoUri(String id) => 'hookahub://share/tobacco?id=$id';

  /// Genera el URI de esquema nativo interno para mezcla (`hookahub://`).
  static String buildNativeMixUri(String id) => 'hookahub://share/mix?id=$id';

  // ─── Inicialización y Ciclo de Vida ─────────────────────────────────────────

  /// Inicializa la escucha de deep links tanto para arranque en frío (cold start)
  /// como para eventos entrantes con la aplicación en segundo o primer plano.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Escuchar enlaces entrantes en caliente (warm / foreground start)
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          handleUri(uri);
        },
        onError: (err, stackTrace) {
          AppLogger.error(
            'Error en el stream de deep links',
            error: err,
            stackTrace: stackTrace is StackTrace ? stackTrace : null,
          );
        },
      );

      // 2. Comprobar enlace inicial en arranque en frío (cold start)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        AppLogger.info('Deep link inicial detectado (cold start): $initialUri');
        await handleUri(initialUri);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al inicializar DeepLinkService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancela la suscripción a eventos de enlaces.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }

  // ─── Procesamiento y Navegación ─────────────────────────────────────────────

  /// Procesa una [Uri] entrante y navega al detalle correspondiente si es válida.
  Future<void> handleUri(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // Validar esquema: aceptamos tanto el esquema nativo hookahub:// como https/http con nuestro host oficial
    final isCustomScheme = scheme == 'hookahub';
    final isOfficialWebDomain = (scheme == 'https' || scheme == 'http') &&
        (host == 'hookahub.manutech.duckdns.org');

    if (!isCustomScheme && !isOfficialWebDomain) {
      return;
    }

    final uriString = uri.toString();
    final now = DateTime.now();

    // Evitar navegación redundante/duplicada si se recibe el mismo URI en un intervalo corto
    if (_lastHandledUri == uriString &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inSeconds < 2) {
      AppLogger.info('Deep link ignorado por duplicado reciente: $uriString');
      return;
    }
    _lastHandledUri = uriString;
    _lastHandledAt = now;

    AppLogger.info('Deep link recibido para procesar: $uriString');

    final pathSegments = uri.pathSegments;
    final path = uri.path.toLowerCase();

    // Identificar tipo de recurso
    final isTobacco = host == 'tobacco' ||
        pathSegments.contains('tobacco') ||
        path.contains('tobacco');

    final isMix = host == 'mix' ||
        pathSegments.contains('mix') ||
        path.contains('mix');

    if (!isTobacco && !isMix) {
      AppLogger.warning('Tipo de deep link no reconocido: $uriString');
      return;
    }

    // Extraer identificador del recurso:
    // 1. Por query parameter ?id=...
    String? id = uri.queryParameters['id'];

    // 2. Si no viene por query, buscar en pathSegments tras el tipo de recurso ('tobacco' o 'mix')
    if (id == null || id.trim().isEmpty) {
      final typeIndex = pathSegments.indexWhere(
        (seg) => seg.toLowerCase() == 'tobacco' || seg.toLowerCase() == 'mix',
      );
      if (typeIndex != -1 && pathSegments.length > typeIndex + 1) {
        id = pathSegments[typeIndex + 1];
      }
    }

    if (id == null || id.trim().isEmpty) {
      AppLogger.warning('Deep link sin ID válido: $uriString');
      return;
    }

    final cleanId = id.trim();

    // Esperar a que el navegador esté disponible antes de interactuar con la UI
    await _waitForNavigator();

    if (isTobacco) {
      await _handleTobaccoDeepLink(cleanId);
    } else if (isMix) {
      await _handleMixDeepLink(cleanId);
    }
  }

  Future<void> _handleTobaccoDeepLink(String id) async {
    try {
      final tobacco = await _tobaccoRepository.fetchTobaccoById(id);
      final navState = rootNavigatorKey.currentState;
      final context = rootNavigatorKey.currentContext;

      if (tobacco != null && navState != null) {
        AppLogger.info('Navegando a detalle de tabaco: ${tobacco.name} ($id)');
        navState.push(
          MaterialPageRoute(
            builder: (_) => TobaccoDetailPage(tobacco: tobacco),
          ),
        );
      } else {
        AppLogger.warning('Tabaco con ID $id no encontrado');
        if (context != null && context.mounted) {
          AppToast.showInfo(context, 'El tabaco ya no está disponible');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al resolver deep link de tabaco: $id',
        error: e,
        stackTrace: stackTrace,
      );
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        AppToast.showInfo(context, 'El tabaco ya no está disponible');
      }
    }
  }

  Future<void> _handleMixDeepLink(String id) async {
    try {
      final mix = await _communityRepository.fetchMixById(id);
      final navState = rootNavigatorKey.currentState;
      final context = rootNavigatorKey.currentContext;

      if (mix != null && navState != null) {
        AppLogger.info('Navegando a detalle de mezcla: ${mix.name} ($id)');
        navState.push(
          MaterialPageRoute(
            builder: (_) => MixDetailPage(mix: mix),
          ),
        );
      } else {
        AppLogger.warning('Mezcla con ID $id no encontrada');
        if (context != null && context.mounted) {
          AppToast.showInfo(context, 'La mezcla ya no está disponible');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al resolver deep link de mezcla: $id',
        error: e,
        stackTrace: stackTrace,
      );
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        AppToast.showInfo(context, 'La mezcla ya no está disponible');
      }
    }
  }

  /// Espera de manera asíncrona a que el árbol de widgets y [rootNavigatorKey] estén listos.
  Future<void> _waitForNavigator() async {
    if (rootNavigatorKey.currentState != null) return;

    int attempts = 0;
    while (rootNavigatorKey.currentState == null && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }
}
