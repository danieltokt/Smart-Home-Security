import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
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
  late List<User> _managedUsers;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadDevices();
    _managedUsers = [
      User.userA,
      User.userB,
      User.userC,
    ];
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
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
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bluetooth, color: Colors.blue),
            const SizedBox(width: 10),
            const Text('Bluetooth устройства'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isScanning
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _devices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Нет сопряженных устройств.\n\n'
                        'Сначала выполните сопряжение с HC-06 в настройках Bluetooth.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(device.name ?? 'Неизвестно'),
                          subtitle: Text(device.address),
                          trailing: device.name?.contains('HC-06') == true ||
                                  device.name?.contains('HC-05') == true
                              ? const Icon(Icons.verified, color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            _connectToDevice(device);
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDevices();
            },
            child: const Text('Обновить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await BluetoothService.connect(device);
    
    if (mounted) {
      Navigator.pop(context); // Закрыть диалог загрузки

      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Подключено к ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка подключения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await BluetoothService.disconnect();
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth отключен'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _emergencyStop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Экстренная остановка'),
        content: const Text(
          'Выключить ВСЕ устройства системы?\n\n'
          '• Датчики\n'
          '• Светодиоды (4 шт)\n'
          '• Баззеры (3 шт)\n'
          '• Серво моторы (2 шт)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('ОСТАНОВИТЬ ВСЁ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await BluetoothService.emergencyStop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✓ Система остановлена' : 'Ошибка'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await BluetoothService.disconnect();
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _togglePermission(User user, String permission) {
    setState(() {
      switch (permission) {
        case 'sensors':
          user.canControlSensors = !user.canControlSensors;
          break;
        case 'servos':
          user.canControlServos = !user.canControlServos;
          break;
        case 'buzzers':
          user.canControlBuzzers = !user.canControlBuzzers;
          break;
        case 'leds':
          user.canControlLeds = !user.canControlLeds;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Права ${user.name} обновлены'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isConnected = BluetoothService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.white : Colors.red.shade200,
            ),
            onPressed: isConnected ? _disconnect : _showBluetoothDialog,
            tooltip: isConnected ? 'Отключить' : 'Подключить',
          ),
          IconButton(
            icon: const Icon(Icons.settings_bluetooth),
            onPressed: _showBluetoothDialog,
            tooltip: 'Настройки Bluetooth',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выход',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade700,
              Colors.grey.shade100,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: isConnected
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Статус подключения
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bluetooth_connected,
                            color: Colors.green,
                          ),
                        ),
                        title: const Text(
                          'Подключено',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(BluetoothService.connectedDeviceName),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _disconnect,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Кнопка экстренной остановки
                    Card(
                      elevation: 4,
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.red.shade200, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.emergency,
                                    color: Colors.red,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Экстренная остановка',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Отключить все устройства системы',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Управление правами
                    const Text(
                      'Управление правами доступа',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...(_managedUsers.map((user) => _buildUserCard(user)).toList()),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Нет подключения',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Подключитесь к HC-06',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _showBluetoothDialog,
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Подключить устройство'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getUserColor(user.name),
          child: Text(
            user.name[4], // A, B, C
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _getUserDescription(user),
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPermissionSwitch(
                  user,
                  'Ультразвуковые датчики (3 шт)',
                  'sensors',
                  user.canControlSensors,
                  Icons.sensors,
                  Colors.teal,
                ),
                _buildPermissionSwitch(
                  user,
                  'Светодиоды (4 шт)',
                  'leds',
                  user.canControlLeds,
                  Icons.lightbulb_outline,
                  Colors.amber,
                ),
                _buildPermissionSwitch(
                  user,
                  'Баззеры (3 шт)',
                  'buzzers',
                  user.canControlBuzzers,
                  Icons.volume_up,
                  Colors.orange,
                ),
                _buildPermissionSwitch(
                  user,
                  'Серво моторы (2 шт)',
                  'servos',
                  user.canControlServos,
                  Icons.settings_input_component,
                  Colors.indigo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSwitch(
    User user,
    String title,
    String permission,
    bool value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title),
          ),
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
      case 'UserA':
        return Colors.blue;
      case 'UserB':
        return Colors.green;
      case 'UserC':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getUserDescription(User user) {
    final permissions = <String>[];
    if (user.canControlSensors) permissions.add('Датчики');
    if (user.canControlLeds) permissions.add('LED');
    if (user.canControlBuzzers) permissions.add('Звук');
    if (user.canControlServos) permissions.add('Серво');

    if (permissions.isEmpty) return 'Нет доступа';
    if (permissions.length == 4) return 'Полный доступ';
    return permissions.join(', ');
  }
}