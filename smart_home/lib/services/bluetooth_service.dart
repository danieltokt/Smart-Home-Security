// lib/services/bluetooth_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  static BluetoothConnection? _connection;
  static bool _isConnected = false;
  static String _connectedDeviceName = '';

  // Буфер для сборки входящих данных
  static String _inputBuffer = '';

  // Очередь команд (offline режим)
  static final List<String> _pendingCommands = [];

  // Stream controllers
  static final _sensorDataController = StreamController<Map<String, double>>.broadcast();
  static final _alertController = StreamController<String>.broadcast();
  static final _stateController = StreamController<DeviceState>.broadcast();
  static final _fullStatusController = StreamController<FullStatus>.broadcast();

  static bool get isConnected => _isConnected;
  static String get connectedDeviceName => _connectedDeviceName;

  static Stream<Map<String, double>> get sensorDataStream => _sensorDataController.stream;
  static Stream<String> get alertStream => _alertController.stream;
  static Stream<DeviceState> get stateStream => _stateController.stream;
  static Stream<FullStatus> get fullStatusStream => _fullStatusController.stream;

  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print('Ошибка получения BT устройств: $e');
      return [];
    }
  }

  static Future<bool> connect(BluetoothDevice device) async {
    try {
      print('Попытка подключения к ${device.name}...');
      await disconnect();

      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      _connectedDeviceName = device.name ?? 'HC-06';
      _inputBuffer = ''; // Очищаем буфер

      print('✅ Подключено к ${device.name}');

      // Слушаем данные от Arduino С БУФЕРИЗАЦИЕЙ
      _connection!.input!.listen((Uint8List data) {
        String chunk = utf8.decode(data);
        _inputBuffer += chunk;
        
        // Обрабатываем все полные строки (до \n)
        while (_inputBuffer.contains('\n')) {
          int idx = _inputBuffer.indexOf('\n');
          String line = _inputBuffer.substring(0, idx).trim();
          _inputBuffer = _inputBuffer.substring(idx + 1);
          
          if (line.isNotEmpty) {
            print("📩 RX: $line");
            _parseMessage(line);
          }
        }
      }).onDone(() {
        _isConnected = false;
        _inputBuffer = '';
        print("❌ Соединение разорвано");
      });

      // Отправляем накопленные команды
      if (_pendingCommands.isNotEmpty) _flushPending();

      // Ждём стабилизации и запрашиваем статус
      await Future.delayed(const Duration(milliseconds: 1000));
      sendCommand('GET_STATUS');

      return true;
    } catch (e) {
      print("Ошибка подключения: $e");
      _isConnected = false;
      return false;
    }
  }

  static void _parseMessage(String message) {
    if (message.startsWith("SENSORS:")) {
      _parseSensorData(message);
    } else if (message.startsWith("ALERT:")) {
      _alertController.add(message.replaceAll("ALERT:", ""));
    } else if (message.startsWith("STATE:")) {
      _parseStateUpdate(message);
    } else if (message.startsWith("FULLSTATUS:")) {
      _parseFullStatus(message);
    } else if (message.startsWith("STATUS:ALARM_RESET")) {
      sendCommand('GET_STATUS');
    }
    // Игнорируем OK, READY и другие служебные сообщения
  }

  static void _parseStateUpdate(String msg) {
    final body = msg.replaceAll("STATE:", "");
    
    if (body.startsWith("LED")) {
      final match = RegExp(r'LED(\d)_(ON|OFF)').firstMatch(body);
      if (match != null) {
        int idx = int.parse(match.group(1)!) - 1;
        bool state = match.group(2) == 'ON';
        _stateController.add(DeviceState(type: 'led', index: idx, value: state ? 1 : 0));
      }
    } else if (body.startsWith("BUZZER")) {
      final match = RegExp(r'BUZZER(\d)_(ON|OFF)').firstMatch(body);
      if (match != null) {
        int idx = int.parse(match.group(1)!) - 1;
        bool state = match.group(2) == 'ON';
        _stateController.add(DeviceState(type: 'buzzer', index: idx, value: state ? 1 : 0));
      }
    } else if (body.startsWith("SERVO")) {
      final match = RegExp(r'SERVO(\d)_(\d+)').firstMatch(body);
      if (match != null) {
        int idx = int.parse(match.group(1)!) - 1;
        int angle = int.parse(match.group(2)!);
        _stateController.add(DeviceState(type: 'servo', index: idx, value: angle));
      }
    } else if (body.startsWith("SENSOR")) {
      final match = RegExp(r'SENSOR(\d)_(ON|OFF)').firstMatch(body);
      if (match != null) {
        int idx = int.parse(match.group(1)!);
        bool state = match.group(2) == 'ON';
        _stateController.add(DeviceState(type: 'sensor_enable', index: idx, value: state ? 1 : 0));
      }
    } else if (body.startsWith("ALL_SENSOR")) {
      bool state = body.contains("ON");
      for (int i = 0; i < 3; i++) {
        _stateController.add(DeviceState(type: 'sensor_enable', index: i, value: state ? 1 : 0));
      }
    }
  }

  static void _parseFullStatus(String msg) {
    try {
      final body = msg.replaceAll("FULLSTATUS:", "");
      final parts = body.split(",");
      
      FullStatus status = FullStatus();
      
      for (int i = 0; i < parts.length; i++) {
        var part = parts[i];
        if (part.startsWith("LED:")) {
          String ledStr = part.substring(4);
          for (int j = 0; j < ledStr.length && j < 4; j++) {
            status.leds[j] = ledStr[j] == '1';
          }
        } else if (part.startsWith("BUZ:")) {
          String buzStr = part.substring(4);
          for (int j = 0; j < buzStr.length && j < 3; j++) {
            status.buzzers[j] = buzStr[j] == '1';
          }
        } else if (part.startsWith("SRV:")) {
          status.servos[0] = int.tryParse(part.substring(4)) ?? 90;
        } else if (part.startsWith("SNS:")) {
          String snsStr = part.substring(4);
          for (int j = 0; j < snsStr.length && j < 3; j++) {
            status.sensorsEnabled[j] = snsStr[j] == '1';
          }
        } else if (part.startsWith("SEC:")) {
          status.securityEnabled = part.substring(4) == '1';
        } else if (part.startsWith("ALM:")) {
          status.alarmActive = part.substring(4) == '1';
        } else {
          // Может быть второй угол серво
          int? angle = int.tryParse(part);
          if (angle != null && status.servos[1] == 90) {
            status.servos[1] = angle;
          }
        }
      }
      
      _fullStatusController.add(status);
      print("📊 Полный статус: LED=${status.leds}, BUZ=${status.buzzers}, SRV=${status.servos}, SNS=${status.sensorsEnabled}");
    } catch (e) {
      print("Ошибка парсинга статуса: $e");
    }
  }

  static Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    _isConnected = false;
    _connectedDeviceName = '';
    _inputBuffer = '';
  }

  static Future<bool> sendCommand(String command) async {
    print("➡ SEND: $command");

    if (!_isConnected || _connection == null) {
      print("⚠ Офлайн, в очередь: $command");
      _pendingCommands.add(command);
      return false;
    }

    try {
      final data = utf8.encode(command + "\n");
      _connection!.output.add(Uint8List.fromList(data));
      await _connection!.output.allSent;
      print("✅ Отправлено: $command");
      return true;
    } catch (e) {
      print("❌ Ошибка: $command");
      _pendingCommands.add(command);
      return false;
    }
  }

  static void _flushPending() {
    print("📤 Очередь: ${_pendingCommands.length}");
    for (final cmd in _pendingCommands) {
      try {
        final data = utf8.encode(cmd + "\n");
        _connection!.output.add(Uint8List.fromList(data));
      } catch (_) {}
    }
    _pendingCommands.clear();
  }

  static void _parseSensorData(String input) {
    try {
      final body = input.replaceAll("SENSORS:", "");
      final parts = body.split(",");
      Map<String, double> out = {};

      for (var p in parts) {
        if (p.contains(":")) {
          final item = p.split(":");
          if (item.length == 2 && item[0].startsWith("S")) {
            out[item[0]] = double.tryParse(item[1]) ?? 0.0;
          }
        }
      }
      if (out.isNotEmpty) {
        _sensorDataController.add(out);
      }
    } catch (e) {
      print("Ошибка разбора датчиков: $e");
    }
  }

  // === API ===
  static Future<bool> controlLed(int id, bool state) =>
      sendCommand("LED${id}_${state ? 'ON' : 'OFF'}");

  static Future<bool> controlBuzzer(int id, bool state) =>
      sendCommand("BUZZER${id}_${state ? 'ON' : 'OFF'}");

  static Future<bool> controlServo(int id, int angle) =>
      sendCommand("SERVO${id}_$angle");

  // Индекс 0-based для сенсоров
  static Future<bool> controlSensor(int id, bool enabled) =>
      sendCommand("SENSOR${id}_${enabled ? 'ON' : 'OFF'}");

  static Future<bool> resetAlarm() => sendCommand("RESET_ALARM");
  static Future<bool> getStatus() => sendCommand("GET_STATUS");
  
  // Включить/выключить систему охраны
  static Future<bool> toggleSecurity(bool active) =>
      sendCommand(active ? "SECURITY_ON" : "SECURITY_OFF");
  
  // Экстренная остановка (теперь просто сброс тревоги)
  static Future<bool> emergencyStop() => sendCommand("RESET_ALARM");
}

class DeviceState {
  final String type;
  final int index;
  final int value;
  DeviceState({required this.type, required this.index, required this.value});
}

class FullStatus {
  List<bool> leds = [false, false, false, false];
  List<bool> buzzers = [false, false, false];
  List<int> servos = [90, 90];
  List<bool> sensorsEnabled = [true, true, true];
  bool securityEnabled = true;
  bool alarmActive = false;
}