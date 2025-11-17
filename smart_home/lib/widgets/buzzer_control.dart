import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class BuzzerControl extends StatefulWidget {
  const BuzzerControl({Key? key}) : super(key: key);

  @override
  State<BuzzerControl> createState() => _BuzzerControlState();
}

class _BuzzerControlState extends State<BuzzerControl> {
  bool _buzzer1On = false;
  bool _buzzer2On = false;
  bool _buzzer3On = false;
  bool _isLoading = false;

  Future<void> _toggleBuzzer(int buzzerNumber, bool turnOn) async {
    setState(() => _isLoading = true);

    final success = await BluetoothService.controlBuzzer(buzzerNumber, turnOn);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          switch (buzzerNumber) {
            case 1:
              _buzzer1On = turnOn;
              break;
            case 2:
              _buzzer2On = turnOn;
              break;
            case 3:
              _buzzer3On = turnOn;
              break;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Buzzer $buzzerNumber ${turnOn ? "включен" : "выключен"}'
                : 'Ошибка управления Buzzer',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildBuzzerSwitch(int buzzerNumber, bool isOn, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOn ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volume_up,
                color: isOn ? color : Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buzzer $buzzerNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isOn ? 'Включен' : 'Выключен',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              onChanged: _isLoading
                  ? null
                  : (value) => _toggleBuzzer(buzzerNumber, value),
              activeColor: color,
            ),
          ],
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.orange,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                const Text(
                  'Управление сигнализацией',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBuzzerSwitch(1, _buzzer1On, Colors.orange),
            const SizedBox(height: 10),
            _buildBuzzerSwitch(2, _buzzer2On, Colors.deepOrange),
            const SizedBox(height: 10),
            _buildBuzzerSwitch(3, _buzzer3On, Colors.red),
          ],
        ),
      ),
    );
  }
}