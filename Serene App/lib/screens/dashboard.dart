import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:ui' show ImageFilter;
import '../main.dart';
import 'profile_menu.dart';
import 'vehicle_screen.dart';
import 'paired_devices.dart';
import 'theft_protection.dart';
import 'app_settings.dart';
import 'configuration.dart';
import 'sound.dart';
import 'software_update.dart';
import 'add_device.dart';

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
                        ? accentColor(context)
                        : Colors.grey,
                  ),
                  title: Text(
                    v.name,
                    style: TextStyle(
                      color: v.id == model.currentVehicle?.id
                          ? accentColor(context)
                          : (Theme.of(context).brightness == Brightness.light
                                ? Colors.black
                                : Colors.white),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: v.id == model.currentVehicle?.id
                      ? Icon(Icons.check, color: accentColor(context))
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

  void _showDebugPanel(BuildContext context) {
    final model = SereneStateProvider.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Debug Console",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.mic),
                    title: const Text("Test Microphone Input"),
                    subtitle: const Text("Records 3s then plays back"),
                    onTap: () {
                      Navigator.pop(context);
                      model.runMicTest();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Recording... Speak now!"),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up),
                    title: const Text("Test ANC Output"),
                    subtitle: const Text("Toggle Pink Noise"),
                    trailing: Switch(
                      value: model.ancOutput.isPlaying,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            model.ancOutput.start(
                              model.currentVehicle?.ancLevel ?? 5.0,
                            );
                          } else {
                            model.ancOutput.stop();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
    final Gradient sereneGradient = LinearGradient(
      colors: [kSuccessGreen, accentColor(context)],
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
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => _showDebugPanel(context),
          ),
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
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  Text(
                    getStatusLabel(ancLevel),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
              ),
                  const SizedBox(height: 17),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(30),
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
                                    : accentColor(context),
                              ),
                              overlayColor: Colors.transparent,
                              overlayShape: SliderComponentShape.noOverlay,
                              trackHeight: 52,
                              thumbShape: MorphingThumbShape(
                                labelValue: ancLevel.round().toString(),
                                isAtEdge: isAtEdge,
                                thumbHeight: 52,
                              ),
                            ),
                            child: Slider(
                              value: ancLevel,
                              min: 0,
                              max: 10,
                              divisions: 10,
                              onChanged: (val) {
                                if (val != ancLevel) {
                                  HapticFeedback.heavyImpact();
                                  model.updateAncLevel(currentVehicle.id, val);
                                }
                              },
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: ancLevel == 0
                                      ? activeIconColor
                                      : const Color(0xFF777777),
                                  size: 24,
                                ),
                                Icon(
                                  Icons.blur_off,
                                  color: ancLevel == 10
                                      ? activeIconColor
                                      : const Color(0xFF777777),
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
    final bleConnected = model.ble.isConnected;
    final sensorsActive = model.sensors.isRunning;
    final audioActive = model.audio.isRunning;
    final phoneIsActive = model.activeDevice?.model == 'Phone';
    final currentVehicle = model.currentVehicle!;
    final ancLevel = currentVehicle.ancLevel;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isReady) {
      statusText = "System Ready";
      statusColor = kSuccessGreen;
      statusIcon = Icons.check_circle_outlined;
    } else if (phoneIsActive && (sensorsActive || audioActive)) {
      statusText = "Phone Sensors Active";
      statusColor = Colors.orange;
      statusIcon = Icons.sensors_outlined;
    } else if (phoneIsActive) {
      statusText = "Phone Mode";
      statusColor = Colors.blue;
      statusIcon = Icons.phone_android_outlined;
    } else if (!bleConnected) {
      statusText = "Device Disconnected";
      statusColor = Colors.grey;
      statusIcon = Icons.cloud_off_outlined;
    } else {
      statusText = "Connecting...";
      statusColor = Colors.blue;
      statusIcon = Icons.sync_outlined;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
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
        ),
        const SizedBox(width: 8),
        if (phoneIsActive && ancLevel == 0)
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              model.updateAncLevel(currentVehicle.id, 5.0);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor(context).withValues(alpha: 0.2),
                border: Border.all(
                  color: accentColor(context).withValues(alpha: 0.5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: accentColor(context), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Start',
                    style: TextStyle(
                      color: accentColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (phoneIsActive && ancLevel > 0)
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              model.updateAncLevel(currentVehicle.id, 0);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop, color: Colors.redAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Stop',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
