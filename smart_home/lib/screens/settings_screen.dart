// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/bluetooth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localization = LocalizationService();
  double _detectionDistance = 30;
  bool _securityEnabled = true;

  @override
  void initState() {
    super.initState();
    _localization.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _localization.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setDistance(double value) async {
    setState(() => _detectionDistance = value);
    await BluetoothService.sendCommand('DISTANCE_${value.toInt()}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('detection_distance')}: ${value.toInt()} ${tr('cm')}'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _toggleSecurity(bool value) async {
    setState(() => _securityEnabled = value);
    await BluetoothService.toggleSecurity(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.grey.shade100],
            stops: const [0.0, 0.3],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === ЯЗЫК ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.language, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(tr('language'), 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLanguageButton(
                            'ru',
                            '🇷🇺 ${tr('russian')}',
                            _localization.isRussian,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLanguageButton(
                            'en',
                            '🇬🇧 ${tr('english')}',
                            _localization.isEnglish,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === ДИСТАНЦИЯ ОБНАРУЖЕНИЯ ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sensors, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(tr('detection_distance'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_detectionDistance.toInt()} ${tr('cm')}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    Slider(
                      value: _detectionDistance,
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: '${_detectionDistance.toInt()} ${tr('cm')}',
                      activeColor: Colors.teal,
                      onChanged: (v) => setState(() => _detectionDistance = v),
                      onChangeEnd: _setDistance,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('10 ${tr('cm')}', style: TextStyle(color: Colors.grey.shade600)),
                        Text('100 ${tr('cm')}', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Быстрые кнопки
                    Wrap(
                      spacing: 8,
                      children: [20, 30, 50, 70].map((d) => 
                        ActionChip(
                          label: Text('$d ${tr('cm')}'),
                          onPressed: () => _setDistance(d.toDouble()),
                          backgroundColor: _detectionDistance == d 
                              ? Colors.teal.shade100 
                              : null,
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === СИСТЕМА ОХРАНЫ ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('security_system'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Switch(
                          value: _securityEnabled,
                          onChanged: _toggleSecurity,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _securityEnabled 
                            ? Colors.green.shade50 
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _securityEnabled ? Icons.shield : Icons.shield_outlined,
                            color: _securityEnabled ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _securityEnabled 
                                ? (_localization.isRussian ? 'Охрана включена' : 'Security ON')
                                : (_localization.isRussian ? 'Охрана выключена' : 'Security OFF'),
                            style: TextStyle(
                              color: _securityEnabled ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === ИНФОРМАЦИЯ ===
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(_localization.isRussian ? 'О системе' : 'About',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      _localization.isRussian ? 'Версия' : 'Version', 
                      '1.0.0'
                    ),
                    _buildInfoRow(
                      _localization.isRussian ? 'Bluetooth' : 'Bluetooth', 
                      BluetoothService.isConnected 
                          ? BluetoothService.connectedDeviceName 
                          : (_localization.isRussian ? 'Не подключен' : 'Not connected')
                    ),
                    _buildInfoRow(
                      _localization.isRussian ? 'Компоненты' : 'Components', 
                      '4 LED, 3 Buzzer, 2 Servo, 3 Sensor'
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(String locale, String label, bool isSelected) {
    return ElevatedButton(
      onPressed: () => _localization.setLocale(locale),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected 
              ? BorderSide.none 
              : BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}