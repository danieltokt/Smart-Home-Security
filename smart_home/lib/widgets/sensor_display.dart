import 'package:flutter/material.dart';
import 'dart:async';
import '../services/bluetooth_service.dart';

class SensorDisplay extends StatefulWidget {
  const SensorDisplay({Key? key}) : super(key: key);

  @override
  State<SensorDisplay> createState() => _SensorDisplayState();
}

class _SensorDisplayState extends State<SensorDisplay> {
  double _sensor0 = 0.0;
  double _sensor1 = 0.0;
  double _sensor2 = 0.0;
  bool _isLoading = true;
  bool _isMonitoring = true;
  Timer? _timer;
  StreamSubscription? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
    _listenToSensorData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  // Слушаем данные от Arduino
  void _listenToSensorData() {
    _sensorSubscription = BluetoothService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _sensor0 = data['S0'] ?? _sensor0;
          _sensor1 = data['S1'] ?? _sensor1;
          _sensor2 = data['S2'] ?? _sensor2;
          _isLoading = false;
        });
        print('📊 Датчики обновлены: S0=$_sensor0, S1=$_sensor1, S2=$_sensor2');
      }
    });
  }

  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isMonitoring) {
        _fetchSensorData();
      }
    });
  }

  Future<void> _fetchSensorData() async {
    await BluetoothService.sendCommand('GET_SENSORS');
  }

  Future<void> _toggleMonitoring() async {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    // Отправляем команду управления системой безопасности
    await BluetoothService.toggleSecurity(_isMonitoring);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Мониторинг ${_isMonitoring ? "включен" : "выключен"}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildSensorCard(
    String title,
    double value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${value.toStringAsFixed(1)} см',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sensors,
                    color: Colors.teal,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text(
                    'Ультразвуковые датчики',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _isMonitoring,
                  onChanged: (_) => _toggleMonitoring(),
                  activeColor: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildSensorCard(
                  'Датчик 0',
                  _sensor0,
                  Icons.crop_square,
                  Colors.blue,
                ),
                const SizedBox(width: 10),
                _buildSensorCard(
                  'Датчик 1',
                  _sensor1,
                  Icons.crop_square,
                  Colors.green,
                ),
                const SizedBox(width: 10),
                _buildSensorCard(
                  'Датчик 2',
                  _sensor2,
                  Icons.crop_square,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}