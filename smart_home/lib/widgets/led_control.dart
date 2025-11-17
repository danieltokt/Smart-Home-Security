import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class LedControl extends StatefulWidget {
  const LedControl({Key? key}) : super(key: key);

  @override
  State<LedControl> createState() => _LedControlState();
}

class _LedControlState extends State<LedControl> {
  bool _led1On = false;
  bool _led2On = false;
  bool _led3On = false;
  bool _led4On = false;
  bool _isLoading = false;

  Future<void> _toggleLed(int ledNumber, bool turnOn) async {
    setState(() => _isLoading = true);

    final success = await BluetoothService.controlLed(ledNumber, turnOn);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          switch (ledNumber) {
            case 1:
              _led1On = turnOn;
              break;
            case 2:
              _led2On = turnOn;
              break;
            case 3:
              _led3On = turnOn;
              break;
            case 4:
              _led4On = turnOn;
              break;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'LED $ledNumber ${turnOn ? "включен" : "выключен"}'
                : 'Ошибка управления LED',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildLedSwitch(int ledNumber, bool isOn, Color color) {
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
                Icons.lightbulb,
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
                    'LED $ledNumber',
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
                  : (value) => _toggleLed(ledNumber, value),
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
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                const Text(
                  'Управление освещением',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLedSwitch(1, _led1On, Colors.red),
            const SizedBox(height: 10),
            _buildLedSwitch(2, _led2On, Colors.green),
            const SizedBox(height: 10),
            _buildLedSwitch(3, _led3On, Colors.blue),
            const SizedBox(height: 10),
            _buildLedSwitch(4, _led4On, Colors.purple),
          ],
        ),
      ),
    );
  }
}