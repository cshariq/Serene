import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Haptics
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/anc_processor.dart';
import 'services/bluetooth_service.dart';
import 'services/sensor_service.dart';
import 'services/audio_service.dart';
import 'services/anc_audio_output.dart';
import 'screens/dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final model = SereneModel();
  // Load data after app initialization
  model.loadData();
  // Initialize runtime in background (don't wait for it)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    model.initializeRuntime();
  });
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
  late final AncAudioOutput _ancOutput;

  SereneModel() {
    _sensors = SensorService();
    _audio = AudioService();
    _ancOutput = AncAudioOutput(_audio);
  }

  List<UserDevice> get devices => List.unmodifiable(_devices);
  List<UserVehicle> get vehicles => List.unmodifiable(_vehicles);
  String get profileName => _profileName;
  String get profileEmail => _profileEmail;
  bool get isSignedIn => _isSignedIn;

  // Public getters for services
  BleClient get ble => _ble;
  AncProcessor get anc => _anc;
  SensorService get sensors => _sensors;
  AudioService get audio => _audio;
  AncAudioOutput get ancOutput => _ancOutput;

  /// Run a microphone test (record 3s and play back)
  Future<void> runMicTest() async {
    await _audio.recordAndPlayDebug(const Duration(seconds: 3));
  }

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
  /// System ready when: BLE connected OR phone is active device
  bool get isSystemReady {
    final bleConnected = _ble.isConnected;
    final sensorsActive = _sensors.isRunning;
    final audioActive = _audio.isRunning;
    final phoneIsActive = activeDevice?.model == 'Phone';
    // Phone is always "connected" when it's the active device
    final isConnected = bleConnected || phoneIsActive;
    return isConnected && (sensorsActive || audioActive);
  }

  /// Request all necessary permissions for ANC functionality
  Future<bool> requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = {};

    // Request bluetooth permissions (required for BLE scanning)
    if (Platform.isAndroid) {
      // Android 12+ requires these permissions
      statuses[Permission.bluetoothScan] = await Permission.bluetoothScan
          .request();
      statuses[Permission.bluetoothConnect] = await Permission.bluetoothConnect
          .request();
      statuses[Permission.locationWhenInUse] = await Permission
          .locationWhenInUse
          .request();
    } else if (Platform.isIOS) {
      statuses[Permission.bluetooth] = await Permission.bluetooth.request();
    }

    // Request microphone permission (required for audio input)
    statuses[Permission.microphone] = await Permission.microphone.request();

    // Request sensors permission if available
    if (Platform.isAndroid) {
      statuses[Permission.sensors] = await Permission.sensors.request();
    }

    // Check if all critical permissions were granted
    final bluetoothGranted = Platform.isAndroid
        ? (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
              (statuses[Permission.bluetoothConnect]?.isGranted ?? false)
        : (statuses[Permission.bluetooth]?.isGranted ?? false);

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

    return bluetoothGranted && micGranted;
  }

  /// Check if all necessary permissions are currently granted
  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final bluetoothScan = await Permission.bluetoothScan.isGranted;
      final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      final microphone = await Permission.microphone.isGranted;
      return bluetoothScan && bluetoothConnect && microphone;
    } else if (Platform.isIOS) {
      final bluetooth = await Permission.bluetooth.isGranted;
      final microphone = await Permission.microphone.isGranted;
      return bluetooth && microphone;
    }
    return false;
  }

  Future<void> initializeRuntime() async {
    // Request permissions in background
    requestPermissions()
        .then((granted) {
          if (!granted) {
            debugPrint(
              '⚠️ Permissions not granted - some features may not work',
            );
          }
        })
        .catchError((e) {
          debugPrint('Error requesting permissions: $e');
        });

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

  void _monitorBleConnection() async {
    // Check if we should activate sensors: BLE connected OR phone is active device
    final phoneIsActive = activeDevice?.model == 'Phone';
    final shouldActivate = _ble.isConnected || phoneIsActive;

    if (shouldActivate) {
      // Check permissions before activating phone sensors
      if (phoneIsActive) {
        final hasPermissions = await checkPermissions();
        if (!hasPermissions) {
          debugPrint('⚠️ Missing permissions - requesting...');
          await requestPermissions();
        }
      }

      // Auto-activate phone sensors and audio when device is connected or phone is active
      if (!_sensors.isRunning) {
        _sensors.start();
      }
      if (!_audio.isRunning) {
        _audio.start();
      }
      // Wire audio/sensor input to ANC processor
      _updateAncInput();
    } else {
      // Stop sensors/audio when disconnected and phone not active
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

    // If selecting phone as active device, request permissions in background
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => _devices.first,
    );
    if (device.model == 'Phone') {
      checkPermissions()
          .then((hasPermissions) {
            if (!hasPermissions) {
              debugPrint('🔔 Requesting permissions for phone mode...');
              requestPermissions();
            }
          })
          .catchError((e) {
            debugPrint('Error checking permissions: $e');
          });
    }

    // Trigger BLE connection monitoring and auto-activation of sensors
    Future.delayed(const Duration(milliseconds: 100), _monitorBleConnection);
    saveData();
    notifyListeners();
  }

  void updateAncLevel(String vehicleId, double level) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].ancLevel = level;

      // Control ANC audio output based on level (fire and forget)
      if (level > 0) {
        // Start ANC audio output in background
        _ancOutput.start(level).catchError((e) {
          debugPrint('Error starting ANC audio: $e');
        });
      } else {
        // Stop ANC audio output
        _ancOutput.stop().catchError((e) {
          debugPrint('Error stopping ANC audio: $e');
        });
      }

      // Update volume if already playing
      _ancOutput.updateLevel(level);

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
const Color kCardColor = Color(0xFF1B1E22);
const Color kSliderContainerColor = Color.fromARGB(255, 33, 40, 47);
const Color kAccentColor = Color.fromARGB(255, 180, 229, 244);
const Color kTextPrimary = Colors.white;
const Color kTextSecondary = Colors.grey;
const Color kSuccessGreen = Color(0xFF81C784);
const Color kErrorRed = Color(0xFFE57373);
const Color kPurpleIcon = Color(0xFFB388FF);
const Color kWarningOrange = Color(0xFFFFCC80);
const Color kOrbPurple = Color(0xFF311B92);

// Light Theme Constants
const Color kLightBackground = Color(0xFFF5F5F5);
const Color kLightCardColor = Color.fromARGB(255, 227, 248, 253);
const Color kLightSliderContainerColor = Color.fromARGB(255, 216, 239, 251);
const Color kLightAccentColor = Color.fromARGB(255, 86, 110, 110);
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
    final model = SereneStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return model.useMaterialYou
        ? _tint(cs.surface, cs.primary, 0.03)
        : cs.surface;
  }

  static Color surfaceLow(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return model.useMaterialYou
        ? _tint(cs.surface, cs.primary, 0.06)
        : cs.surface;
  }

  static Color surfaceMedium(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return model.useMaterialYou
        ? _tint(cs.surface, cs.primary, 0.09)
        : cs.surface;
  }

  static Color surfaceHigh(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return model.useMaterialYou
        ? _tint(cs.surface, cs.primary, 0.12)
        : cs.surface;
  }

  static Color surfaceHighest(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    return model.useMaterialYou
        ? _tint(cs.surface, cs.primary, 0.16)
        : cs.surface;
  }
}

/// Returns the appropriate accent color based on current brightness
Color accentColor(BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

class SereneApp extends StatelessWidget {
  const SereneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final useMaterialYou = model.useMaterialYou;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme = useMaterialYou
            ? (lightDynamic ??
                  ColorScheme.fromSeed(
                    seedColor: kLightAccentColor,
                    brightness: Brightness.light,
                  ))
            : ColorScheme.light(
                primary: kLightAccentColor,
                secondary: kLightAccentColor,
                surface: kLightCardColor,
                surfaceContainer: kLightCardColor,
                surfaceContainerLow: kLightCardColor,
                surfaceContainerLowest: kLightCardColor,
                surfaceContainerHigh: kLightCardColor,
                surfaceContainerHighest: kLightSliderContainerColor,
                onSurface: kLightTextPrimary,
                onSurfaceVariant: kLightTextSecondary,
              );

        final darkColorScheme = useMaterialYou
            ? (darkDynamic ??
                  ColorScheme.fromSeed(
                    seedColor: kAccentColor,
                    brightness: Brightness.dark,
                  ))
            : ColorScheme.dark(
                primary: kAccentColor,
                secondary: kAccentColor,
                surface: kCardColor,
                surfaceContainer: kCardColor,
                surfaceContainerLow: kCardColor,
                surfaceContainerLowest: kCardColor,
                surfaceContainerHigh: kCardColor,
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

// All screen classes have been extracted to separate files in lib/screens/
// See dashboard.dart, paired_devices.dart, add_device.dart, etc.
