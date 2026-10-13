import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _kPin = 'app_pin';

  static Future<bool> hasPin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPin) != null;
  }

  static Future<void> savePin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPin, pin);
  }

  static Future<bool> verifyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPin) == pin;
  }

  static Future<void> clearPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPin);
  }
}
