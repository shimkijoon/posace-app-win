import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Helper extension to safely get localizations
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw FlutterError(
        'AppLocalizations not found. Make sure the widget is wrapped in MaterialApp with AppLocalizations.delegate.',
      );
    }
    return localizations;
  }
}
