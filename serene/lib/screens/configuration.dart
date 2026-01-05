import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: accentColor(context), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Due to its latency bluetooth is highly discouraged\nand may lead to degraded performace",
                    style: const TextStyle(fontSize: 13, height: 1.4),
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
                ? (isDark ? accentColor(context) : kLightAccentColor)
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
