import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/providers/database_health_provider.dart';
import '../l10n/app_localizations.dart';

class DatabaseConnectionBanner extends StatelessWidget {
  const DatabaseConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseHealthProvider>(
      builder: (context, provider, child) {
        final isVisible = !provider.isConnected;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final background = theme.brightness == Brightness.dark
          ? warningSurfaceDark
          : warningSurfaceLight;
        final accentColor = colorScheme.error;
        final textColor = theme.brightness == Brightness.dark
          ? Colors.white
          : accentColor;
        final localizations = AppLocalizations.of(context);
        final message = localizations?.databaseOfflineMessage ?? 'Conexión perdida';
        final retryText = localizations?.databaseRetryButton ?? 'Reintentar';

        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            offset: isVisible ? Offset.zero : const Offset(0, -1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isVisible ? 1 : 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(20),
                      color: background,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off, color: textColor),
                            const SizedBox(width: 12),
                            Text(
                              message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              onPressed: provider.isChecking
                                  ? null
                                  : () {
                                      provider.retryConnection();
                                    },
                              child: provider.isChecking
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(retryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
