import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static User? _currentUser;

  static final List<User> _users = [
    User.userA,
    User.userB,
    User.userC,
    User.admin,
  ];

  static Future<User?> login(String username, String password) async {
    final user = _users.firstWhere(
      (u) => u.name == username && u.password == password,
      orElse: () => User(
        name: '',
        password: '',
        isAdmin: false,
        canControlSensors: false,
        canControlServos: false,
        canControlBuzzers: false,
        canControlLeds: false,
      ),
    );

    if (user.name.isNotEmpty) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', user.name);
      return user;
    }

    return null;
  }

  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('current_user');

    if (username != null) {
      _currentUser = _users.firstWhere(
        (u) => u.name == username,
        orElse: () => User.userA,
      );
      return true;
    }

    return false;
  }

  static Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('current_user');

    if (username != null) {
      _currentUser = _users.firstWhere(
        (u) => u.name == username,
        orElse: () => User.userA,
      );
      return _currentUser;
    }

    return null;
  }

  static User? get currentUser => _currentUser;

  static bool get isAdmin => _currentUser?.isAdmin ?? false;
  
  static List<User> get allUsers => _users;
}