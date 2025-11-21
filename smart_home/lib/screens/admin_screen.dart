// lib/screens/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/user_model.dart';  // User class
import '../services/auth_service.dart';  // AuthService
import '../services/bluetooth_service.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  User? _currentUser;
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  List<User> _managedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCurrentUser();
    await _loadManagedUsers();
    await _loadDevices();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _currentUser = user);
  }

  Future<void> _loadManagedUsers() async {
    // Загружаем пользователей из AuthService (с сохранёнными правами)
    final users = AuthService.getManagedUsers();
    setState(() => _managedUsers = users);
  }

  Future<void> _loadDevices() async {
    setState(() => _isScanning = true);
    final devices = await BluetoothService.getPairedDevices();
    setState(() {
      _devices = devices;
      _isScanning = false;
    });
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 10),
            Text('Bluetooth устройства'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isScanning
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : _devices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Нет сопряженных устройств.\n\nВыполните сопряжение с HC-06 в настройках Bluetooth.', textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      itemBuilder: (_, i) {
                        final device = _devices[i];
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(device.name ?? 'Неизвестно'),
                          subtitle: Text(device.address),
                          trailing: (device.name?.contains('HC-06') == true || device.name?.contains('HC-05') == true)
                              ? const Icon(Icons.verified, color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _connectToDevice(device);
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _loadDevices(); }, child: const Text('Обновить')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final success = await BluetoothService.connect(device);

    if (mounted) {
      Navigator.pop(context);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✓ Подключено к ${device.name}' : 'Ошибка подключения'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _disconnect() async {
    await BluetoothService.disconnect();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth отключен'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _emergencyStop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Экстренная остановка'),
        content: const Text('Выключить ВСЕ устройства системы?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ОСТАНОВИТЬ ВСЁ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await BluetoothService.emergencyStop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '✓ Система остановлена' : 'Команда в очереди'),
          backgroundColor: success ? Colors.green : Colors.orange,
        ));
      }
    }
  }

  Future<void> _logout() async {
    await BluetoothService.disconnect();
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  /// ===== ПЕРЕКЛЮЧЕНИЕ ПРАВ С СОХРАНЕНИЕМ =====
  Future<void> _togglePermission(User user, String permission) async {
    // Вызываем AuthService - он переключит и СОХРАНИТ в SharedPreferences
    await AuthService.togglePermission(user.name, permission);

    // Перезагружаем список пользователей
    await _loadManagedUsers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Права ${user.name} обновлены и сохранены'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _resetAllPermissions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить все права?'),
        content: const Text('Права всех пользователей будут сброшены к начальным настройкам.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сбросить')),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.resetPermissions();
      await _loadManagedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Права сброшены'), backgroundColor: Colors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isConnected = BluetoothService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: isConnected ? Colors.white : Colors.red.shade200),
            onPressed: isConnected ? _disconnect : _showBluetoothDialog,
          ),
          IconButton(icon: const Icon(Icons.settings_bluetooth), onPressed: _showBluetoothDialog),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade700, Colors.grey.shade100],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Статус подключения
              Card(
                child: ListTile(
                  leading: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                  title: Text(isConnected ? 'Подключено' : 'Офлайн режим'),
                  subtitle: Text(isConnected ? BluetoothService.connectedDeviceName : 'Команды будут отправлены при подключении'),
                  trailing: isConnected
                      ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _disconnect)
                      : TextButton(onPressed: _showBluetoothDialog, child: const Text('Подключить')),
                ),
              ),
              const SizedBox(height: 16),

              // Экстренная остановка
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.red.shade200, width: 2)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.emergency, color: Colors.red, size: 30),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Экстренная остановка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Отключить все устройства', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _emergencyStop,
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('ОСТАНОВИТЬ ВСЁ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Заголовок управления правами
              Row(
                children: [
                  const Text('Управление правами доступа', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetAllPermissions,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Сбросить'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Карточки пользователей
              ..._managedUsers.map((user) => _buildUserCard(user)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getUserColor(user.name),
          child: Text(user.name.length > 4 ? user.name[4] : user.name[0],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(_getUserDescription(user), style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPermissionSwitch(user, 'Ультразвуковые датчики (3 шт)', 'sensors', user.canControlSensors, Icons.sensors, Colors.teal),
                _buildPermissionSwitch(user, 'Светодиоды (4 шт)', 'leds', user.canControlLeds, Icons.lightbulb_outline, Colors.amber),
                _buildPermissionSwitch(user, 'Баззеры (4 шт)', 'buzzers', user.canControlBuzzers, Icons.volume_up, Colors.orange),
                _buildPermissionSwitch(user, 'Серво моторы (2 шт)', 'servos', user.canControlServos, Icons.settings_input_component, Colors.indigo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSwitch(User user, String title, String permission, bool value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Switch(
            value: value,
            onChanged: (_) => _togglePermission(user, permission),
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Color _getUserColor(String name) {
    switch (name) {
      case 'UserA': return Colors.blue;
      case 'UserB': return Colors.green;
      case 'UserC': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getUserDescription(User user) {
    final p = <String>[];
    if (user.canControlSensors) p.add('Датчики');
    if (user.canControlLeds) p.add('LED');
    if (user.canControlBuzzers) p.add('Звук');
    if (user.canControlServos) p.add('Серво');
    if (p.isEmpty) return 'Нет доступа';
    if (p.length == 4) return 'Полный доступ';
    return p.join(', ');
  }
}