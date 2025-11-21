// lib/screens/user_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  User? _user;
  bool _isBluetoothConnected = false;
  bool _isAlarmActive = false;
  
  StreamSubscription? _alertSubscription;
  StreamSubscription? _sensorSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _fullStatusSubscription;

  // Состояния устройств (синхронизируются с Arduino)
  List<bool> _ledStates = [false, false, false, false];
  List<bool> _buzzerStates = [false, false, false];
  List<int> _servoAngles = [90, 90];
  List<bool> _sensorsEnabled = [true, true, true];
  Map<String, double> _sensorData = {'S0': 0, 'S1': 0, 'S2': 0};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkBluetoothConnection();
    _setupListeners();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _sensorSubscription?.cancel();
    _stateSubscription?.cancel();
    _fullStatusSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    // Данные сенсоров
    _sensorSubscription = BluetoothService.sensorDataStream.listen((data) {
      if (mounted) setState(() => _sensorData = data);
    });

    // Тревоги
    _alertSubscription = BluetoothService.alertStream.listen((alert) {
      if (mounted) {
        setState(() => _isAlarmActive = true);
        _showAlarmDialog(alert);
      }
    });

    // Обновления состояния отдельных устройств
    _stateSubscription = BluetoothService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        switch (state.type) {
          case 'led':
            if (state.index < 4) _ledStates[state.index] = state.value == 1;
            break;
          case 'buzzer':
            if (state.index < 3) _buzzerStates[state.index] = state.value == 1;
            break;
          case 'servo':
            if (state.index < 2) _servoAngles[state.index] = state.value;
            break;
          case 'sensor_enable':
            if (state.index < 3) _sensorsEnabled[state.index] = state.value == 1;
            break;
        }
      });
    });

    // Полный статус
    _fullStatusSubscription = BluetoothService.fullStatusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _ledStates = List.from(status.leds);
        _buzzerStates = List.from(status.buzzers);
        _servoAngles = List.from(status.servos);
        _sensorsEnabled = List.from(status.sensorsEnabled);
        _isAlarmActive = status.alarmActive;
      });
    });
  }

  void _showAlarmDialog(String alertType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 40),
            const SizedBox(width: 10),
            const Text('🚨 ТРЕВОГА!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Обнаружено движение!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Датчик: ${alertType.replaceAll('MOTION_', '')}', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await BluetoothService.resetAlarm();
              setState(() => _isAlarmActive = false);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.check),
            label: const Text('Сбросить тревогу'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) setState(() => _user = user);
  }

  void _checkBluetoothConnection() {
    setState(() => _isBluetoothConnected = BluetoothService.isConnected);
    // Если подключены - запрашиваем статус
    if (_isBluetoothConnected) {
      BluetoothService.getStatus();
    }
  }

  Future<void> _connectToBluetooth() async {
    final devices = await BluetoothService.getPairedDevices();
    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Нет сопряженных устройств'), backgroundColor: Colors.red));
      }
      return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выберите устройство', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...devices.map((device) => Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name ?? 'Неизвестное'),
                subtitle: Text(device.address),
                trailing: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _performConnection(device);
                  },
                  child: const Text('Подключить'),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _performConnection(device) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final success = await BluetoothService.connect(device);
    if (mounted) {
      Navigator.pop(context);
      setState(() => _isBluetoothConnected = success);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Подключено!' : '❌ Ошибка'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _disconnectBluetooth() async {
    await BluetoothService.disconnect();
    setState(() => _isBluetoothConnected = false);
  }

  Future<void> _logout() async {
    // НЕ отключаем Bluetooth при выходе!
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // === УПРАВЛЕНИЕ ===
  Future<void> _toggleLed(int i, bool v) async {
    setState(() => _ledStates[i] = v);
    await BluetoothService.controlLed(i + 1, v);
  }

  Future<void> _toggleBuzzer(int i, bool v) async {
    setState(() => _buzzerStates[i] = v);
    await BluetoothService.controlBuzzer(i + 1, v);
  }

  Future<void> _setServo(int i, int angle) async {
    setState(() => _servoAngles[i] = angle);
    await BluetoothService.controlServo(i + 1, angle);
  }

  Future<void> _toggleSensor(int i, bool v) async {
    setState(() => _sensorsEnabled[i] = v);
    await BluetoothService.controlSensor(i, v);
  }

  // === ГРУППОВЫЕ ===
  Future<void> _allLedsOn() async {
    setState(() => _ledStates = [true, true, true, true]);
    await BluetoothService.sendCommand('ALL_LED_ON');
  }
  Future<void> _allLedsOff() async {
    setState(() => _ledStates = [false, false, false, false]);
    await BluetoothService.sendCommand('ALL_LED_OFF');
  }
  Future<void> _allBuzzersOn() async {
    setState(() => _buzzerStates = [true, true, true]);
    await BluetoothService.sendCommand('ALL_BUZZER_ON');
  }
  Future<void> _allBuzzersOff() async {
    setState(() => _buzzerStates = [false, false, false]);
    await BluetoothService.sendCommand('ALL_BUZZER_OFF');
  }
  Future<void> _allServosClose() async {
    setState(() => _servoAngles = [0, 0]);
    await BluetoothService.sendCommand('ALL_SERVO_CLOSE');
  }
  Future<void> _allServosOpen() async {
    setState(() => _servoAngles = [90, 90]);
    await BluetoothService.sendCommand('ALL_SERVO_OPEN');
  }
  Future<void> _allSensorsOn() async {
    setState(() => _sensorsEnabled = [true, true, true]);
    await BluetoothService.sendCommand('ALL_SENSOR_ON');
  }
  Future<void> _allSensorsOff() async {
    setState(() => _sensorsEnabled = [false, false, false]);
    await BluetoothService.sendCommand('ALL_SENSOR_OFF');
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Привет, ${_user!.name}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isBluetoothConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: _isBluetoothConnected ? Colors.greenAccent : Colors.white),
            onPressed: _isBluetoothConnected ? _disconnectBluetooth : _connectToBluetooth,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.grey.shade100],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildConnectionStatus(),
                if (_isAlarmActive) _buildAlarmCard(),
                if (_user!.canControlLeds) _buildLedSection(),
                if (_user!.canControlBuzzers) _buildBuzzerSection(),
                if (_user!.canControlServos) _buildServoSection(),
                if (_user!.canControlSensors) _buildSensorSection(),
                if (!_user!.canControlLeds && !_user!.canControlBuzzers && 
                    !_user!.canControlServos && !_user!.canControlSensors)
                  _buildNoAccessCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      color: _isBluetoothConnected ? Colors.green.shade50 : Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_isBluetoothConnected ? Icons.check_circle : Icons.warning,
                color: _isBluetoothConnected ? Colors.green.shade700 : Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _isBluetoothConnected ? 'Подключено к ${BluetoothService.connectedDeviceName}' : 'Офлайн режим',
              style: TextStyle(color: _isBluetoothConnected ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold),
            )),
            if (_isBluetoothConnected)
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => BluetoothService.getStatus(), tooltip: 'Обновить'),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmCard() {
    return Card(
      color: Colors.red.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 40),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚨 ТРЕВОГА!', style: TextStyle(color: Colors.red.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Обнаружено движение', style: TextStyle(color: Colors.red.shade700)),
              ],
            )),
            ElevatedButton(
              onPressed: () async {
                await BluetoothService.resetAlarm();
                setState(() => _isAlarmActive = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Сбросить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text('Светодиоды', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _allLedsOn, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text('Все ВКЛ', style: TextStyle(color: Colors.white)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _allLedsOff, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('Все ВЫКЛ', style: TextStyle(color: Colors.white)))),
            ]),
            ...List.generate(4, (i) => SwitchListTile(
              title: Text('LED ${i + 1}'),
              value: _ledStates[i],
              onChanged: (v) => _toggleLed(i, v),
              activeColor: Colors.amber,
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBuzzerSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.volume_up, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Баззеры', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _allBuzzersOn, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Все ВКЛ', style: TextStyle(color: Colors.white)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _allBuzzersOff, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('Все ВЫКЛ', style: TextStyle(color: Colors.white)))),
            ]),
            ...List.generate(3, (i) => SwitchListTile(
              title: Text('Баззер ${i + 1}'),
              value: _buzzerStates[i],
              onChanged: (v) => _toggleBuzzer(i, v),
              activeColor: Colors.orange,
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildServoSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.door_sliding, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text('Двери (Серво)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _allServosOpen, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Открыть все', style: TextStyle(color: Colors.white)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _allServosClose, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Закрыть все', style: TextStyle(color: Colors.white)))),
            ]),
            const SizedBox(height: 8),
            ...List.generate(2, (i) => Column(children: [
              Row(children: [
                Text('Дверь ${i + 1}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Icon(_servoAngles[i] < 45 ? Icons.lock : Icons.lock_open, color: _servoAngles[i] < 45 ? Colors.red : Colors.green, size: 20),
                Text(_servoAngles[i] < 45 ? ' Закрыта' : ' Открыта'),
              ]),
              Slider(value: _servoAngles[i].toDouble(), min: 0, max: 180, divisions: 18, label: '${_servoAngles[i]}°', onChanged: (v) => _setServo(i, v.toInt())),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.sensors, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Text('Датчики движения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => BluetoothService.sendCommand('GET_SENSORS')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _allSensorsOn, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('Все ВКЛ', style: TextStyle(color: Colors.white)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _allSensorsOff, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('Все ВЫКЛ', style: TextStyle(color: Colors.white)))),
            ]),
            const SizedBox(height: 8),
            ...List.generate(3, (i) {
              final dist = _sensorData['S$i'] ?? 0;
              final isClose = dist > 0 && dist < 30;
              return Card(
                color: !_sensorsEnabled[i] ? Colors.grey.shade200 : (isClose ? Colors.red.shade50 : Colors.green.shade50),
                child: ListTile(
                  leading: Icon(_sensorsEnabled[i] ? (isClose ? Icons.warning : Icons.check_circle) : Icons.sensors_off,
                      color: !_sensorsEnabled[i] ? Colors.grey : (isClose ? Colors.red : Colors.green)),
                  title: Text('Датчик ${i + 1}'),
                  subtitle: Text(_sensorsEnabled[i] ? '${dist.toStringAsFixed(1)} см' : 'Выключен'),
                  trailing: Switch(value: _sensorsEnabled[i], onChanged: (v) => _toggleSensor(i, v), activeColor: Colors.teal),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccessCard() {
    return Card(
      color: Colors.grey.shade200,
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.lock, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('Нет доступа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Обратитесь к администратору'),
        ]),
      ),
    );
  }
}