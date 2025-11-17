import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class ServoControl extends StatefulWidget {
  const ServoControl({Key? key}) : super(key: key);

  @override
  State<ServoControl> createState() => _ServoControlState();
}

class _ServoControlState extends State<ServoControl> {
  double _servo1Angle = 90;
  double _servo2Angle = 90;
  bool _isLoading = false;

  Future<void> _setServoAngle(int servoNumber, double angle) async {
    setState(() => _isLoading = true);

    final success = await BluetoothService.controlServo(
      servoNumber,
      angle.round(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          if (servoNumber == 1) {
            _servo1Angle = angle;
          } else {
            _servo2Angle = angle;
          }
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servo $servoNumber: ${angle.round()}°'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  Widget _buildServoControl(
    String title,
    int servoNumber,
    double currentAngle,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_input_component,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${currentAngle.round()}°',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: currentAngle,
                    min: 0,
                    max: 180,
                    divisions: 18,
                    label: '${currentAngle.round()}°',
                    activeColor: color,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              if (servoNumber == 1) {
                                _servo1Angle = value;
                              } else {
                                _servo2Angle = value;
                              }
                            });
                          },
                    onChangeEnd: (value) {
                      _setServoAngle(servoNumber, value);
                    },
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPresetButton('0°', 0, servoNumber, color),
                _buildPresetButton('90°', 90, servoNumber, color),
                _buildPresetButton('180°', 180, servoNumber, color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(
    String label,
    double angle,
    int servoNumber,
    Color color,
  ) {
    return OutlinedButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                if (servoNumber == 1) {
                  _servo1Angle = angle;
                } else {
                  _servo2Angle = angle;
                }
              });
              _setServoAngle(servoNumber, angle);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(label),
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
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.door_sliding,
                    color: Colors.purple,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                const Text(
                  'Управление дверями',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildServoControl('Дверь 1', 1, _servo1Angle, Colors.purple),
            const SizedBox(height: 15),
            _buildServoControl('Дверь 2', 2, _servo2Angle, Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}