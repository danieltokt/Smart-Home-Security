// lib/services/localization_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLocale = 'ru';
  
  String get currentLocale => _currentLocale;
  bool get isRussian => _currentLocale == 'ru';
  bool get isEnglish => _currentLocale == 'en';

  // Загрузка языка при старте
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_language') ?? 'ru';
    notifyListeners();
  }

  // Смена языка
  Future<void> setLocale(String locale) async {
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale);
    notifyListeners();
  }

  // Переключение языка
  Future<void> toggleLanguage() async {
    await setLocale(_currentLocale == 'ru' ? 'en' : 'ru');
  }

  // Получить перевод
  String tr(String key) {
    return _translations[_currentLocale]?[key] ?? _translations['en']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'ru': {
      // Общие
      'app_title': 'Умный Дом',
      'hello': 'Привет',
      'logout': 'Выйти',
      'connect': 'Подключить',
      'disconnect': 'Отключить',
      'refresh': 'Обновить',
      'settings': 'Настройки',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'reset': 'Сбросить',
      'on': 'ВКЛ',
      'off': 'ВЫКЛ',
      'all_on': 'Все ВКЛ',
      'all_off': 'Все ВЫКЛ',
      
      // Подключение
      'connected_to': 'Подключено к',
      'offline_mode': 'Офлайн режим',
      'no_paired_devices': 'Нет сопряженных устройств',
      'select_device': 'Выберите устройство',
      'connecting': 'Подключение...',
      'connection_success': 'Подключено!',
      'connection_error': 'Ошибка подключения',
      
      // Тревога
      'alarm': 'ТРЕВОГА!',
      'motion_detected': 'Обнаружено движение!',
      'reset_alarm': 'Сбросить тревогу',
      'alarm_reset_success': 'Тревога сброшена',
      'sensor': 'Датчик',
      
      // Устройства
      'leds': 'Светодиоды',
      'buzzers': 'Баззеры',
      'servos': 'Двери (Серво)',
      'sensors': 'Датчики движения',
      'led': 'LED',
      'buzzer': 'Баззер',
      'door': 'Дверь',
      'open': 'Открыта',
      'closed': 'Закрыта',
      'open_all': 'Открыть все',
      'close_all': 'Закрыть все',
      'disabled': 'Выключен',
      
      // Админ
      'admin_panel': 'Панель администратора',
      'user_permissions': 'Управление правами доступа',
      'reset_permissions': 'Сбросить права',
      'permissions_updated': 'Права обновлены',
      'full_access': 'Полный доступ',
      'no_access': 'Нет доступа',
      
      // Настройки
      'detection_distance': 'Дистанция обнаружения',
      'cm': 'см',
      'language': 'Язык',
      'russian': 'Русский',
      'english': 'English',
      'system_settings': 'Настройки системы',
      'security_system': 'Система охраны',
    },
    
    'en': {
      // General
      'app_title': 'Smart Home',
      'hello': 'Hello',
      'logout': 'Logout',
      'connect': 'Connect',
      'disconnect': 'Disconnect',
      'refresh': 'Refresh',
      'settings': 'Settings',
      'save': 'Save',
      'cancel': 'Cancel',
      'reset': 'Reset',
      'on': 'ON',
      'off': 'OFF',
      'all_on': 'All ON',
      'all_off': 'All OFF',
      
      // Connection
      'connected_to': 'Connected to',
      'offline_mode': 'Offline mode',
      'no_paired_devices': 'No paired devices',
      'select_device': 'Select device',
      'connecting': 'Connecting...',
      'connection_success': 'Connected!',
      'connection_error': 'Connection error',
      
      // Alarm
      'alarm': 'ALARM!',
      'motion_detected': 'Motion detected!',
      'reset_alarm': 'Reset alarm',
      'alarm_reset_success': 'Alarm reset',
      'sensor': 'Sensor',
      
      // Devices
      'leds': 'LEDs',
      'buzzers': 'Buzzers',
      'servos': 'Doors (Servo)',
      'sensors': 'Motion Sensors',
      'led': 'LED',
      'buzzer': 'Buzzer',
      'door': 'Door',
      'open': 'Open',
      'closed': 'Closed',
      'open_all': 'Open all',
      'close_all': 'Close all',
      'disabled': 'Disabled',
      
      // Admin
      'admin_panel': 'Admin Panel',
      'user_permissions': 'User Permissions',
      'reset_permissions': 'Reset permissions',
      'permissions_updated': 'Permissions updated',
      'full_access': 'Full access',
      'no_access': 'No access',
      
      // Settings
      'detection_distance': 'Detection distance',
      'cm': 'cm',
      'language': 'Language',
      'russian': 'Русский',
      'english': 'English',
      'system_settings': 'System Settings',
      'security_system': 'Security System',
    },
  };
}

// Глобальный доступ к переводам
String tr(String key) => LocalizationService().tr(key);