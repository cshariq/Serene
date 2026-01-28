import 'package:flutter/material.dart';
import '../main.dart';

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
    activeThumbColor: accentColor(context),
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
