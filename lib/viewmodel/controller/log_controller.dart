import 'package:get/get.dart';

import '../../i18n/app_locale.dart';
import '../repository/log_repository.dart';

class LogController extends GetxController {
  final LogRepository _repository = LogRepository();

  bool isDownloading = false;

  Future<void> downloadLatestLog() async {
    if (isDownloading) return;

    try {
      isDownloading = true;
      update();

      final List<LogFileInfo> files = await _repository.fetchLogFiles();

      if (files.isEmpty) {
        Get.snackbar(l10n('알림', 'Notice'), t('다운로드 가능한 XLS 로그 파일이 없습니다.'));
        return;
      }

      files.sort((a, b) {
        final DateTime da = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime db = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      final LogFileInfo latest = files.first;

      await _repository.downloadLogFile(
        latest.fileName,
        exp: latest.downloadExp,
        sig: latest.downloadSig,
      );

      Get.snackbar(t('완료'), t('로그 파일 다운로드를 시작했습니다.'));
    } catch (e) {
      Get.snackbar(t('오류'), t('로그 다운로드 중 문제가 발생했습니다.'));
    } finally {
      isDownloading = false;
      update();
    }
  }
}
