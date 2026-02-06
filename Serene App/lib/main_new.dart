import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Haptics
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/profile_menu.dart';
import 'screens/vehicle_screen.dart';
import 'services/anc_processor.dart';
import 'services/bluetooth_service.dart';
import 'services/sensor_service.dart';
import 'services/audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final model = SereneModel();
  // Load data after app initialization
  model.loadData();
  runApp(SereneStateProvider(model: model, child: const SereneApp()));
}

// --- DATA MODELS & STATE MANAGEMENT ---

enum VehicleType { sedan, suv, truck, minivan, coupe, other }

class VehicleData {
  final String name;
  final VehicleType type;
  const VehicleData(this.name, this.type);
}

class UserDevice {
  final String id;
  final String vehicleId;
  String name;
  final String model;
  final Color color;
  final bool isHub;
  bool isTheftDetector; // Mutable
  final bool isUsbConnected;
  final bool hasBattery;
  String status;
  double batteryLevel;

  UserDevice({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.model,
    required this.color,
    this.isHub = false,
    this.isTheftDetector = false,
    this.isUsbConnected = false,
    this.hasBattery = false,
    this.status = "Connected",
    this.batteryLevel = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'name': name,
    'model': model,
    'color': color.value,
    'isHub': isHub,
    'isTheftDetector': isTheftDetector,
    'isUsbConnected': isUsbConnected,
    'hasBattery': hasBattery,
    'status': status,
    'batteryLevel': batteryLevel,
  };

  factory UserDevice.fromJson(Map<String, dynamic> json) => UserDevice(
    id: json['id'],
    vehicleId: json['vehicleId'],
    name: json['name'],
    model: json['model'],
    color: Color(json['color']),
    isHub: json['isHub'] ?? false,
    isTheftDetector: json['isTheftDetector'] ?? false,
    isUsbConnected: json['isUsbConnected'] ?? false,
    hasBattery: json['hasBattery'] ?? false,
    status: json['status'] ?? 'Connected',
    batteryLevel: json['batteryLevel'] ?? 1.0,
  );
}

class UserVehicle {
  final String id;
  String name;
  final VehicleType type;
  int speakerCount;
  bool isTheftProtectionActive;
  double ancLevel;

  UserVehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.speakerCount,
    this.isTheftProtectionActive = false,
    this.ancLevel = 4.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'speakerCount': speakerCount,
    'isTheftProtectionActive': isTheftProtectionActive,
    'ancLevel': ancLevel,
  };

  factory UserVehicle.fromJson(Map<String, dynamic> json) => UserVehicle(
    id: json['id'],
    name: json['name'],
    type: VehicleType.values.firstWhere((e) => e.name == json['type']),
    speakerCount: json['speakerCount'],
    isTheftProtectionActive: json['isTheftProtectionActive'] ?? false,
    ancLevel: json['ancLevel'] ?? 4.0,
  );
}

// Global State Logic
class SereneModel extends ChangeNotifier {
  final List<UserDevice> _devices = [];
  final List<UserVehicle> _vehicles = [];
  String? _currentVehicleId;
  String? _activeDeviceId;
  // Profile state
  String _profileName = 'Guest';
  String _profileEmail = '';
  // Auth state
  String? _authToken;
  bool _isSignedIn = false;
  // Runtime services
  final BleClient _ble = BleClient();
  final AncProcessor _anc = AncProcessor();
  late final SensorService _sensors;
  late final AudioService _audio;

  SereneModel() {
    _sensors = SensorService();
    _audio = AudioService();
  }

  List<UserDevice> get devices => List.unmodifiable(_devices);
  List<UserVehicle> get vehicles => List.unmodifiable(_vehicles);
  String get profileName => _profileName;
  String get profileEmail => _profileEmail;
  bool get isSignedIn => _isSignedIn;

  void setProfileName(String name) {
    _profileName = name;
    saveData();
    notifyListeners();
  }

  void setProfileEmail(String email) {
    _profileEmail = email;
    saveData();
    notifyListeners();
  }

  // --- AUTH ---
  Future<bool> signIn(String email, String password) async {
    // Local-only sign in: no server, just store credentials (demo)
    _profileEmail = email;
    _isSignedIn = true;
    saveData();
    notifyListeners();
    return true;
  }

  void signOut() {
    _authToken = null;
    _isSignedIn = false;
    saveData();
    notifyListeners();
  }

  // --- RUNTIME / CONNECTIVITY ---
  /// System ready when: BLE connected AND (device is active OR phone sensors+audio are active)
  bool get isSystemReady {
    final bleConnected = _ble.isConnected;
    final sensorsActive = _sensors.isRunning;
    final audioActive = _audio.isRunning;
    return bleConnected && (sensorsActive || audioActive);
  }

  void initializeRuntime() {
    // Start Bluetooth scan for Serene devices
    _ble.onDeviceFound = (r) {
      final id = r.device.remoteId.str;
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : 'Serene Device';
      final existingIdx = _devices.indexWhere((d) => d.id == id);
      if (existingIdx == -1) {
        _devices.add(
          UserDevice(
            id: id,
            vehicleId: _currentVehicleId ?? 'global',
            name: name,
            model: name,
            color: Colors.blue.shade200,
            isHub: false,
            isUsbConnected: false,
            hasBattery: true,
            status: 'Discovered',
            batteryLevel: 1.0,
          ),
        );
      } else {
        _devices[existingIdx].status = 'Discovered';
      }
      notifyListeners();
    };
    _ble.startScan();
    // Start ANC processor
    _anc.start();
    // Monitor BLE connection state and activate phone sensors when BLE connects
    _monitorBleConnection();
  }

  void _monitorBleConnection() {
    // This will be called periodically or via a listener to check connection state
    // For now, we'll integrate this into the main loop or device connect/disconnect methods
    if (_ble.isConnected) {
      // Auto-activate phone sensors and audio when device is connected
      if (!_sensors.isRunning) {
        _sensors.start();
      }
      if (!_audio.isRunning) {
        _audio.start();
      }
      // Wire audio/sensor input to ANC processor
      _updateAncInput();
    } else {
      // Stop sensors/audio when disconnected
      if (_sensors.isRunning) {
        _sensors.stop();
      }
      if (_audio.isRunning) {
        _audio.stop();
      }
    }
  }

  void _updateAncInput() {
    // Combine audio and sensor data for ANC input
    final audioNoise = _audio.noiseLevel; // 0..1
    final sensorMotion = _sensors.accelMagnitude; // 0..1
    // Weighted combination: audio has more influence on ANC
    final combinedNoise = (audioNoise * 0.7) + (sensorMotion * 0.3);
    _anc.setExternalNoiseLevel(combinedNoise);
  }

  Future<void> registerPhoneAsDevice() async {
    // Ensure a phone device exists and mark as connected locally
    try {
      final phone = _devices.firstWhere((d) => d.model == 'Phone');
      phone.status = 'Connected';
      notifyListeners();
    } catch (_) {
      // no phone present; ignore
    }
  }

  double get simulatedNoiseLevel => _anc.noiseLevel;
  double get simulatedAncLevel => _anc.ancLevel;

  UserVehicle? get currentVehicle {
    if (_currentVehicleId == null || _vehicles.isEmpty) return null;
    try {
      return _vehicles.firstWhere((v) => v.id == _currentVehicleId);
    } catch (e) {
      return null;
    }
  }

  UserDevice? get activeDevice {
    if (_activeDeviceId == null) return null;
    try {
      return _devices.firstWhere((d) => d.id == _activeDeviceId);
    } catch (e) {
      return null;
    }
  }

  // Check if the phone is already added to the system
  bool get hasPhone => _devices.any((d) => d.model == "Phone");

  List<UserDevice> getDevicesForVehicle(String vehicleId) {
    // Return devices for this vehicle OR the global phone
    return _devices
        .where((d) => d.vehicleId == vehicleId || d.model == "Phone")
        .toList();
  }

  bool vehicleHasHub(String vehicleId) {
    return _devices.any((d) => d.vehicleId == vehicleId && d.isHub);
  }

  bool vehicleHasCore(String vehicleId) {
    return _devices.any(
      (d) => d.vehicleId == vehicleId && d.model == "Serene Core",
    );
  }

  bool isModelHub(String modelName) {
    return ["Serene Core", "Serene Ultra", "Serene Pro"].contains(modelName);
  }

  void switchVehicle(String vehicleId) {
    _currentVehicleId = vehicleId;
    final vehicleDevices = getDevicesForVehicle(vehicleId);
    if (vehicleDevices.isNotEmpty) {
      // Prefer Hub or first device
      final hub = vehicleDevices.firstWhere(
        (d) => d.isHub,
        orElse: () => vehicleDevices.first,
      );
      _activeDeviceId = hub.id;
    }
    saveData();
    notifyListeners();
  }

  void setActiveDevice(String deviceId) {
    _activeDeviceId = deviceId;
    // Trigger BLE connection monitoring and auto-activation of sensors
    Future.delayed(const Duration(milliseconds: 100), _monitorBleConnection);
    saveData();
    notifyListeners();
  }

  void updateAncLevel(String vehicleId, double level) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].ancLevel = level;
      saveData();
      notifyListeners();
    }
  }

  void updateSpeakerCount(String vehicleId, int count) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].speakerCount = count;
      saveData();
      notifyListeners();
    }
  }

  void updateVehicleName(String vehicleId, String name) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].name = name;
      saveData();
      notifyListeners();
    }
  }

  void deleteVehicle(String vehicleId) {
    _vehicles.removeWhere((v) => v.id == vehicleId);
    _devices.removeWhere((d) => d.vehicleId == vehicleId && d.model != "Phone");

    if (_currentVehicleId == vehicleId) {
      _currentVehicleId = _vehicles.isNotEmpty ? _vehicles.first.id : null;
    }

    if (_currentVehicleId != null) {
      final remainingDevices = getDevicesForVehicle(_currentVehicleId!);
      _activeDeviceId = remainingDevices.isNotEmpty
          ? remainingDevices.first.id
          : null;
    } else {
      _activeDeviceId = null;
    }

    saveData();
    notifyListeners();
  }

  void updateDeviceName(String deviceId, String name) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _devices[index].name = name;
      saveData();
      notifyListeners();
    }
  }

  // --- DEVICE MANAGEMENT ---

  void deleteDevice(String deviceId) {
    // Check vehicle ID before deleting to reassign theft protection later
    String? vehicleId;
    try {
      final device = _devices.firstWhere((d) => d.id == deviceId);
      vehicleId = device.vehicleId;
    } catch (e) {
      /* ignore */
    }

    _devices.removeWhere((d) => d.id == deviceId);

    // If active device was deleted, switch active device
    if (_activeDeviceId == deviceId) {
      if (_currentVehicleId != null) {
        final remaining = getDevicesForVehicle(_currentVehicleId!);
        if (remaining.isNotEmpty) {
          _activeDeviceId = remaining.first.id;
        } else {
          _activeDeviceId = null;
        }
      } else {
        _activeDeviceId = null;
      }
    }

    // Re-evaluate theft protection for the affected vehicle
    if (vehicleId != null) {
      _reassignTheftProtection(vehicleId);
    }

    saveData();
    notifyListeners();
  }

  void factoryResetDevice(String deviceId) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _devices[index].status = "Resetting...";
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (index < _devices.length) {
          _devices[index].status = "Connected";
          saveData();
          notifyListeners();
        }
      });
    }
  }

  // --- THEFT PROTECTION LOGIC ---

  int _getTheftPriority(String model) {
    if (model == "Phone") return -1; // Phone cannot be theft detector
    if (model == "Serene Core") return 5;
    if (model == "Serene Ultra") return 4;
    if (model == "Serene Pro") return 3;
    if (model == "Serene Max") return 2;
    if (model == "Serene Mini") return 1;
    return 0;
  }

  void _reassignTheftProtection(String vehicleId) {
    if (vehicleId == "global") return;

    UserVehicle? vehicle;
    try {
      vehicle = _vehicles.firstWhere((v) => v.id == vehicleId);
    } catch (e) {
      return;
    }

    final vehicleDevices = getDevicesForVehicle(vehicleId);

    // Reset all to false first
    for (var d in vehicleDevices) {
      d.isTheftDetector = false;
    }

    UserDevice? bestCandidate;
    int maxPriority = -1;

    for (var d in vehicleDevices) {
      int p = _getTheftPriority(d.model);
      if (p > maxPriority) {
        maxPriority = p;
        bestCandidate = d;
      }
    }

    if (bestCandidate != null && maxPriority > -1) {
      bestCandidate.isTheftDetector = true;
    } else {
      vehicle.isTheftProtectionActive = false;
    }

    saveData();
    notifyListeners();
  }

  String? setTheftDetectorDevice(String deviceId) {
    final targetDevice = _devices.firstWhere((d) => d.id == deviceId);
    if (_getTheftPriority(targetDevice.model) == -1) return null;

    String? disabledDeviceName;

    if (!targetDevice.isTheftDetector) {
      for (var d in _devices) {
        if ((d.vehicleId == targetDevice.vehicleId || d.model == "Phone") &&
            d.id != deviceId &&
            d.isTheftDetector) {
          d.isTheftDetector = false;
          disabledDeviceName = d.name;
        }
      }
      targetDevice.isTheftDetector = true;
      final vehicle = _vehicles.firstWhere(
        (v) => v.id == targetDevice.vehicleId,
      );
      vehicle.isTheftProtectionActive = true;
    } else {
      targetDevice.isTheftDetector = false;
      final vehicle = _vehicles.firstWhere(
        (v) => v.id == targetDevice.vehicleId,
      );
      vehicle.isTheftProtectionActive = false;
    }

    saveData();
    notifyListeners();
    return disabledDeviceName;
  }

  String? toggleVehicleTheftProtection(String vehicleId, bool isActive) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].isTheftProtectionActive = isActive;

      if (isActive) {
        final vehicleDevices = getDevicesForVehicle(vehicleId);
        bool hasDetector = vehicleDevices.any((d) => d.isTheftDetector);
        if (!hasDetector) {
          _reassignTheftProtection(vehicleId);
        }
      }
    }
    saveData();
    notifyListeners();
    return null;
  }

  // --- ADDING LOGIC ---

  void addDevicesToExistingVehicle(
    String vehicleId,
    int newDeviceCount,
    String selectedModel, {
    bool isPhoneSetup = false,
  }) {
    switchVehicle(vehicleId);
    _generateAndAddDevices(
      vehicleId,
      newDeviceCount,
      isPhoneSetup,
      selectedModel,
    );
    _reassignTheftProtection(vehicleId);
    saveData();
    notifyListeners();
  }

  void addSystemSetup(
    VehicleData vehicleData,
    int speakerCount,
    int deviceCount,
    String selectedModel, {
    bool isPhoneSetup = false,
  }) {
    final newVehicleId = DateTime.now().millisecondsSinceEpoch.toString();
    final newVehicle = UserVehicle(
      id: newVehicleId,
      name: vehicleData.name,
      type: vehicleData.type,
      speakerCount: speakerCount,
      isTheftProtectionActive: true,
      ancLevel: 4.0,
    );

    _vehicles.add(newVehicle);
    _currentVehicleId = newVehicleId;

    _generateAndAddDevices(
      newVehicleId,
      deviceCount,
      isPhoneSetup,
      selectedModel,
    );
    _reassignTheftProtection(newVehicleId);

    final addedDevices = getDevicesForVehicle(newVehicleId);
    if (addedDevices.isNotEmpty) {
      _activeDeviceId = addedDevices.first.id;
    }

    saveData();
    notifyListeners();
  }

  void _generateAndAddDevices(
    String vehicleId,
    int newCount,
    bool isPhoneSetup,
    String primaryModel,
  ) {
    Color getModelColor(String m) {
      if (m == "Serene Core") return Colors.cyan.shade200;
      if (m == "Serene Ultra") return Colors.purple.shade200;
      if (m == "Serene Pro") return Colors.orange.shade200;
      if (m == "Serene Max") return Colors.green.shade200;
      return Colors.blue.shade200;
    }

    int existingCount = _devices.where((d) => d.vehicleId == vehicleId).length;

    if (isPhoneSetup) {
      if (!hasPhone) {
        _devices.insert(
          0,
          UserDevice(
            id: "global_phone",
            vehicleId: "global",
            name: "This Phone",
            model: "Phone",
            color: Colors.white,
            isHub: false,
            isTheftDetector: false,
            isUsbConnected: false,
            hasBattery: true,
            batteryLevel: 0.85,
          ),
        );
      }
    } else {
      for (int i = 0; i < newCount; i++) {
        String currentModel;
        if (i == 0) {
          currentModel = primaryModel;
        } else {
          currentModel = "Serene Mini";
        }

        bool isHub = isModelHub(currentModel);
        bool isUsb = isHub;
        bool hasBattery = !isHub;

        _devices.insert(
          0,
          UserDevice(
            id: "${vehicleId}_${DateTime.now().millisecondsSinceEpoch}_$i",
            vehicleId: vehicleId,
            name: (newCount == 1 && existingCount == 0)
                ? currentModel
                : "$currentModel ${existingCount + i + 1}",
            model: currentModel,
            color: getModelColor(currentModel),
            isHub: isHub,
            isTheftDetector: false, // Handled by _reassignTheftProtection
            isUsbConnected: isUsb,
            hasBattery: hasBattery,
            batteryLevel: 0.5 + (Random().nextDouble() * 0.5),
          ),
        );
      }
    }
  }

  // --- THEME LOGIC ---
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool _useMaterialYou = false;
  bool get useMaterialYou => _useMaterialYou;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    saveData();
    notifyListeners();
  }

  void setUseMaterialYou(bool value) {
    _useMaterialYou = value;
    saveData();
    notifyListeners();
  }

  // --- DATA PERSISTENCE ---
  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save vehicles
      final vehiclesJson = _vehicles.map((v) => v.toJson()).toList();
      await prefs.setString('vehicles', jsonEncode(vehiclesJson));

      // Save devices
      final devicesJson = _devices.map((d) => d.toJson()).toList();
      await prefs.setString('devices', jsonEncode(devicesJson));

      // Save current selections
      if (_currentVehicleId != null) {
        await prefs.setString('currentVehicleId', _currentVehicleId!);
      }
      if (_activeDeviceId != null) {
        await prefs.setString('activeDeviceId', _activeDeviceId!);
      }

      // Save theme settings
      await prefs.setString('themeMode', _themeMode.name);
      await prefs.setBool('useMaterialYou', _useMaterialYou);

      // Save profile
      await prefs.setString('profileName', _profileName);
      await prefs.setString('profileEmail', _profileEmail);
      await prefs.setString('authToken', _authToken ?? '');
      await prefs.setBool('isSignedIn', _isSignedIn);
    } catch (e) {
      // Silently fail if preferences aren't available yet
      // This can happen during app initialization
    }
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load vehicles
      final vehiclesString = prefs.getString('vehicles');
      if (vehiclesString != null) {
        final List<dynamic> vehiclesJson = jsonDecode(vehiclesString);
        _vehicles.clear();
        _vehicles.addAll(vehiclesJson.map((v) => UserVehicle.fromJson(v)));
      }

      // Load devices
      final devicesString = prefs.getString('devices');
      if (devicesString != null) {
        final List<dynamic> devicesJson = jsonDecode(devicesString);
        _devices.clear();
        _devices.addAll(devicesJson.map((d) => UserDevice.fromJson(d)));
      }

      // Load current selections
      _currentVehicleId = prefs.getString('currentVehicleId');
      _activeDeviceId = prefs.getString('activeDeviceId');

      // Load theme settings
      final themeModeString = prefs.getString('themeMode');
      if (themeModeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.name == themeModeString,
          orElse: () => ThemeMode.system,
        );
      }
      _useMaterialYou = prefs.getBool('useMaterialYou') ?? false;

      // Load profile
      _profileName = prefs.getString('profileName') ?? 'Guest';
      _profileEmail = prefs.getString('profileEmail') ?? '';
      final token = prefs.getString('authToken');
      _authToken = (token != null && token.isNotEmpty) ? token : null;
      _isSignedIn = prefs.getBool('isSignedIn') ?? false;

      notifyListeners();
    } catch (e) {
      // If loading fails, continue with default empty state
      // This can happen on first run or if storage is unavailable
    }
  }
}

class SereneStateProvider extends InheritedNotifier<SereneModel> {
  const SereneStateProvider({
    super.key,
    required SereneModel model,
    required super.child,
  }) : super(notifier: model);

  static SereneModel of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SereneStateProvider>()!
        .notifier!;
  }
}

// --- CONSTANTS & THEME ---
const Color kBackground = Color(0xFF121212);
const Color kCardColor = Color(0xFF1E1E1E);
const Color kSliderContainerColor = Color(0xFF263238);
const Color kAccentColor = Color(0xFF80DEEA);
const Color kTextPrimary = Colors.white;
const Color kTextSecondary = Colors.grey;
const Color kSuccessGreen = Color(0xFF81C784);
const Color kErrorRed = Color(0xFFE57373);
const Color kPurpleIcon = Color(0xFFB388FF);
const Color kWarningOrange = Color(0xFFFFCC80);
const Color kOrbPurple = Color(0xFF311B92);

// Light Theme Constants
const Color kLightBackground = Color(0xFFF5F5F5);
const Color kLightCardColor = Colors.white;
const Color kLightSliderContainerColor = Color(0xFFE0E0E0);
const Color kLightAccentColor = Color(0xFF00ACC1);
const Color kLightTextPrimary = Color(0xFF1A1A1A);
const Color kLightTextSecondary = Color(0xFF666666);
const Color kLightDivider = Color(0xFFE0E0E0);
const Color kLightSuccessGreen = Color(0xFF2E7D32);
const Color kLightCardBackground = Color(0xFFFAFAFA);

const List<VehicleData> kAllVehicles = [
  VehicleData("Honda Accord", VehicleType.sedan),
  VehicleData("Honda Civic", VehicleType.sedan),
  VehicleData("Honda CR-V", VehicleType.suv),
  VehicleData("Honda Pilot", VehicleType.suv),
  VehicleData("Honda Odyssey", VehicleType.minivan),
  VehicleData("Toyota Camry", VehicleType.sedan),
  VehicleData("Toyota RAV4", VehicleType.suv),
  VehicleData("Ford F-150", VehicleType.truck),
  VehicleData("Ford Explorer", VehicleType.suv),
  VehicleData("Tesla Model 3", VehicleType.sedan),
  VehicleData("Tesla Model Y", VehicleType.suv),
  VehicleData("Nissan Altima", VehicleType.sedan),
  VehicleData("Cadillac Escalade", VehicleType.suv),
  VehicleData("Chevrolet Silverado", VehicleType.truck),
  VehicleData("BMW 3 Series", VehicleType.sedan),
];

// --- MATERIAL YOU SURFACE TONES (Tinted containers) ---
class SereneTone {
  static Color _tint(Color base, Color tint, double opacity) {
    return Color.alphaBlend(tint.withOpacity(opacity), base);
  }

  static Color surfaceLowest(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _tint(cs.surface, cs.primary, 0.03);
  }

  static Color surfaceLow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _tint(cs.surface, cs.primary, 0.06);
  }

  static Color surfaceMedium(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _tint(cs.surface, cs.primary, 0.09);
  }

  static Color surfaceHigh(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _tint(cs.surface, cs.primary, 0.12);
  }

  static Color surfaceHighest(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _tint(cs.surface, cs.primary, 0.16);
  }
}

class SereneApp extends StatelessWidget {
  const SereneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme = model.useMaterialYou && lightDynamic != null
            ? lightDynamic.copyWith(
                surface: lightDynamic.surface,
                surfaceContainerHighest: lightDynamic.surfaceContainerHighest,
                onSurface: lightDynamic.onSurface,
                onSurfaceVariant: lightDynamic.onSurfaceVariant,
              )
            : const ColorScheme.light(
                primary: kLightAccentColor,
                secondary: kLightAccentColor,
                surface: kLightCardColor,
                surfaceContainerHighest: kLightSliderContainerColor,
                onSurface: kLightTextPrimary,
                onSurfaceVariant: kLightTextSecondary,
              );

        final darkColorScheme = model.useMaterialYou && darkDynamic != null
            ? darkDynamic.copyWith(
                surface: darkDynamic.surface,
                surfaceContainerHighest: darkDynamic.surfaceContainerHighest,
                onSurface: darkDynamic.onSurface,
                onSurfaceVariant: darkDynamic.onSurfaceVariant,
              )
            : const ColorScheme.dark(
                primary: kAccentColor,
                secondary: kAccentColor,
                surface: kCardColor,
                surfaceContainerHighest: kSliderContainerColor,
                onSurface: kTextPrimary,
                onSurfaceVariant: kTextSecondary,
              );

        return MaterialApp(
          title: 'Serene Pro',
          debugShowCheckedModeBanner: false,
          themeMode: model.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: model.useMaterialYou
                ? lightColorScheme.surface
                : kLightBackground,
            primaryColor: lightColorScheme.primary,
            cardColor: model.useMaterialYou
                ? lightColorScheme.surfaceContainer
                : kLightCardColor,
            canvasColor: model.useMaterialYou
                ? lightColorScheme.surfaceContainer
                : kLightCardColor,
            colorScheme: lightColorScheme,
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: model.useMaterialYou
                  ? lightColorScheme.surfaceContainer
                  : kLightCardColor,
              dialHandColor: lightColorScheme.primary,
              dialBackgroundColor: model.useMaterialYou
                  ? lightColorScheme.surface
                  : kLightBackground,
              hourMinuteTextColor: lightColorScheme.onSurface,
              dayPeriodTextColor: lightColorScheme.onSurfaceVariant,
              dayPeriodColor: lightColorScheme.surfaceContainerHighest,
              entryModeIconColor: lightColorScheme.primary,
              helpTextStyle: GoogleFonts.inter(
                color: lightColorScheme.onSurface,
              ),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
                .apply(
                  bodyColor: lightColorScheme.onSurface,
                  displayColor: lightColorScheme.onSurface,
                ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: model.useMaterialYou
                ? darkColorScheme.surface
                : kBackground,
            primaryColor: darkColorScheme.primary,
            cardColor: model.useMaterialYou
                ? darkColorScheme.surfaceContainer
                : kCardColor,
            canvasColor: model.useMaterialYou
                ? darkColorScheme.surfaceContainer
                : kCardColor,
            colorScheme: darkColorScheme,
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: model.useMaterialYou
                  ? darkColorScheme.surfaceContainer
                  : kCardColor,
              dialHandColor: darkColorScheme.primary,
              dialBackgroundColor: model.useMaterialYou
                  ? darkColorScheme.surface
                  : kBackground,
              hourMinuteTextColor: darkColorScheme.onSurface,
              dayPeriodTextColor: darkColorScheme.onSurfaceVariant,
              dayPeriodColor: darkColorScheme.surfaceContainerHighest,
              entryModeIconColor: darkColorScheme.primary,
              helpTextStyle: GoogleFonts.inter(
                color: darkColorScheme.onSurface,
              ),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
                .apply(
                  bodyColor: darkColorScheme.onSurface,
                  displayColor: darkColorScheme.onSurface,
                ),
            useMaterial3: true,
          ),
          home: const DashboardScreen(),
        );
      },
    );
  }
}

// --- CUSTOM WIDGETS ---

class GlowingOrb extends StatelessWidget {
  final double size;
  final Color color;
  const GlowingOrb({super.key, this.size = 220, this.color = kOrbPurple});
  @override
  Widget build(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color, Color.lerp(color, Colors.black, 0.15) ?? color],
        stops: const [0.2, 1.0],
        center: Alignment.center,
        radius: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.18),
          blurRadius: 18,
          spreadRadius: 4,
        ),
      ],
    ),
  );
}

class DeviceRepresentation extends StatelessWidget {
  final String modelName;
  final double size;

  const DeviceRepresentation({
    super.key,
    required this.modelName,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (modelName == "Phone") {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.smartphone, size: size * 0.8, color: Colors.grey),
      );
    }

    Color color;
    bool isPill = false;

    switch (modelName) {
      case "Serene Ultra":
        color = Colors.purple.shade300;
        break;
      case "Serene Max":
        color = Colors.orange.shade300;
        break;
      case "Serene Pro":
        color = Colors.blue.shade300;
        isPill = true;
        break;
      case "Serene Mini":
        color = const Color(0xFF212121);
        isPill = true;
        break;
      case "Serene Core":
        color = Colors.grey;
        isPill = true;
        break;
      default:
        color = kOrbPurple;
    }

    if (isPill) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size,
            height: size * 0.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.18) ?? color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 14,
                  spreadRadius: 3,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GlowingOrb(size: size, color: color);
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) =>
        gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
    child: Text(text, style: style),
  );
}

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;
  const GradientIcon(
    this.icon, {
    super.key,
    required this.gradient,
    this.size = 24,
  });
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (Rect bounds) => gradient.createShader(bounds),
    child: Icon(icon, size: size, color: Colors.white),
  );
}

class BatteryPill extends StatelessWidget {
  final int percentage;
  const BatteryPill({super.key, required this.percentage});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      height: 25,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 128, 128, 128).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: percentage / 100,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kSuccessGreen, kAccentColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              "$percentage%",
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MorphingThumbShape extends SliderComponentShape {
  final double thumbHeight;
  final String labelValue;
  final bool isAtEdge;
  const MorphingThumbShape({
    this.thumbHeight = 48,
    required this.labelValue,
    required this.isAtEdge,
  });
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(isAtEdge ? thumbHeight : 24, thumbHeight);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;
    final Path shadowPath = Path();
    if (isAtEdge) {
      shadowPath.addOval(
        Rect.fromCenter(
          center: center,
          width: thumbHeight,
          height: thumbHeight,
        ),
      );
    } else {
      shadowPath.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 24, height: thumbHeight),
          const Radius.circular(20),
        ),
      );
    }
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.3), 3.0, true);
    if (isAtEdge) {
      canvas.drawCircle(center, thumbHeight / 2, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 24, height: thumbHeight),
          const Radius.circular(20),
        ),
        paint,
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF006064),
          ),
          text: labelValue,
        ),
        textAlign: TextAlign.center,
        textDirection: textDirection,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
  }
}

class SereneCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  const SereneCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: SereneTone.surfaceMedium(context),
      borderRadius: BorderRadius.circular(33),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SereneSection extends StatelessWidget {
  final List<Widget> children;
  const SereneSection({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(children.length, (index) {
      BorderRadius radius;
      if (children.length == 1) {
        radius = BorderRadius.circular(24);
      } else if (index == 0)
        radius = const BorderRadius.vertical(top: Radius.circular(24));
      else if (index == children.length - 1)
        radius = const BorderRadius.vertical(bottom: Radius.circular(24));
      else
        radius = BorderRadius.zero;
      return Column(
        children: [
          Material(
            color: SereneTone.surfaceHigh(context),
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: children[index],
          ),
          if (index != children.length - 1) const SizedBox(height: 3),
        ],
      );
    }),
  );
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = kAccentColor,
    this.foregroundColor = Colors.black,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// --- SCREEN 1: DASHBOARD ---

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Battery _battery = Battery();
  int _phoneBatteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _updatePhoneBattery();
  }

  Future<void> _updatePhoneBattery() async {
    try {
      final level = await _battery.batteryLevel;
      setState(() {
        _phoneBatteryLevel = level;
      });
    } catch (e) {
      // If battery info is not available, use default
    }
  }

  String getStatusLabel(double val) {
    if (val == 0) return "ANC Deactivated";
    if (val == 10) return "Full ANC Active";
    if (val > 5) return "Wind + Road Noise ANC Active";
    return "Road Noise ANC Active";
  }

  void _showVehicleSwitcher(BuildContext context) {
    final model = SereneStateProvider.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Switch Vehicle",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...model.vehicles.map(
                (v) => ListTile(
                  leading: Icon(
                    Icons.directions_car,
                    color: v.id == model.currentVehicle?.id
                        ? kAccentColor
                        : Colors.grey,
                  ),
                  title: Text(
                    v.name,
                    style: TextStyle(
                      color: v.id == model.currentVehicle?.id
                          ? kAccentColor
                          : (Theme.of(context).brightness == Brightness.light
                                ? Colors.black
                                : Colors.white),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: v.id == model.currentVehicle?.id
                      ? const Icon(Icons.check, color: kAccentColor)
                      : null,
                  onTap: () {
                    model.switchVehicle(v.id);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: "Add New Vehicle",
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const AddDeviceScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final currentVehicle = model.currentVehicle;
    final activeDevice = model.activeDevice;

    if (currentVehicle == null) {
      return _buildEmptyState(context);
    }

    double ancLevel = currentVehicle.ancLevel;
    bool isAtEdge = (ancLevel == 0 || ancLevel == 10);
    Color activeIconColor = const Color.fromARGB(255, 0, 0, 0);
    double sliderHorizontalPadding = isAtEdge ? 0.0 : 20.0;
    const Gradient sereneGradient = LinearGradient(
      colors: [kSuccessGreen, kAccentColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.devices_other_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const PairedDevicesScreen()),
          ),
        ),
        title: Text(
          activeDevice?.name ?? "Serene Pro",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const ProfileMenuScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 40,
            ),
            DeviceRepresentation(
              modelName: activeDevice?.model ?? "Serene Pro",
              size: 260,
            ),
            const SizedBox(height: 24),
            if (activeDevice != null && activeDevice.hasBattery)
              Column(
                children: [
                  BatteryPill(
                    percentage: activeDevice.model == 'Phone'
                        ? _phoneBatteryLevel
                        : (activeDevice.batteryLevel * 100).toInt(),
                  ),
                  const SizedBox(height: 16),
                  _buildSystemReadinessIndicator(context, model),
                  const SizedBox(height: 8),
                ],
              )
            else if (activeDevice != null && activeDevice.isUsbConnected)
              Column(
                children: [
                  const Icon(Icons.usb, size: 20, color: kSuccessGreen),
                  const SizedBox(height: 12),
                ],
              ),

            GestureDetector(
              onTap: () => _showVehicleSwitcher(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: SereneTone.surfaceLow(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Connected to ${currentVehicle.name}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                model.toggleVehicleTheftProtection(
                  currentVehicle.id,
                  !currentVehicle.isTheftProtectionActive,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: currentVehicle.isTheftProtectionActive ? 1.0 : 0.5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentVehicle.isTheftProtectionActive)
                      GradientIcon(
                        Icons.shield_outlined,
                        gradient: sereneGradient,
                        size: 18,
                      )
                    else
                      const Icon(
                        Icons.shield_outlined,
                        color: Colors.grey,
                        size: 18,
                      ),
                    const SizedBox(width: 6),
                    if (currentVehicle.isTheftProtectionActive)
                      GradientText(
                        "Theft Protection On",
                        gradient: sereneGradient,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const Text(
                        "Theft Protection Off",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            SereneCard(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Column(
                children: [
                  Text(
                    getStatusLabel(ancLevel),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          padding: EdgeInsets.symmetric(
                            horizontal: sliderHorizontalPadding,
                          ),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              thumbColor: WidgetStateColor.resolveWith(
                                (states) => states.contains(WidgetState.dragged)
                                    ? const Color(0xFFB2EBF2)
                                    : kAccentColor,
                              ),
                              overlayColor: Colors.transparent,
                              overlayShape: SliderComponentShape.noOverlay,
                              trackHeight: 48,
                              thumbShape: MorphingThumbShape(
                                labelValue: ancLevel.round().toString(),
                                isAtEdge: isAtEdge,
                                thumbHeight: 48,
                              ),
                            ),
                            child: Slider(
                              value: ancLevel,
                              min: 0,
                              max: 10,
                              divisions: 10,
                              onChanged: (val) {
                                if (val != ancLevel) {
                                  HapticFeedback.selectionClick();
                                  model.updateAncLevel(currentVehicle.id, val);
                                }
                              },
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: ancLevel == 0
                                      ? activeIconColor
                                      : Colors.grey,
                                  size: 24,
                                ),
                                Icon(
                                  Icons.blur_off,
                                  color: ancLevel == 10
                                      ? activeIconColor
                                      : Colors.grey,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SereneSection(
              children: [
                _buildMenuRow(
                  "Theft Protection",
                  "Manage theft detection settings",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const TheftProtectionScreen(),
                    ),
                  ),
                ),
                _buildMenuRow(
                  "App Settings",
                  "Theme, notifications, and preferences",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const AppSettingsScreen(),
                    ),
                  ),
                ),
                _buildMenuRow(
                  "Configuration",
                  "Set the position of the speaker",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const ConfigurationScreen(),
                    ),
                  ),
                ),
                _buildMenuRow(
                  "Vehicle",
                  "Set the car make and model",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const VehicleScreen()),
                  ),
                ),
                _buildMenuRow(
                  "Sound",
                  "Change audio settings",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const SoundScreen()),
                  ),
                ),
                _buildMenuRow(
                  "Software",
                  "Check for updates",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const SoftwareUpdateScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Serene",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 260,
                width: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Welcome to Serene",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Connect a device to your vehicle to get started.",
                style: TextStyle(color: kTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                text: "Set Up System",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const AddDeviceScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow(String title, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: kTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemReadinessIndicator(
    BuildContext context,
    SereneModel model,
  ) {
    final isReady = model.isSystemReady;
    final bleConnected = model._ble.isConnected;
    final sensorsActive = model._sensors.isRunning;
    final audioActive = model._audio.isRunning;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!bleConnected) {
      statusText = "Device Disconnected";
      statusColor = Colors.grey;
      statusIcon = Icons.cloud_off_outlined;
    } else if (isReady) {
      statusText = "System Ready";
      statusColor = kSuccessGreen;
      statusIcon = Icons.check_circle_outlined;
    } else if (sensorsActive || audioActive) {
      statusText = "Phone Sensors Active";
      statusColor = Colors.orange;
      statusIcon = Icons.sensors_outlined;
    } else {
      statusText = "Connecting...";
      statusColor = Colors.blue;
      statusIcon = Icons.sync_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 2: PAIRED DEVICES ---

class PairedDevicesScreen extends StatelessWidget {
  const PairedDevicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final currentVehicle = model.currentVehicle;
    final devices = currentVehicle != null
        ? model.getDevicesForVehicle(currentVehicle.id)
        : <UserDevice>[];

    void showDeviceOptions(UserDevice device) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.white),
                  title: const Text("Rename Device"),
                  onTap: () {
                    Navigator.pop(context);
                    final controller = TextEditingController(text: device.name);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Rename Device"),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: "Enter new name",
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                model.updateDeviceName(
                                  device.id,
                                  controller.text.trim(),
                                );
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.white),
                  title: const Text("Factory Reset"),
                  onTap: () {
                    Navigator.pop(context);
                    model.factoryResetDevice(device.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Device resetting...")),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: kErrorRed),
                  title: const Text(
                    "Delete Device",
                    style: TextStyle(color: kErrorRed),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    model.deleteDevice(device.id);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (currentVehicle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                "Devices for ${currentVehicle.name}",
                style: const TextStyle(
                  color: kAccentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  "No devices paired for this vehicle.",
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
            )
          else
            SereneSection(
              children: devices.map((device) {
                bool isPhone = device.model == "Phone";
                bool isActive = model.activeDevice?.id == device.id;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    model.setActiveDevice(device.id);
                    Navigator.pop(context); // RETURN TO DASHBOARD
                  },
                  onLongPress: () => showDeviceOptions(device),
                  child: Container(
                    color: isActive ? kAccentColor.withOpacity(0.05) : null,
                    child: _buildDeviceTile(
                      device: device,
                      isPhone: isPhone,
                      isActive: isActive,
                      onTheftToggle: () {
                        if (device.model == "Phone") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Phones cannot be used as theft detectors.",
                              ),
                            ),
                          );
                          return;
                        }
                        final disabledName = model.setTheftDetectorDevice(
                          device.id,
                        );
                        if (disabledName != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Switched theft detection from $disabledName to ${device.name}",
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: kWarningOrange.withOpacity(0.9),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 8),
          SereneSection(
            children: [
              _buildSectionHeader(
                "Add Devices",
                Icons.add,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const AddDeviceScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            context,
            Icons.info_outline,
            "Tap a device to view status. Long press for options.",
            const Color(0xFF4FC3F7),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            Icons.info_outline,
            "Your phone will only be used as an ANC device if no device are online and your phone is connected to your car",
            kSuccessGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Icon(icon, size: 28),
        ],
      ),
    ),
  );

  Widget _buildDeviceTile({
    required UserDevice device,
    required bool isPhone,
    required bool isActive,
    required VoidCallback onTheftToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          DeviceRepresentation(modelName: device.model, size: 44),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isActive ? kAccentColor : Colors.white,
                  ),
                ),
                if (device.status == "Resetting...")
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Resetting...",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (device.isUsbConnected)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.usb, size: 16, color: Colors.white70),
                      ),
                    GestureDetector(
                      onTap: onTheftToggle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.shield,
                          size: 16,
                          color: device.isTheftDetector
                              ? kSuccessGreen
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    if (device.isHub)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.device_hub,
                          size: 16,
                          color: kPurpleIcon,
                        ),
                      ),
                    if (device.hasBattery)
                      BatteryPill(
                        percentage: (device.batteryLevel * 100).toInt(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String text,
    Color iconColor,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: SereneTone.surfaceMedium(context),
      borderRadius: BorderRadius.circular(36),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

// --- SETUP FLOW ---

class AddDeviceScreen extends StatelessWidget {
  const AddDeviceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final hasPhone = model.hasPhone; // Check global phone state

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add A New Device"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SereneSection(
          children: [
            _buildSelectionRow(
              context,
              "Serene Ultra",
              "Our flagship ANC speaker + hub",
              Colors.purple,
            ),
            _buildSelectionRow(
              context,
              "Serene Max",
              "Best in-class ANC speaker",
              Colors.green,
            ),
            _buildSelectionRow(
              context,
              "Serene Pro",
              "Our flagship ANC mic array",
              Colors.blueGrey,
            ),
            _buildSelectionRow(
              context,
              "Serene Mini",
              "Our entry level mic array",
              Colors.blue.shade200,
            ),
            _buildSelectionRow(
              context,
              "Serene Core",
              "A hub that allows pairing up to 12 devices",
              Colors.cyan,
            ),
            // Phone Option (Hidden if already added)
            if (!hasPhone)
              _buildSelectionRow(
                context,
                "This Device",
                "Use this phone as a sensor",
                Colors.grey,
                isPhone: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow(
    BuildContext context,
    String name,
    String subtitle,
    Color color, {
    bool isPhone = false,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) =>
              PairingInstructionScreen(isPhone: isPhone, modelName: name),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            DeviceRepresentation(modelName: isPhone ? "Phone" : name, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PairingInstructionScreen extends StatelessWidget {
  final bool isPhone;
  final String modelName;
  const PairingInstructionScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  Widget build(BuildContext context) {
    if (isPhone) {
      Future.delayed(
        Duration.zero,
        () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) =>
                ConnectingScreen(isPhone: true, modelName: modelName),
          ),
        ),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Spacer(),
            DeviceRepresentation(modelName: modelName, size: 250),
            const SizedBox(height: 60),
            const Text(
              "Locate the power button on the side of the device. Press it until the device glows blue",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            PrimaryButton(
              text: "Continue",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ConnectingScreen(modelName: modelName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectingScreen extends StatefulWidget {
  final bool isPhone;
  final String modelName;
  const ConnectingScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => SetupProgressScreen(
              isPhone: widget.isPhone,
              modelName: widget.modelName,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Connecting to your device",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "This may take a while...",
            style: TextStyle(color: kTextSecondary, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              minHeight: 8,
              color: Color(0xFF3B5B75),
              backgroundColor: Color(0xFF263238),
            ),
          ),
          const Spacer(),
          Center(
            child: DeviceRepresentation(
              modelName: widget.isPhone ? "Phone" : widget.modelName,
              size: 280,
            ),
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}

class SetupProgressScreen extends StatefulWidget {
  final bool isPhone;
  final String modelName;
  const SetupProgressScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  State<SetupProgressScreen> createState() => _SetupProgressScreenState();
}

class _SetupProgressScreenState extends State<SetupProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => VehicleSelectionScreen(
              isPhone: widget.isPhone,
              modelName: widget.modelName,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Setting Up...",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Your device is being setup...",
            style: TextStyle(color: kTextSecondary, fontSize: 15),
          ),
          const Spacer(),
          Center(
            child: DeviceRepresentation(
              modelName: widget.isPhone ? "Phone" : widget.modelName,
              size: 300,
            ),
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}

// Step 4: Vehicle Selection
class VehicleSelectionScreen extends StatefulWidget {
  final bool isPhone;
  final String modelName;
  const VehicleSelectionScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VehicleData> _filteredVehicles = kAllVehicles;
  VehicleData? _selectedVehicle;
  String? _selectedExistingVehicleId;

  void _showCustomVehicleDialog() {
    final TextEditingController nameController = TextEditingController();
    VehicleType selectedType = VehicleType.sedan;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: const Text("Add Custom Vehicle"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Vehicle Name",
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<VehicleType>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    items: VehicleType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.toString().split('.').last.toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedType = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text("Add"),
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      Navigator.pop(context);
                      this.setState(() {
                        _selectedVehicle = VehicleData(
                          nameController.text,
                          selectedType,
                        );
                        _selectedExistingVehicleId = null;
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final userVehicles = model.vehicles;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select your vehicle",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SereneTone.surfaceLow(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SereneTone.surfaceMedium(context)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (query) => setState(
                () => _filteredVehicles = kAllVehicles
                    .where(
                      (v) => v.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList(),
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: "Search model",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: SereneTone.surfaceMedium(context),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  if (userVehicles.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Your Vehicles",
                        style: TextStyle(
                          color: kAccentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...userVehicles.map(
                      (v) => ListTile(
                        tileColor: _selectedExistingVehicleId == v.id
                            ? kAccentColor.withOpacity(0.1)
                            : SereneTone.surfaceHigh(context),
                        title: Text(
                          v.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _selectedExistingVehicleId == v.id
                                ? kAccentColor
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        trailing: _selectedExistingVehicleId == v.id
                            ? const Icon(
                                Icons.check_circle,
                                color: kAccentColor,
                              )
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedExistingVehicleId = v.id;
                            _selectedVehicle = VehicleData(v.name, v.type);
                          });
                        },
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "All Vehicles",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._filteredVehicles.map(
                    (v) => ListTile(
                      tileColor:
                          _selectedVehicle == v &&
                              _selectedExistingVehicleId == null
                          ? kAccentColor.withOpacity(0.1)
                          : SereneTone.surfaceHigh(context),
                      title: Text(
                        v.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color:
                              _selectedVehicle == v &&
                                  _selectedExistingVehicleId == null
                              ? kAccentColor
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      trailing:
                          _selectedVehicle == v &&
                              _selectedExistingVehicleId == null
                          ? const Icon(Icons.check_circle, color: kAccentColor)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedVehicle = v;
                          _selectedExistingVehicleId = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: "Continue",
                    backgroundColor: _selectedVehicle != null
                        ? kAccentColor
                        : const Color(0xFF2C2C2C),
                    foregroundColor: _selectedVehicle != null
                        ? Colors.black
                        : Colors.grey,
                    onPressed: _selectedVehicle != null
                        ? () {
                            // VALIDATION LOGIC
                            bool isHub = model.isModelHub(widget.modelName);
                            String? existingId = _selectedExistingVehicleId;

                            if (existingId != null) {
                              // Adding to EXISTING
                              bool hasHub = model.vehicleHasHub(existingId);
                              bool hasCore = model.vehicleHasCore(existingId);
                              int currentDeviceCount = model
                                  .getDevicesForVehicle(existingId)
                                  .length;

                              // 1. Core Limit
                              if (widget.modelName == "Serene Core" &&
                                  hasCore) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "This vehicle already has a Core device.",
                                    ),
                                  ),
                                );
                                return;
                              }

                              // 2. Hub Required for Satellites if devices already exist
                              // Logic fix: If current count is 0 (deleted devices), allow satellite as first device.
                              if (!isHub && !hasHub && currentDeviceCount > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "A Hub (Core/Ultra/Pro) is required to add more devices.",
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => DeviceCountScreen(
                                    selectedVehicle: _selectedVehicle!,
                                    speakerCount: 0,
                                    isPhone: widget.isPhone,
                                    existingVehicleId: existingId,
                                    modelName: widget.modelName,
                                  ),
                                ),
                              );
                            } else {
                              // New Vehicle
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => SpeakerCountScreen(
                                    selectedVehicle: _selectedVehicle!,
                                    isPhone: widget.isPhone,
                                    modelName: widget.modelName,
                                  ),
                                ),
                              );
                            }
                          }
                        : () {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    text: "I don't see\nmy vehicle",
                    onPressed: _showCustomVehicleDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpeakerCountScreen extends StatefulWidget {
  final VehicleData selectedVehicle;
  final bool isPhone;
  final String modelName;
  const SpeakerCountScreen({
    super.key,
    required this.selectedVehicle,
    this.isPhone = false,
    required this.modelName,
  });
  @override
  State<SpeakerCountScreen> createState() => _SpeakerCountScreenState();
}

class _SpeakerCountScreenState extends State<SpeakerCountScreen> {
  int speakerCount = 4;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Spacer(),
          Text(
            "How many speakers are in your ${widget.selectedVehicle.name}?",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCountButton(Icons.remove, () {
                if (speakerCount > 2) setState(() => speakerCount -= 2);
              }),
              SizedBox(
                width: 100,
                child: Text(
                  "$speakerCount",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
              _buildCountButton(Icons.add, () {
                if (speakerCount < 30) setState(() => speakerCount += 2);
              }),
            ],
          ),
          const Spacer(),
          PrimaryButton(
            text: "Continue",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => widget.isPhone
                    ? PlacementInstructionsScreen(
                        vehicle: widget.selectedVehicle,
                        speakerCount: speakerCount,
                        deviceCount: 1,
                        isPhone: true,
                        modelName: widget.modelName,
                      )
                    : DeviceCountScreen(
                        selectedVehicle: widget.selectedVehicle,
                        speakerCount: speakerCount,
                        modelName: widget.modelName,
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _buildCountButton(IconData icon, VoidCallback onPressed) => InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      onPressed();
    },
    borderRadius: BorderRadius.circular(50),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class DeviceCountScreen extends StatefulWidget {
  final VehicleData selectedVehicle;
  final int speakerCount;
  final String? existingVehicleId;
  final bool isPhone;
  final String modelName;
  const DeviceCountScreen({
    super.key,
    required this.selectedVehicle,
    required this.speakerCount,
    this.existingVehicleId,
    this.isPhone = false,
    required this.modelName,
  });
  @override
  State<DeviceCountScreen> createState() => _DeviceCountScreenState();
}

class _DeviceCountScreenState extends State<DeviceCountScreen> {
  int deviceCount = 1;
  @override
  Widget build(BuildContext context) {
    bool isHub = [
      "Serene Core",
      "Serene Ultra",
      "Serene Pro",
    ].contains(widget.modelName);
    bool hasExistingHub = false;
    if (widget.existingVehicleId != null) {
      hasExistingHub = SereneStateProvider.of(
        context,
      ).vehicleHasHub(widget.existingVehicleId!);
    }
    bool canAddMultiple = isHub || hasExistingHub;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Spacer(),
            Text(
              widget.existingVehicleId != null
                  ? "How many NEW devices are you adding?"
                  : "How many Serene devices are you setting up?",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCountButton(Icons.remove, () {
                  if (deviceCount > 1) setState(() => deviceCount--);
                }),
                SizedBox(
                  width: 100,
                  child: Text(
                    "$deviceCount",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ),
                _buildCountButton(Icons.add, () {
                  if (canAddMultiple && deviceCount < 12) {
                    setState(() => deviceCount++);
                  }
                }),
              ],
            ),
            if (!canAddMultiple)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  "A Hub (Core/Ultra/Pro) is required to add more devices.",
                  style: TextStyle(color: kErrorRed),
                ),
              ),
            const Spacer(),
            PrimaryButton(
              text: "Continue",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => PlacementInstructionsScreen(
                    vehicle: widget.selectedVehicle,
                    speakerCount: widget.speakerCount,
                    deviceCount: deviceCount,
                    existingVehicleId: widget.existingVehicleId,
                    isPhone: widget.isPhone,
                    modelName: widget.modelName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountButton(IconData icon, VoidCallback onPressed) => InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      onPressed();
    },
    borderRadius: BorderRadius.circular(50),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class PlacementInstructionsScreen extends StatelessWidget {
  final VehicleData vehicle;
  final int speakerCount;
  final int deviceCount;
  final bool isPhone;
  final String? existingVehicleId;
  final String modelName;
  const PlacementInstructionsScreen({
    super.key,
    required this.vehicle,
    required this.speakerCount,
    required this.deviceCount,
    this.isPhone = false,
    this.existingVehicleId,
    required this.modelName,
  });
  @override
  Widget build(BuildContext context) {
    String instructions =
        "Distribute the $deviceCount devices evenly throughout the cabin near the main speakers.";
    if (isPhone) {
      instructions =
          "Since you are using this phone as the primary sensor, ensure it is placed in a secure phone mount on the dashboard or center console.";
    } else if (deviceCount == 1)
      instructions =
          "Place the device on the ceiling lining, centered directly above the front armrest/center console.";

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Placement for ${vehicle.name}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.orange
                                : Colors.yellow,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Recommendation",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        instructions,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: "Start Calibration",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => CalibrationScreen(
                    vehicle: vehicle,
                    speakerCount: speakerCount,
                    deviceCount: deviceCount,
                    isPhone: isPhone,
                    existingVehicleId: existingVehicleId,
                    modelName: modelName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalibrationScreen extends StatelessWidget {
  final VehicleData vehicle;
  final int speakerCount;
  final int deviceCount;
  final bool isPhone;
  final String? existingVehicleId;
  final String modelName;
  const CalibrationScreen({
    super.key,
    required this.vehicle,
    required this.speakerCount,
    required this.deviceCount,
    this.isPhone = false,
    this.existingVehicleId,
    required this.modelName,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Calibration",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Place your phone on top of the centre console and start the calibration.",
            style: TextStyle(color: kTextSecondary, fontSize: 16),
          ),
          const Spacer(),
          const Spacer(),
          PrimaryButton(
            text: "Start",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => FinalSuccessScreen(
                  vehicle: vehicle,
                  speakerCount: speakerCount,
                  deviceCount: deviceCount,
                  isPhone: isPhone,
                  existingVehicleId: existingVehicleId,
                  modelName: modelName,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class FinalSuccessScreen extends StatelessWidget {
  final VehicleData vehicle;
  final int speakerCount;
  final int deviceCount;
  final bool isPhone;
  final String? existingVehicleId;
  final String modelName;
  const FinalSuccessScreen({
    super.key,
    required this.vehicle,
    required this.speakerCount,
    required this.deviceCount,
    this.isPhone = false,
    this.existingVehicleId,
    required this.modelName,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
    ),
    body: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Spacer(),
          const Text(
            "You're All Set!",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          DeviceRepresentation(
            modelName: isPhone ? "Phone" : modelName,
            size: 250,
          ),
          const Spacer(),
          PrimaryButton(
            text: "Continue",
            onPressed: () {
              final model = SereneStateProvider.of(context);
              if (existingVehicleId != null) {
                model.addDevicesToExistingVehicle(
                  existingVehicleId!,
                  deviceCount,
                  modelName,
                  isPhoneSetup: isPhone,
                );
              } else {
                model.addSystemSetup(
                  vehicle,
                  speakerCount,
                  deviceCount,
                  modelName,
                  isPhoneSetup: isPhone,
                );
              }
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    ),
  );
}

// --- CONFIGURATION SCREEN ---
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});
  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  bool wirelessAndroidAuto = false;
  bool loudnessAlerts = true;
  bool soundNotifs = false;
  bool theftProtection = true;
  String selectedConnection = "Bluetooth";
  TimeOfDay startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 7, minute: 0);
  Set<int> selectedDays = {1, 2, 3, 4, 5};

  Future<void> _selectTime(bool isStart) async {
    HapticFeedback.lightImpact();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Configuration",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SereneSection(
            children: [
              _buildToggleRow(
                "Wireless Android Auto",
                "Enable wireless android auto to cars\nthat have wired android auto exclusively",
                wirelessAndroidAuto,
                (v) => setState(() => wirelessAndroidAuto = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SereneSection(
            children: [
              _buildToggleRow(
                "Loudness Alerts",
                "Notify when surrounding sound\nexceeds safe levels",
                loudnessAlerts,
                (v) => setState(() => loudnessAlerts = v),
              ),
              if (loudnessAlerts)
                _buildToggleRow(
                  "Sound Notifications",
                  "Notify using sound in addition to push\nnotifications",
                  soundNotifs,
                  (v) => setState(() => soundNotifs = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SereneSection(
            children: [
              _buildToggleRow(
                "Theft Protection",
                "Alert and start immediate tracking when\ndriving is detected at unusual hours",
                theftProtection,
                (v) => setState(() => theftProtection = v),
              ),
              if (theftProtection)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Set Unusual Hours",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Start:",
                        style: TextStyle(color: kTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF37474F),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _selectTime(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  startTime.format(context),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildDaySelector(),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "End:",
                        style: TextStyle(color: kTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _selectTime(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                endTime.format(context),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SereneCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Default Connection Method",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildModernConnectionChip(Icons.usb, "USB"),
                    const SizedBox(width: 8),
                    _buildModernConnectionChip(Icons.cable, "AUX"),
                    const SizedBox(width: 8),
                    _buildModernConnectionChip(Icons.bluetooth, "Bluetooth"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: kAccentColor, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Due to its latency bluetooth is highly discouraged\nand may lead to degraded performace",
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeThumbColor: const Color(0xFF455A64),
            activeTrackColor: const Color(0xFF80CBC4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade600
                : Colors.grey,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade300
                : Theme.of(context).disabledColor,
          ),
        ),
      ],
    ),
  );
  Widget _buildDaySelector() {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(days.length, (index) {
        final isSelected = selectedDays.contains(index);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSelected) {
                selectedDays.remove(index);
              } else {
                selectedDays.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Text(
              days[index],
              style: TextStyle(
                color: isSelected ? kSuccessGreen : kTextSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildModernConnectionChip(IconData icon, String label) {
    bool isSelected = selectedConnection == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => selectedConnection = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? kAccentColor : kLightAccentColor)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(30),
            border: isSelected
                ? null
                : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? Colors.black87 : Colors.white)
                    : Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.black87 : Colors.white)
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SOUND SCREEN ---
class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});
  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  // Sound settings state
  bool bassBoost = false;
  bool adaptiveSound = true;
  bool spatialAudio = false;
  double bassLevel = 0.5;
  double trebleLevel = 0.5;
  String selectedSoundProfile = "Balanced";
  String? _selectedDeviceId;

  // Models that have built-in speakers
  static const List<String> _modelsWithSpeakers = [
    "Serene Ultra",
    "Serene Max",
  ];

  bool _deviceHasSpeaker(String model) => _modelsWithSpeakers.contains(model);

  final List<Map<String, dynamic>> soundProfiles = [
    {
      "name": "Balanced",
      "icon": Icons.equalizer,
      "desc": "Natural sound balance",
    },
    {
      "name": "Bass Boost",
      "icon": Icons.graphic_eq,
      "desc": "Enhanced low frequencies",
    },
    {"name": "Vocal", "icon": Icons.mic, "desc": "Clear voice and dialogue"},
    {
      "name": "Immersive",
      "icon": Icons.surround_sound,
      "desc": "360° spatial audio",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final currentVehicle = model.currentVehicle;
    final theme = Theme.of(context);

    if (currentVehicle == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Sound Settings",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: Text(
            "No vehicle selected",
            style: TextStyle(color: kTextSecondary),
          ),
        ),
      );
    }

    double ancLevel = currentVehicle.ancLevel;
    bool isAtEdge = (ancLevel == 0 || ancLevel == 10);
    double sliderHorizontalPadding = isAtEdge ? 0.0 : 20.0;

    final vehicleDevices = model.getDevicesForVehicle(currentVehicle.id);

    // Initialize selected device if not set
    if (_selectedDeviceId == null && vehicleDevices.isNotEmpty) {
      _selectedDeviceId = vehicleDevices.first.id;
    }

    final selectedDevice = vehicleDevices.firstWhere(
      (d) => d.id == _selectedDeviceId,
      orElse: () => vehicleDevices.isNotEmpty
          ? vehicleDevices.first
          : vehicleDevices.first,
    );
    final hasBuiltInSpeaker = _deviceHasSpeaker(selectedDevice.model);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Sound Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Device Selector
          _buildSectionHeader("Select Device"),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: SereneTone.surfaceMedium(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: vehicleDevices.map((device) {
                final isSelected = device.id == _selectedDeviceId;
                final hasSpeaker = _deviceHasSpeaker(device.model);
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedDeviceId = device.id);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kAccentColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: kAccentColor, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        DeviceRepresentation(modelName: device.model, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isSelected ? kAccentColor : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    device.model,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (hasSpeaker) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.speaker,
                                      size: 14,
                                      color: kSuccessGreen,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: kAccentColor,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Notice for devices without speakers
          if (!hasBuiltInSpeaker)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWarningOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kWarningOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kWarningOrange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "No Built-in Speaker",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${selectedDevice.model} doesn't have built-in speakers. Sound settings will modify your vehicle's speaker output via ANC processing.",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Vehicle info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SereneTone.surfaceLow(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: kAccentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentVehicle.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  "${currentVehicle.speakerCount} car speakers",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ANC Section
          _buildSectionHeader("Active Noise Cancellation"),
          const SizedBox(height: 12),
          SereneCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getAncLabel(ancLevel),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ancLevel > 0
                            ? kSuccessGreen.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ancLevel > 0 ? "Active" : "Off",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: ancLevel > 0 ? kSuccessGreen : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: SereneTone.surfaceHigh(context),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        padding: EdgeInsets.symmetric(
                          horizontal: sliderHorizontalPadding,
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: WidgetStateColor.resolveWith(
                              (states) => states.contains(WidgetState.dragged)
                                  ? const Color(0xFFB2EBF2)
                                  : kAccentColor,
                            ),
                            overlayColor: Colors.transparent,
                            overlayShape: SliderComponentShape.noOverlay,
                            trackHeight: 48,
                            thumbShape: MorphingThumbShape(
                              labelValue: ancLevel.round().toString(),
                              isAtEdge: isAtEdge,
                              thumbHeight: 48,
                            ),
                          ),
                          child: Slider(
                            value: ancLevel,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (val) {
                              if (val != ancLevel) {
                                HapticFeedback.selectionClick();
                                model.updateAncLevel(currentVehicle.id, val);
                              }
                            },
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: ancLevel == 0
                                    ? Colors.black
                                    : Colors.grey,
                                size: 24,
                              ),
                              Icon(
                                Icons.blur_off,
                                color: ancLevel == 10
                                    ? Colors.black
                                    : Colors.grey,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Transparency",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "Full ANC",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sound Profiles
          _buildSectionHeader("Sound Profile"),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: soundProfiles.map((profile) {
              final isSelected = selectedSoundProfile == profile["name"];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => selectedSoundProfile = profile["name"]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kAccentColor.withOpacity(0.15)
                        : SereneTone.surfaceMedium(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? kAccentColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        profile["icon"],
                        color: isSelected
                            ? kAccentColor
                            : theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile["name"],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isSelected
                                  ? kAccentColor
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile["desc"],
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Equalizer
          _buildSectionHeader("Equalizer"),
          const SizedBox(height: 12),
          SereneCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Bass
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        "Bass",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: kAccentColor,
                          inactiveTrackColor:
                              theme.colorScheme.surfaceContainerHighest,
                          thumbColor: kAccentColor,
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: bassLevel,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => bassLevel = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        "${(bassLevel * 100).round()}%",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Treble
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        "Treble",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: kAccentColor,
                          inactiveTrackColor: SereneTone.surfaceLow(context),
                          thumbColor: kAccentColor,
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: trebleLevel,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => trebleLevel = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        "${(trebleLevel * 100).round()}%",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Audio Features
          _buildSectionHeader("Audio Features"),
          const SizedBox(height: 12),
          SereneSection(
            children: [
              _buildToggleRow(
                context,
                "Adaptive Sound",
                "Automatically adjust based on environment",
                Icons.auto_awesome,
                adaptiveSound,
                (val) => setState(() => adaptiveSound = val),
              ),
              _buildToggleRow(
                context,
                "Spatial Audio",
                "Immersive 3D sound experience",
                Icons.surround_sound,
                spatialAudio,
                (val) => setState(() => spatialAudio = val),
              ),
              _buildToggleRow(
                context,
                "Bass Boost",
                "Enhance low frequency output",
                Icons.graphic_eq,
                bassBoost,
                (val) => setState(() => bassBoost = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Speaker Test
          _buildSectionHeader("Diagnostics"),
          const SizedBox(height: 12),
          SereneCard(
            onTap: () {
              HapticFeedback.lightImpact();
              _showSpeakerTest(context, currentVehicle);
            },
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.speaker_group,
                    color: kAccentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Speaker Test",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Test all ${currentVehicle.speakerCount} speakers",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kTextSecondary),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getAncLabel(double val) {
    if (val == 0) return "Transparency Mode";
    if (val == 10) return "Full ANC";
    if (val > 5) return "Wind + Road Noise ANC";
    return "Road Noise ANC";
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _buildToggleRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value ? kAccentColor : kTextSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: value,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
            activeThumbColor: const Color(0xFF455A64),
            activeTrackColor: const Color(0xFF80CBC4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade600
                : Colors.grey,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade300
                : Theme.of(context).disabledColor,
          ),
        ),
      ],
    ),
  );

  void _showSpeakerTest(BuildContext context, UserVehicle vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.7)
                : Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.speaker_group, size: 48, color: kAccentColor),
              const SizedBox(height: 16),
              Text(
                "Speaker Test",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Test all ${vehicle.speakerCount} speakers in your ${vehicle.name}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: "Start Test",
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Speaker test started..."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// --- THEFT PROTECTION SCREEN ---
class TheftProtectionScreen extends StatefulWidget {
  const TheftProtectionScreen({super.key});

  @override
  State<TheftProtectionScreen> createState() => _TheftProtectionScreenState();
}

class _TheftProtectionScreenState extends State<TheftProtectionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = SereneStateProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Theft Protection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.vehicles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'No vehicles configured',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ...state.vehicles.map((vehicle) {
              final isProtected = vehicle.isTheftProtectionActive;
              final vehicleDevices = state.getDevicesForVehicle(vehicle.id);
              final currentDevice = vehicleDevices
                  .where((d) => d.isTheftDetector)
                  .firstOrNull;
              final eligibleDevices = vehicleDevices
                  .where((d) => d.model != 'Phone')
                  .toList();

              return Column(
                children: [
                  SereneSection(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: SereneTone.surfaceHigh(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            if (isProtected)
                              GradientIcon(
                                Icons.shield,
                                gradient: const LinearGradient(
                                  colors: [kSuccessGreen, kAccentColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                size: 26,
                              )
                            else
                              Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                                size: 26,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SereneTone.surfaceLow(context),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          vehicle.type.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isProtected
                                              ? kSuccessGreen.withOpacity(0.15)
                                              : SereneTone.surfaceLow(context),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: isProtected
                                              ? Border.all(
                                                  color: kSuccessGreen,
                                                  width: 1,
                                                )
                                              : null,
                                        ),
                                        child: Text(
                                          isProtected ? 'PROTECTED' : 'OFF',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isProtected
                                                ? kSuccessGreen
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (eligibleDevices.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: Colors.orange.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'No devices available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade300,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: SereneTone.surfaceLow(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Transform.scale(
                                scale: 0.9,
                                child: Switch(
                                  value: isProtected,
                                  onChanged: (value) {
                                    HapticFeedback.lightImpact();
                                    state.toggleVehicleTheftProtection(
                                      vehicle.id,
                                      value,
                                    );
                                  },
                                  activeThumbColor: const Color(0xFF455A64),
                                  activeTrackColor: const Color(0xFF80CBC4),
                                  inactiveThumbColor:
                                      theme.brightness == Brightness.light
                                      ? Colors.grey.shade600
                                      : Colors.grey,
                                  inactiveTrackColor:
                                      theme.brightness == Brightness.light
                                      ? Colors.grey.shade300
                                      : theme.disabledColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isProtected) ...[
                    const SizedBox(height: 12),
                    SereneSection(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detector Device',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (eligibleDevices.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: SereneTone.surfaceLow(context),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: Colors.orange.shade300,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'No devices available for theft detection',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                SereneSection(
                                  children: [
                                    for (final device in eligibleDevices)
                                      Row(
                                        children: [
                                          DeviceRepresentation(
                                            modelName: device.model,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  device.name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${device.model} • ${device.batteryLevel.toInt()}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Radio<String>(
                                            value: device.id,
                                            groupValue: currentDevice?.id,
                                            activeColor: const Color(
                                              0xFF80CBC4,
                                            ),
                                            onChanged: (_) {
                                              HapticFeedback.selectionClick();
                                              state.setTheftDetectorDevice(
                                                device.id,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// --- APP SETTINGS SCREEN ---
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool theftAlerts = true;
  bool deviceAlerts = true;
  bool updateNotifications = true;

  @override
  Widget build(BuildContext context) {
    final state = SereneStateProvider.of(context);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SereneSection(
            children: [
              _buildThemeSelector(context, state),
              if (isAndroid)
                _buildToggleRow(
                  'Material You',
                  'Use system color palette',
                  state.useMaterialYou,
                  (v) => state.setUseMaterialYou(v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SereneSection(
            children: [
              _buildToggleRow(
                'Theft Alerts',
                'Get notified about theft attempts',
                theftAlerts,
                (v) => setState(() => theftAlerts = v),
              ),
              _buildToggleRow(
                'Device Alerts',
                'Battery and connection status',
                deviceAlerts,
                (v) => setState(() => deviceAlerts = v),
              ),
              _buildToggleRow(
                'Update Notifications',
                'Software and firmware updates',
                updateNotifications,
                (v) => setState(() => updateNotifications = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeThumbColor: const Color(0xFF455A64),
            activeTrackColor: const Color(0xFF80CBC4),
            inactiveThumbColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade600
                : Colors.grey,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade300
                : Theme.of(context).disabledColor,
          ),
        ),
      ],
    ),
  );

  Widget _buildThemeSelector(BuildContext context, SereneModel state) {
    final theme = Theme.of(context);
    final modes = {
      ThemeMode.system: 'System',
      ThemeMode.light: 'Light',
      ThemeMode.dark: 'Dark',
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme Mode',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? Colors.grey.shade200
                  : const Color(0xFF37474F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: modes.entries.map((entry) {
                final isSelected = entry.key == state.themeMode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      state.setThemeMode(entry.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (theme.brightness == Brightness.light
                                  ? Colors.white
                                  : const Color(0xFF80CBC4))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isSelected
                              ? (theme.brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.black)
                              : (theme.brightness == Brightness.light
                                    ? Colors.grey.shade700
                                    : Colors.white70),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SOFTWARE UPDATE SCREEN ---
class SoftwareUpdateScreen extends StatefulWidget {
  const SoftwareUpdateScreen({super.key});
  @override
  State<SoftwareUpdateScreen> createState() => _SoftwareUpdateScreenState();
}

class _SoftwareUpdateScreenState extends State<SoftwareUpdateScreen> {
  bool autoUpdate = true;
  bool downloadWifiOnly = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Software Update",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SereneCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: kWarningOrange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: kWarningOrange,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Updates Available",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Last checked: Just now",
                        style: TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SereneSection(
            children: [
              _buildToggle(
                "Automatic Updates",
                "Install updates automatically when devices are inactive",
                autoUpdate,
                (v) => setState(() => autoUpdate = v),
              ),
              _buildToggle(
                "Download over Wi-Fi only",
                "Save mobile data by only downloading via Wi-Fi",
                downloadWifiOnly,
                (v) => setState(() => downloadWifiOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Firmware Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SereneSection(
            children: [
              _buildFirmwareRow(
                "Serene Pro",
                "v2.4.0",
                "Up to date",
                kSuccessGreen,
              ),
              _buildFirmwareRow(
                "Serene Mini",
                "v1.1.2",
                "Update Available",
                kWarningOrange,
                showButton: true,
              ),
              _buildFirmwareRow(
                "Serene Core",
                "v3.0.0",
                "Up to date",
                kSuccessGreen,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "App Version 2.5.1",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) => SwitchListTile(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: kTextSecondary),
      ),
    ),
    value: value,
    onChanged: onChanged,
    activeThumbColor: kAccentColor,
    activeTrackColor: const Color(0xFF455A64),
    inactiveThumbColor: Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade600
        : null,
    inactiveTrackColor: Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade300
        : Colors.black26,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  );
  Widget _buildFirmwareRow(
    String name,
    String version,
    String status,
    Color color, {
    bool showButton = false,
  }) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    version,
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showButton)
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: kWarningOrange,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Update",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        else
          Icon(Icons.check_circle_outline, color: color, size: 24),
      ],
    ),
  );
}
