import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'placement_instructions.dart';

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
                  if (canAddMultiple && deviceCount < 12) {
                    setState(() => deviceCount++);
                  }
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
