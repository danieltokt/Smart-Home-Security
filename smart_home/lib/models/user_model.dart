class User {
  final String name;
  final String password;
  final bool isAdmin;
  bool canControlSensors;
  bool canControlServos;
  bool canControlBuzzers;
  bool canControlLeds;

  User({
    required this.name,
    required this.password,
    this.isAdmin = false,
    this.canControlSensors = false,
    this.canControlServos = false,
    this.canControlBuzzers = false,
    this.canControlLeds = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'],
      password: json['password'],
      isAdmin: json['isAdmin'] ?? false,
      canControlSensors: json['canControlSensors'] ?? false,
      canControlServos: json['canControlServos'] ?? false,
      canControlBuzzers: json['canControlBuzzers'] ?? false,
      canControlLeds: json['canControlLeds'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'password': password,
      'isAdmin': isAdmin,
      'canControlSensors': canControlSensors,
      'canControlServos': canControlServos,
      'canControlBuzzers': canControlBuzzers,
      'canControlLeds': canControlLeds,
    };
  }

  // User A - полный доступ
  static User userA = User(
    name: 'UserA',
    password: '1111',
    canControlSensors: true,
    canControlServos: true,
    canControlBuzzers: true,
    canControlLeds: true,
  );

  // User B - только сенсоры
  static User userB = User(
    name: 'UserB',
    password: '2222',
    canControlSensors: true,
    canControlServos: false,
    canControlBuzzers: false,
    canControlLeds: false,
  );

  // User C - серво и баззеры
  static User userC = User(
    name: 'UserC',
    password: '3333',
    canControlSensors: false,
    canControlServos: true,
    canControlBuzzers: true,
    canControlLeds: false,
  );

  // User D (Admin) - только управление правами
  static User admin = User(
    name: 'Admin',
    password: 'admin',
    isAdmin: true,
    canControlSensors: false,
    canControlServos: false,
    canControlBuzzers: false,
    canControlLeds: false,
  );
}