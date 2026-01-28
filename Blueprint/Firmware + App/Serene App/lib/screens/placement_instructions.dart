import 'package:flutter/material.dart';
import '../main.dart';
import 'calibration.dart';

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
    if (isPhone) {
      instructions =
          "Since you are using this phone as the primary sensor, ensure it is placed in a secure phone mount on the dashboard or center console.";
    } else if (deviceCount == 1)
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.orange
                                : Colors.yellow,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
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
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
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
