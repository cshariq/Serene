import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'add_device.dart';

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
                style: TextStyle(
                  color: accentColor(context),
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
                    Navigator.pop(context);
                  },
                  onLongPress: () => showDeviceOptions(device),
                  child: Container(
                    color: isActive
                        ? accentColor(context).withOpacity(0.05)
                        : null,
                    child: _buildDeviceTile(
                      context: context,
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
    required BuildContext context,
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
                    color: isActive ? accentColor(context) : Colors.white,
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
