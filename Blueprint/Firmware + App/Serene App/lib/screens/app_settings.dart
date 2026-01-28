import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../main.dart';

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
