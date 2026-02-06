import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:serene/main.dart';
import 'dart:ui' show ImageFilter;
import 'paired_devices.dart';
import 'theft_protection.dart';
import 'add_device.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});
  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  void _showEditDialog(
    BuildContext context,
    UserVehicle vehicle,
    SereneModel model,
  ) {
    final nameController = TextEditingController(text: vehicle.name);
    int speakerCount = vehicle.speakerCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.15,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentColor(context).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.directions_car,
                                color: accentColor(context),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Edit Vehicle",
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Update your vehicle settings",
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Vehicle Name Field
                        Text(
                          "VEHICLE NAME",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: SereneTone.surfaceMedium(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: nameController,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter vehicle name",
                              prefixIcon: Icon(
                                Icons.edit_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Speaker Count
                        Text(
                          "SPEAKER COUNT",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: SereneTone.surfaceHigh(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.speaker,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "$speakerCount speakers",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: (theme.brightness == Brightness.dark)
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove,
                                        color: speakerCount > 2
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.3),
                                      ),
                                      onPressed: speakerCount > 2
                                          ? () => setDialogState(
                                              () => speakerCount -= 2,
                                            )
                                          : null,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: theme.dividerColor,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      onPressed: () => setDialogState(
                                        () => speakerCount += 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      kSuccessGreen,
                                      accentColor(context),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor(
                                        context,
                                      ).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    model.updateVehicleName(
                                      vehicle.id,
                                      nameController.text,
                                    );
                                    model.updateSpeakerCount(
                                      vehicle.id,
                                      speakerCount,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Save Changes",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
              final deviceCount = vehicleDevices.length;
              final hasHub = model.vehicleHasHub(v.id);
              final hasCore = model.vehicleHasCore(v.id);
              final theftActive = v.isTheftProtectionActive;
              final ancStatus = _ancLabel(v.ancLevel);

              return SereneCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Name + Edit button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.name,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditDialog(context, v, model),
                          tooltip: "Edit vehicle",
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: "Delete vehicle",
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete vehicle"),
                                content: const Text(
                                  "This will remove the vehicle and its devices. Delete?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              model.deleteVehicle(v.id);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stats row with speaker pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _typeChip(context, v.type),
                        GestureDetector(
                          onTap: () => _showEditDialog(context, v, model),
                          child: _statChip(
                            context,
                            Icons.speaker,
                            "${v.speakerCount} speakers",
                          ),
                        ),
                        _statChip(
                          context,
                          Icons.devices_other,
                          "$deviceCount devices",
                        ),
                        if (hasHub) _statChip(context, Icons.device_hub, "Hub"),
                        if (hasCore) _statChip(context, Icons.memory, "Core"),
                        _statusChip(
                          context,
                          theftActive ? Icons.shield : Icons.shield_outlined,
                          theftActive ? "Protected" : "Unprotected",
                          theftActive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ANC Status
                    _sectionHeader(context, "ANC Status"),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ancStatus.contains("Deactivated")
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 20,
                            color: ancStatus.contains("Deactivated")
                                ? Colors.grey
                                : accentColor(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ancStatus,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Devices
                    _sectionHeader(context, "Devices"),
                    const SizedBox(height: 10),
                    ...vehicleDevices.map((d) => _deviceTile(context, d)),
                    const SizedBox(height: 12),

                    // Action links (compact)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.devices, size: 16),
                          label: const Text(
                            "Manage Devices",
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const PairedDevicesScreen(),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text(
                            "Theft Protection",
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const TheftProtectionScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
          SereneCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const AddDeviceScreen()),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Add New Vehicle",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Icon(Icons.add, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ancLabel(double val) {
    if (val == 0) return "ANC Deactivated";
    if (val == 10) return "Full ANC Active";
    if (val > 5) return "Wind + Road Noise ANC Active";
    return "Road Noise ANC Active";
  }

  Widget _statChip(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SereneTone.surfaceLow(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _statusChip(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isActive
          ? kSuccessGreen.withOpacity(0.15)
          : SereneTone.surfaceLow(context),
      borderRadius: BorderRadius.circular(24),
      border: isActive ? Border.all(color: kSuccessGreen, width: 1) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isActive ? kSuccessGreen : null),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: isActive ? kSuccessGreen : null,
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(BuildContext context, String title) => Text(
    title,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _deviceTile(BuildContext context, UserDevice d) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: SereneTone.surfaceHigh(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        DeviceRepresentation(modelName: d.model, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                d.model,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (d.isTheftDetector)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.shield_outlined, size: 18, color: kSuccessGreen),
          ),
        if (d.isHub)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.device_hub, size: 18, color: kPurpleIcon),
          ),
        if (d.hasBattery)
          BatteryPill(percentage: (d.batteryLevel * 100).toInt()),
      ],
    ),
  );

  Widget _typeChip(BuildContext context, VehicleType type) {
    String label;
    switch (type) {
      case VehicleType.sedan:
        label = "Sedan";
        break;
      case VehicleType.suv:
        label = "SUV";
        break;
      case VehicleType.truck:
        label = "Truck";
        break;
      case VehicleType.minivan:
        label = "Minivan";
        break;
      case VehicleType.coupe:
        label = "Coupe";
        break;
      case VehicleType.other:
        label = "Other";
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
