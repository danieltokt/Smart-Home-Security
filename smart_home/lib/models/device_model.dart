// lib/models/device_model.dart

class Sensor {
  final String id;
  final String name;
  final String location;
  double distance; // в см
  bool isTriggered; // если расстояние < порога

  Sensor({
    required this.id,
    required this.name,
    required this.location,
    this.distance = 0,
    this.isTriggered = false,
  });
}

class LED {
  final String id;
  final String name;
  final String location;
  bool status;

  LED({
    required this.id,
    required this.name,
    required this.location,
    this.status = false,
  });
}

class Buzzer {
  final String id;
  final String name;
  int frequency; // Hz
  bool status;

  Buzzer({
    required this.id,
    required this.name,
    this.frequency = 1000,
    this.status = false,
  });
}

class Servo {
  final String id;
  final String name;
  int angle; // 0-180 градусов

  Servo({
    required this.id,
    required this.name,
    this.angle = 90,
  });
}

// Заводские настройки устройств
class DeviceFactory {
  static List<Sensor> createSensors() {
    return [
      Sensor(
        id: 'S0',
        name: 'Сенсор 1',
        location: 'Вход в комнату',
      ),
      Sensor(
        id: 'S1',
        name: 'Сенсор 2',
        location: 'Центр комнаты',
      ),
      Sensor(
        id: 'S2',
        name: 'Сенсор 3',
        location: 'Окно',
      ),
    ];
  }

  static List<LED> createLEDs() {
    return [
      LED(id: 'L0', name: 'LED 1', location: 'Левый угол'),
      LED(id: 'L1', name: 'LED 2', location: 'Правый угол'),
      LED(id: 'L2', name: 'LED 3', location: 'Передняя стена'),
      LED(id: 'L3', name: 'LED 4', location: 'Задняя стена'),
    ];
  }

  static List<Buzzer> createBuzzers() {
    return [
      Buzzer(id: 'B0', name: 'Баззер 1', frequency: 1000),
      Buzzer(id: 'B1', name: 'Баззер 2', frequency: 1500),
      Buzzer(id: 'B2', name: 'Баззер 3', frequency: 2000),
    ];
  }

  static List<Servo> createServos() {
    return [
      Servo(id: 'SV0', name: 'Серво 1', angle: 90),
      Servo(id: 'SV1', name: 'Серво 2', angle: 90),
    ];
  }
}