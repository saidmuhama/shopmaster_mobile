import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../generated/l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

extension L10nExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  LocaleProvider get localeProvider => read<LocaleProvider>();
  LocaleProvider get localeProviderWatch => watch<LocaleProvider>();
}
