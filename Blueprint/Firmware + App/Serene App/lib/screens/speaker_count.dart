import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'device_count.dart';
import 'placement_instructions.dart';

class SpeakerCountScreen extends StatefulWidget {
  final VehicleData selectedVehicle;
  final bool isPhone;
  final String modelName;
  const SpeakerCountScreen({
    super.key,
    required this.selectedVehicle,
    this.isPhone = false,
    required this.modelName,
  });
  @override
  State<SpeakerCountScreen> createState() => _SpeakerCountScreenState();
}

class _SpeakerCountScreenState extends State<SpeakerCountScreen> {
  int speakerCount = 4;
  @override
  Widget build(BuildContext context) => Scaffold(
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
            "How many speakers are in your ${widget.selectedVehicle.name}?",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCountButton(Icons.remove, () {
                if (speakerCount > 2) setState(() => speakerCount -= 2);
              }),
              SizedBox(
                width: 100,
                child: Text(
                  "$speakerCount",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
              _buildCountButton(Icons.add, () {
                if (speakerCount < 30) setState(() => speakerCount += 2);
              }),
            ],
          ),
          const Spacer(),
          PrimaryButton(
            text: "Continue",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => widget.isPhone
                    ? PlacementInstructionsScreen(
                        vehicle: widget.selectedVehicle,
                        speakerCount: speakerCount,
                        deviceCount: 1,
                        isPhone: true,
                        modelName: widget.modelName,
                      )
                    : DeviceCountScreen(
                        selectedVehicle: widget.selectedVehicle,
                        speakerCount: speakerCount,
                        modelName: widget.modelName,
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
