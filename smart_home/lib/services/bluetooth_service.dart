import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  static BluetoothConnection? _connection;
  static bool _isConnected = false;
  static String _connectedDeviceName = '';
  
  // Stream контроллеры для реактивных обновлений
  static final _sensorDataController = StreamController<Map<String, double>>.broadcast();
  static final _alertController = StreamController<String>.broadcast();

  static bool get isConnected => _isConnected;
  static String get connectedDeviceName => _connectedDeviceName;
  
  // Получить stream данных датчиков
  static Stream<Map<String, double>> get sensorDataStream => _sensorDataController.stream;
  static Stream<String> get alertStream => _alertController.stream;

  // Получить список доступных Bluetooth устройств
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      print('Найдено устройств: ${devices.length}');
      return devices;
    } catch (e) {
      print('Ошибка получения устройств: $e');
      return [];
    }
  }

  // Подключиться к устройству
  static Future<bool> connect(BluetoothDevice device) async {
    try {
      print('Попытка подключения к ${device.name}...');
      
      // Закрываем предыдущее подключение если есть
      await disconnect();

      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      _connectedDeviceName = device.name ?? 'HC-06';

      print('✅ Подключено к ${device.name}');
      print('Адрес: ${device.address}');
      
      // Слушаем входящие данные
      _connection!.input!.listen((Uint8List data) {
        String response = utf8.decode(data).trim();
        debugPrint('📩 Получено от Arduino: $response');
        
        // Парсим данные датчиков
        if (response.startsWith('SENSORS:')) {
          _parseSensorData(response);
        }
        // Парсим статусы
        else if (response.startsWith('STATUS:')) {
          debugPrint('📊 Статус: $response');
        }
        // Парсим алерты
        else if (response.startsWith('ALERT:')) {
          debugPrint('🚨 ТРЕВОГА: $response');
          _alertController.add(response.replaceAll('ALERT:', ''));
        }
      }).onDone(() {
        debugPrint('❌ Bluetooth соединение разорвано');
        _isConnected = false;
      });
      
      return true;
    } catch (e) {
      print('❌ Ошибка подключения: $e');
      _isConnected = false;
      return false;
    }
  }
  
  // Парсинг данных датчиков
  static void _parseSensorData(String data) {
    try {
      // Формат: "SENSORS:S0:10.5,S1:15.2,S2:8.9"
      debugPrint('Парсинг: $data');
      
      final parts = data.replaceAll('SENSORS:', '').split(',');
      Map<String, double> sensors = {};
      
      for (var part in parts) {
        final pair = part.split(':');
        if (pair.length == 2) {
          final name = pair[0].trim();
          final value = double.tryParse(pair[1].trim()) ?? 0.0;
          sensors[name] = value;
          debugPrint('  $name = $value см');
        }
      }
      
      // Отправляем данные в stream
      if (sensors.isNotEmpty) {
        _sensorDataController.add(sensors);
      }
    } catch (e) {
      debugPrint('Ошибка парсинга датчиков: $e');
    }
  }

  // Отключиться от устройства
  static Future<void> disconnect() async {
    try {
      await _connection?.close();
      _connection = null;
      _isConnected = false;
      _connectedDeviceName = '';
      print('Bluetooth отключен');
    } catch (e) {
      print('Ошибка отключения: $e');
    }
  }

  // Отправить команду на Arduino
  static Future<bool> sendCommand(String command) async {
    debugPrint('=== SEND COMMAND START ===');
    debugPrint('Connected: $_isConnected');
    debugPrint('Connection: ${_connection != null}');
    debugPrint('Command: $command');
    
    if (!_isConnected || _connection == null) {
      debugPrint('❌ НЕТ ПОДКЛЮЧЕНИЯ К BLUETOOTH');
      return false;
    }

    try {
      debugPrint('📤 Отправка команды: $command');
      
      final data = utf8.encode(command + '\n');
      debugPrint('Encoded data: $data');
      
      _connection!.output.add(Uint8List.fromList(data));
      await _connection!.output.allSent;
      
      debugPrint('✅ КОМАНДА ОТПРАВЛЕНА: $command');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ОШИБКА ОТПРАВКИ: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  // Управление светодиодами (1-4)
  static Future<bool> controlLed(int ledNumber, bool state) async {
    debugPrint('🔦 ===== CONTROL LED START =====');
    debugPrint('LED Number: $ledNumber');
    debugPrint('State: ${state ? "ON" : "OFF"}');
    
    final command = 'LED${ledNumber}_${state ? "ON" : "OFF"}';
    debugPrint('Command string: $command');
    
    final result = await sendCommand(command);
    debugPrint('Result: $result');
    debugPrint('🔦 ===== CONTROL LED END =====');
    
    return result;
  }

  // Управление баззерами (1-3)
  static Future<bool> controlBuzzer(int buzzerNumber, bool state) async {
    print('🔔 Попытка управления BUZZER$buzzerNumber: ${state ? "ON" : "OFF"}');
    final command = 'BUZZER${buzzerNumber}_${state ? "ON" : "OFF"}';
    return await sendCommand(command);
  }

  // Управление серво моторами (1-2)
  static Future<bool> controlServo(int servoNumber, int angle) async {
    print('🎛️ Попытка управления SERVO$servoNumber: $angle°');
    final command = 'SERVO${servoNumber}_$angle';
    return await sendCommand(command);
  }

  // Получить данные с ультразвуковых датчиков
  static Future<Map<String, double>?> getSensorData() async {
    if (!_isConnected || _connection == null) {
      return null;
    }

    try {
      await sendCommand('GET_SENSORS');
      
      return {
        'S0': 0.0,
        'S1': 0.0,
        'S2': 0.0,
      };
    } catch (e) {
      print('Ошибка чтения данных: $e');
      return null;
    }
  }

  // Экстренная остановка всей системы
  static Future<bool> emergencyStop() async {
    return await sendCommand('EMERGENCY_STOP');
  }

  // Включить/выключить систему охраны
  static Future<bool> toggleSecurity(bool enable) async {
    final command = enable ? 'SECURITY_ON' : 'SECURITY_OFF';
    return await sendCommand(command);
  }

  // Установить дистанцию обнаружения
  static Future<bool> setDetectionDistance(int distance) async {
    final command = 'DISTANCE_$distance';
    return await sendCommand(command);
  }

  // Сбросить тревогу
  static Future<bool> resetAlarm() async {
    return await sendCommand('RESET_ALARM');
  }

  // Получить статус системы
  static Future<bool> getStatus() async {
    return await sendCommand('GET_STATUS');
  }
}