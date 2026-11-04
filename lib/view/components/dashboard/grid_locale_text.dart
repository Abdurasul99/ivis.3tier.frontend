import 'package:pluto_grid/pluto_grid.dart';

import '../../../i18n/app_locale.dart';

/// PlutoGrid built-in texts (filter types, loading text, popups) for the
/// current locale. Filter type names are static inside PlutoGrid, so every
/// grid must pass the same texts; the dashboard keeps its short filter names.
PlutoGridLocaleText dashboardGridLocaleText() {
  if (isEnglishLocale) {
    return PlutoGridLocaleText(
      filterContains: t('검색'),
      filterEquals: t('일치'),
      filterStartsWith: t('시작'),
      filterEndsWith: t('끝'),
    );
  }
  return PlutoGridLocaleText.korean(
    filterContains: t('검색'),
    filterEquals: t('일치'),
    filterStartsWith: t('시작'),
    filterEndsWith: t('끝'),
  );
}
