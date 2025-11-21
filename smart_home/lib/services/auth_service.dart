// lib/services/auth_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static User? _currentUser;
  static List<User>? _users;

  static const String _usersKey = 'app_users';
  static const String _currentUserKey = 'current_user';

  /// Инициализация - загружает пользователей из SharedPreferences
  static Future<void> init() async {
    await _loadUsers();
  }

  /// Загрузка пользователей из хранилища
  static Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson != null) {
      final List<dynamic> decoded = jsonDecode(usersJson);
      _users = decoded.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
      print('✅ Загружено ${_users!.length} пользователей из хранилища');
    } else {
      // Первый запуск - создаём дефолтных пользователей
      _users = [
        User.defaultUserA,
        User.defaultUserB,
        User.defaultUserC,
        User.admin,
      ];
      await _saveUsers();
      print('✅ Созданы дефолтные пользователи');
    }
  }

  /// Сохранение пользователей в хранилище
  static Future<void> _saveUsers() async {
    if (_users == null) return;
    final prefs = await SharedPreferences.getInstance();
    final usersJson = jsonEncode(_users!.map((u) => u.toJson()).toList());
    await prefs.setString(_usersKey, usersJson);
    print('💾 Пользователи сохранены');
  }

  /// Логин
  static Future<User?> login(String username, String password) async {
    if (_users == null) await _loadUsers();

    try {
      final user = _users!.firstWhere(
        (u) => u.name == username && u.password == password,
      );
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, user.name);
      print('✅ Вход: ${user.name}');
      return user;
    } catch (_) {
      print('❌ Неверный логин/пароль');
      return null;
    }
  }

  /// Выход
  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    print('👋 Выход из системы');
  }

  /// Восстановление сессии
  static Future<bool> restoreSession() async {
    if (_users == null) await _loadUsers();

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_currentUserKey);

    if (username == null) return false;

    try {
      _currentUser = _users!.firstWhere((u) => u.name == username);
      print('✅ Сессия восстановлена: ${_currentUser!.name}');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Текущий пользователь
  static Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    if (_users == null) await _loadUsers();

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_currentUserKey);

    if (username != null) {
      try {
        _currentUser = _users!.firstWhere((u) => u.name == username);
        return _currentUser;
      } catch (_) {}
    }
    return null;
  }

  static User? get currentUser => _currentUser;
  static bool get isAdmin => _currentUser?.isAdmin ?? false;
  static List<User> get allUsers => _users ?? [];

  /// ===== УПРАВЛЕНИЕ ПРАВАМИ (ДЛЯ АДМИНА) =====

  /// Получить список обычных пользователей (не админов)
  static List<User> getManagedUsers() {
    if (_users == null) return [];
    return _users!.where((u) => !u.isAdmin).toList();
  }

  /// Переключить конкретное право
  static Future<void> togglePermission(String username, String permission) async {
    if (_users == null) await _loadUsers();

    final index = _users!.indexWhere((u) => u.name == username);
    if (index == -1) return;

    final user = _users![index];

    switch (permission) {
      case 'sensors':
        user.canControlSensors = !user.canControlSensors;
        break;
      case 'servos':
        user.canControlServos = !user.canControlServos;
        break;
      case 'buzzers':
        user.canControlBuzzers = !user.canControlBuzzers;
        break;
      case 'leds':
        user.canControlLeds = !user.canControlLeds;
        break;
    }

    await _saveUsers();
    print('🔐 ${user.name}.$permission = toggled');
  }

  /// Сбросить права к дефолтным
  static Future<void> resetPermissions() async {
    _users = [
      User.defaultUserA,
      User.defaultUserB,
      User.defaultUserC,
      User.admin,
    ];
    await _saveUsers();
    print('🔄 Права сброшены к дефолтным');
  }
}