import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' show ImageFilter;
import '../main.dart';

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
                          ? accentColor(context).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: accentColor(context), width: 2)
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
                                  color: isSelected
                                      ? accentColor(context)
                                      : null,
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
                            color: accentColor(context),
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
                Icon(
                  Icons.directions_car,
                  color: accentColor(context),
                  size: 24,
                ),
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
                    color: theme.colorScheme.surfaceContainerHighest,
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
                                  : accentColor(context),
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
                        ? accentColor(context).withOpacity(0.15)
                        : SereneTone.surfaceMedium(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? accentColor(context)
                          : Colors.transparent,
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
                            ? accentColor(context)
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
                                  ? accentColor(context)
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
                          activeTrackColor: accentColor(context),
                          inactiveTrackColor:
                              theme.colorScheme.surfaceContainerHighest,
                          thumbColor: accentColor(context),
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
                          activeTrackColor: accentColor(context),
                          inactiveTrackColor: SereneTone.surfaceLow(context),
                          thumbColor: accentColor(context),
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
                    color: accentColor(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.speaker_group,
                    color: accentColor(context),
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
            color: value ? accentColor(context) : kTextSecondary,
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
              Icon(Icons.speaker_group, size: 48, color: accentColor(context)),
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
