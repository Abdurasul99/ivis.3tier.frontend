import '../../constants/constants.dart';
import 'base_repository.dart';

class MapRepository extends BaseRepository {
  final String path = '/';

  Uri get uri => Uri.http(kMapHost, path);
}
