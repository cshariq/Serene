import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Haptics
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:math';
import 'dart:io' show Platform;

void main() {
  runApp(SereneStateProvider(model: SereneModel(), child: const SereneApp()));
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
  final String name;
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
}

class UserVehicle {
  final String id;
  final String name;
  final VehicleType type;
  final int speakerCount;
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
}

// Global State Logic
class SereneModel extends ChangeNotifier {
  final List<UserDevice> _devices = [];
  final List<UserVehicle> _vehicles = [];
  String? _currentVehicleId;
  String? _activeDeviceId;

  SereneModel();

  List<UserDevice> get devices => List.unmodifiable(_devices);
  List<UserVehicle> get vehicles => List.unmodifiable(_vehicles);

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
    notifyListeners();
  }

  void setActiveDevice(String deviceId) {
    _activeDeviceId = deviceId;
    notifyListeners();
  }

  void updateAncLevel(String vehicleId, double level) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index].ancLevel = level;
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
  bool _useMaterialYou = true;
  bool get useMaterialYou => _useMaterialYou;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setUseMaterialYou(bool value) {
    _useMaterialYou = value;
    notifyListeners();
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
const Color kLightTextPrimary = Colors.black;
const Color kLightTextSecondary = Colors.black54;

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

class SereneApp extends StatelessWidget {
  const SereneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null &&
            darkDynamic != null &&
            model.useMaterialYou) {
          lightScheme = lightDynamic.copyWith(
            primary: kLightAccentColor,
            secondary: kLightAccentColor,
          );
          darkScheme = darkDynamic.copyWith(
            primary: kAccentColor,
            secondary: kAccentColor,
          );
        } else {
          lightScheme = const ColorScheme.light(
            primary: kLightAccentColor,
            secondary: kLightAccentColor,
            surface: kLightCardColor,
            surfaceContainerHighest: kLightSliderContainerColor,
            onSurface: kLightTextPrimary,
            onSurfaceVariant: kLightTextSecondary,
          );
          darkScheme = const ColorScheme.dark(
            primary: kAccentColor,
            secondary: kAccentColor,
            surface: kCardColor,
            surfaceContainerHighest: kSliderContainerColor,
            onSurface: kTextPrimary,
            onSurfaceVariant: kTextSecondary,
          );
        }

        return MaterialApp(
          title: 'Serene Pro',
          debugShowCheckedModeBanner: false,
          themeMode: model.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor:
                (model.useMaterialYou && lightDynamic != null)
                ? lightScheme.surfaceContainerLowest
                : kLightBackground,
            primaryColor: lightScheme.primary,
            cardColor: (model.useMaterialYou && lightDynamic != null)
                ? lightScheme.surfaceContainer
                : kLightCardColor,
            canvasColor: (model.useMaterialYou && lightDynamic != null)
                ? lightScheme.surfaceContainer
                : kLightCardColor,
            colorScheme: lightScheme,
            timePickerTheme: TimePickerThemeData(
              backgroundColor: lightScheme.surfaceContainer,
              dialHandColor: lightScheme.primary,
              dialBackgroundColor: lightScheme.surface,
              hourMinuteTextColor: lightScheme.onSurface,
              dayPeriodTextColor: lightScheme.onSurfaceVariant,
              dayPeriodColor: lightScheme.surfaceContainerHighest,
              entryModeIconColor: lightScheme.primary,
              helpTextStyle: GoogleFonts.inter(color: lightScheme.onSurface),
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme)
                .apply(
                  bodyColor: lightScheme.onSurface,
                  displayColor: lightScheme.onSurface,
                ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor:
                (model.useMaterialYou && darkDynamic != null)
                ? darkScheme.surfaceContainerLowest
                : kBackground,
            primaryColor: darkScheme.primary,
            cardColor: (model.useMaterialYou && darkDynamic != null)
                ? darkScheme.surfaceContainer
                : kCardColor,
            canvasColor: (model.useMaterialYou && darkDynamic != null)
                ? darkScheme.surfaceContainer
                : kCardColor,
            colorScheme: darkScheme,
            timePickerTheme: TimePickerThemeData(
              backgroundColor: darkScheme.surfaceContainer,
              dialHandColor: darkScheme.primary,
              dialBackgroundColor: darkScheme.surface,
              hourMinuteTextColor: darkScheme.onSurface,
              dayPeriodTextColor: darkScheme.onSurfaceVariant,
              dayPeriodColor: darkScheme.surfaceContainerHighest,
              entryModeIconColor: darkScheme.primary,
              helpTextStyle: GoogleFonts.inter(color: darkScheme.onSurface),
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme)
                .apply(
                  bodyColor: darkScheme.onSurface,
                  displayColor: darkScheme.onSurface,
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
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
        center: Alignment.center,
        radius: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.15),
          blurRadius: 60,
          spreadRadius: 10,
        ),
      ],
    ),
  );
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
      width: 60,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
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
    if (isAtEdge)
      shadowPath.addOval(
        Rect.fromCenter(
          center: center,
          width: thumbHeight,
          height: thumbHeight,
        ),
      );
    else
      shadowPath.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 24, height: thumbHeight),
          const Radius.circular(20),
        ),
      );
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.3), 3.0, true);
    if (isAtEdge)
      canvas.drawCircle(center, thumbHeight / 2, paint);
    else {
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
      color: Theme.of(context).cardColor,
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
      if (children.length == 1)
        radius = BorderRadius.circular(24);
      else if (index == 0)
        radius = const BorderRadius.vertical(top: Radius.circular(24));
      else if (index == children.length - 1)
        radius = const BorderRadius.vertical(bottom: Radius.circular(24));
      else
        radius = BorderRadius.zero;
      return Column(
        children: [
          Material(
            color: Theme.of(context).cardColor,
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
                          : Colors.white,
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.orange.shade100, Colors.orange.shade300],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.15),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (activeDevice != null && activeDevice.hasBattery)
              Column(
                children: [
                  BatteryPill(
                    percentage: (activeDevice.batteryLevel * 100).toInt(),
                  ),
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
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

            const SizedBox(height: 32),
            SereneCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                      color: kSliderContainerColor,
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
            const SizedBox(height: 16),
            SereneSection(
              children: [
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
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

    void _showDeviceOptions(UserDevice device) {
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
                  onLongPress: () => _showDeviceOptions(device),
                  child: Container(
                    color: isActive ? kAccentColor.withOpacity(0.05) : null,
                    child: _buildDeviceTile(
                      context,
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
                context,
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
    BuildContext context,
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.onSurface),
        ],
      ),
    ),
  );

  Widget _buildDeviceTile(
    BuildContext context, {
    required UserDevice device,
    required bool isPhone,
    required bool isActive,
    required VoidCallback onTheftToggle,
  }) {
    BoxShape shape =
        (device.model.contains("Mini") || device.model.contains("Core"))
        ? BoxShape.rectangle
        : BoxShape.circle;
    BorderRadius? borderRadius = device.model.contains("Mini")
        ? BorderRadius.circular(12)
        : (device.model.contains("Core")
              ? const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                )
              : null);
    double iconWidth =
        (device.model.contains("Mini") || device.model.contains("Core"))
        ? 18
        : 44;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: iconWidth,
            height: 44,
            decoration: BoxDecoration(
              color: isPhone ? Colors.transparent : device.color,
              shape: shape,
              borderRadius: borderRadius,
              border: isPhone
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2,
                    )
                  : null,
              gradient: isPhone
                  ? null
                  : RadialGradient(
                      colors: [
                        device.color.withOpacity(1),
                        device.color.withOpacity(0.6),
                      ],
                    ),
            ),
            child: isPhone
                ? Icon(
                    Icons.smartphone,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : null,
          ),
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
                    color: isActive
                        ? kAccentColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (device.status == "Resetting...")
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Resetting...",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (device.isUsbConnected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.usb,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.3),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
                ),
              ),
              child: isPhone
                  ? const Icon(Icons.smartphone, color: Colors.white, size: 20)
                  : null,
            ),
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
            const GlowingOrb(size: 250, color: kOrbPurple),
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
      if (mounted)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => SetupProgressScreen(
              isPhone: widget.isPhone,
              modelName: widget.modelName,
            ),
          ),
        );
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
          const Center(child: GlowingOrb(size: 280, color: Color(0xFF281E5D))),
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
      if (mounted)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => VehicleSelectionScreen(
              isPhone: widget.isPhone,
              modelName: widget.modelName,
            ),
          ),
        );
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
          const Center(child: GlowingOrb(size: 300, color: kOrbPurple)),
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

  void _onSearchChanged(String query) {
    setState(() {
      _filteredVehicles = kAllVehicles
          .where((v) => v.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
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
                            : null,
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
                          : null,
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
      decoration: const BoxDecoration(
        color: kSliderContainerColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: Colors.white),
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
                  if (canAddMultiple && deviceCount < 12)
                    setState(() => deviceCount++);
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
      decoration: const BoxDecoration(
        color: kSliderContainerColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: Colors.white),
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
    if (isPhone)
      instructions =
          "Since you are using this phone as the primary sensor, ensure it is placed in a secure phone mount on the dashboard or center console.";
    else if (deviceCount == 1)
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
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color: Colors.yellow,
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
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFFE0E0E0),
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
          const GlowingOrb(size: 250, color: kOrbPurple),
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
    if (picked != null)
      setState(() {
        if (isStart)
          startTime = picked;
        else
          endTime = picked;
      });
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
          SereneCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleRow(
                  "Dark Mode",
                  "Enable dark theme",
                  Theme.of(context).brightness == Brightness.dark,
                  (v) {
                    final model = SereneStateProvider.of(context);
                    model.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                if (Platform.isAndroid) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  _buildToggleRow(
                    "Material You",
                    "Use system colors",
                    SereneStateProvider.of(context).useMaterialYou,
                    (v) {
                      final model = SereneStateProvider.of(context);
                      model.setUseMaterialYou(v);
                    },
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                _buildToggleRow(
                  "Wireless Android Auto",
                  "Enable wireless android auto to cars\nthat have wired android auto exclusively",
                  wirelessAndroidAuto,
                  (v) => setState(() => wirelessAndroidAuto = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SereneCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleRow(
                  "Loudness Alerts",
                  "Notify when surrounding sound\nexceeds safe levels",
                  loudnessAlerts,
                  (v) => setState(() => loudnessAlerts = v),
                ),
                if (loudnessAlerts) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  _buildToggleRow(
                    "Sound Notifications",
                    "Notify using sound in addition to push\nnotifications",
                    soundNotifs,
                    (v) => setState(() => soundNotifs = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SereneCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleRow(
                  "Theft Protection",
                  "Alert and start immediate tracking when\ndriving is detected at unusual hours",
                  theftProtection,
                  (v) => setState(() => theftProtection = v),
                ),
                if (theftProtection) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
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
              ],
            ),
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
            activeColor: const Color(0xFF455A64),
            activeTrackColor: const Color(0xFF80CBC4),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Theme.of(context).disabledColor,
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
              if (isSelected)
                selectedDays.remove(index);
              else
                selectedDays.add(index);
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
            color: isSelected ? kAccentColor : kSliderContainerColor,
            borderRadius: BorderRadius.circular(30),
            border: isSelected ? null : Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black87 : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.white70,
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

// --- VEHICLE SCREEN (Dynamic List) ---
class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final vehicles = model.vehicles;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Vehicles",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (vehicles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  "No vehicles added yet.",
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
            )
          else
            ...vehicles.map((v) {
              final vehicleDevices = model.getDevicesForVehicle(v.id);
              return SereneSection(
                children: [
                  _buildVehicleHeader(context, v.name),
                  ...vehicleDevices.map(
                    (d) => _buildVehicleDeviceRow(
                      context,
                      name: d.name,
                      shape:
                          d.model.contains("Mini") || d.model.contains("Core")
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      color: d.color,
                      radius: d.model.contains("Mini")
                          ? BorderRadius.circular(10)
                          : (d.model.contains("Core")
                                ? const BorderRadius.only(
                                    topRight: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  )
                                : null),
                      iconWidth:
                          d.model.contains("Mini") || d.model.contains("Core")
                          ? 16
                          : 32,
                      trailing: Row(
                        children: [
                          if (d.isUsbConnected)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.usb,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (d.isTheftDetector)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: kSuccessGreen,
                              ),
                            ),
                          if (d.isHub)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.device_hub,
                                size: 18,
                                color: kPurpleIcon,
                              ),
                            ),
                          if (d.hasBattery)
                            BatteryPill(
                              percentage: (d.batteryLevel * 100).toInt(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          const SizedBox(height: 24),
          SereneCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const AddDeviceScreen()),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Add New Vehicle",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Icon(
                  Icons.add,
                  size: 30,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleHeader(BuildContext context, String name) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Icon(Icons.shield_outlined, color: kSuccessGreen, size: 20),
      ],
    ),
  );
  Widget _buildVehicleDeviceRow(
    BuildContext context, {
    required String name,
    required BoxShape shape,
    required Color color,
    required BorderRadius? radius,
    required double iconWidth,
    required Widget trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Container(
          width: iconWidth,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: shape,
            borderRadius: radius,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        trailing,
      ],
    ),
  );
}

// --- SOUND SCREEN (Reusing Vehicle List Style) ---
class SoundScreen extends StatelessWidget {
  const SoundScreen({super.key});
  @override
  Widget build(BuildContext context) => const VehicleScreen(); // Visual reuse as requested
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
    activeColor: kAccentColor,
    activeTrackColor: const Color(0xFF455A64),
    inactiveTrackColor: Colors.black26,
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
