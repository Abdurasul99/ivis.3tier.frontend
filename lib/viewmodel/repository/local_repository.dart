import 'package:shared_preferences/shared_preferences.dart';

class LocalRepository {
  final String accessTokenKey = "accessToken";
  final String rememberMeKey = "rememberMe";
  final String loginEmailKey = "loginEmail";

  Future<bool> saveAccessToken(String accessToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(accessTokenKey, accessToken);
  }

  Future<String> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey) ?? '';
  }

  Future<bool> saveRememberMe(bool rememberMe) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(rememberMeKey, rememberMe);
  }

  Future<bool> getRememberMe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(rememberMeKey) ?? false;
  }

  Future<bool> saveLoginEmail(String loginEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(loginEmailKey, loginEmail);
  }

  Future<String> getLoginEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(loginEmailKey) ?? '';
  }

  Future clearAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(accessTokenKey);
  }

  Future clearPreferencesValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(accessTokenKey);
    prefs.remove(rememberMeKey);
    prefs.remove(loginEmailKey);
  }
}
