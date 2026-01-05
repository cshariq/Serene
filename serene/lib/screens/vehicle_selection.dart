import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'speaker_count.dart';
import 'device_count.dart';

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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Your Vehicles",
                        style: TextStyle(
                          color: accentColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...userVehicles.map(
                      (v) => ListTile(
                        tileColor: _selectedExistingVehicleId == v.id
                            ? accentColor(context).withOpacity(0.1)
                            : SereneTone.surfaceHigh(context),
                        title: Text(
                          v.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _selectedExistingVehicleId == v.id
                                ? accentColor(context)
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        trailing: _selectedExistingVehicleId == v.id
                            ? Icon(
                                Icons.check_circle,
                                color: accentColor(context),
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
                          ? accentColor(context).withOpacity(0.1)
                          : SereneTone.surfaceHigh(context),
                      title: Text(
                        v.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color:
                              _selectedVehicle == v &&
                                  _selectedExistingVehicleId == null
                              ? accentColor(context)
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      trailing:
                          _selectedVehicle == v &&
                              _selectedExistingVehicleId == null
                          ? Icon(
                              Icons.check_circle,
                              color: accentColor(context),
                            )
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
                        ? accentColor(context)
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
