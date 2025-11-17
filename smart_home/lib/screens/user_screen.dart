import 'package:flutter/material.dart';
import 'dart:async';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import '../widgets/led_control.dart';
import '../widgets/buzzer_control.dart';
import '../widgets/servo_control.dart';
import '../widgets/sensor_display.dart';
import 'login_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  String _userName = '';
  bool _isBluetoothConnected = false;
  bool _isAlarmActive = false;
  StreamSubscription? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkBluetoothConnection();
    _listenToAlerts();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  // Слушаем тревоги от Arduino
  void _listenToAlerts() {
    _alertSubscription = BluetoothService.alertStream.listen((alert) {
      if (mounted) {
        setState(() {
          _isAlarmActive = true;
        });
        
        // Показываем диалог тревоги
        _showAlarmDialog(alert);
      }
    });
  }

  void _showAlarmDialog(String alertType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 40),
            const SizedBox(width: 10),
            const Text(
              '🚨 ТРЕВОГА!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Обнаружено движение!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              alertType.replaceAll('_', ' '),
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await BluetoothService.sendCommand('RESET_ALARM');
              setState(() {
                _isAlarmActive = false;
              });
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Сбросить тревогу'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _userName = user?.name ?? 'User';
      });
    }
  }

  void _checkBluetoothConnection() {
    setState(() {
      _isBluetoothConnected = BluetoothService.isConnected;
    });
  }

  Future<void> _connectToBluetooth() async {
    // Показываем диалог с доступными устройствами
    final devices = await BluetoothService.getPairedDevices();
    
    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Нет сопряженных Bluetooth устройств'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Показываем список устройств
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Выберите устройство HC-06',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...devices.map((device) => Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name ?? 'Неизвестное устройство'),
                subtitle: Text(device.address),
                trailing: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _performConnection(device);
                  },
                  child: const Text('Подключить'),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _performConnection(device) async {
    // Показываем загрузку
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await BluetoothService.connect(device);

    if (mounted) {
      Navigator.pop(context); // Закрываем загрузку

      if (success) {
        setState(() {
          _isBluetoothConnected = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Подключено к HC-06!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Не удалось подключиться'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectBluetooth() async {
    await BluetoothService.disconnect();
    setState(() {
      _isBluetoothConnected = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth отключен'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Привет, $_userName'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // КНОПКА BLUETOOTH
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _isBluetoothConnected 
                    ? Icons.bluetooth_connected 
                    : Icons.bluetooth_disabled,
                color: _isBluetoothConnected 
                    ? Colors.greenAccent 
                    : Colors.white,
              ),
              onPressed: _isBluetoothConnected 
                  ? _disconnectBluetooth 
                  : _connectToBluetooth,
              tooltip: _isBluetoothConnected 
                  ? 'Отключить Bluetooth' 
                  : 'Подключить Bluetooth',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.grey.shade100,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
                            child: _isBluetoothConnected
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Индикатор тревоги
                      if (_isAlarmActive)
                        Card(
                          color: Colors.red.shade100,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 40),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🚨 АКТИВНА ТРЕВОГА!',
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Обнаружено движение',
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await BluetoothService.sendCommand('RESET_ALARM');
                                    setState(() {
                                      _isAlarmActive = false;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('Сбросить'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Индикатор подключения
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Подключено к ${BluetoothService.connectedDeviceName}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Управление светодиодами
                      const LedControl(),
                      const SizedBox(height: 16),
                      
                      // Управление баззерами
                      const BuzzerControl(),
                      const SizedBox(height: 16),
                      
                      // Управление серво
                      const ServoControl(),
                      const SizedBox(height: 16),
                      
                      // Датчики
                      const SensorDisplay(),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 100,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Bluetooth не подключен',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Нажмите на иконку Bluetooth вверху\nчтобы подключиться к HC-06',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _connectToBluetooth,
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Подключить Bluetooth'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}