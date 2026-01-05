import 'package:flutter/material.dart';
import '../main.dart';
import 'final_success.dart';

class CalibrationScreen extends StatelessWidget {
  final VehicleData vehicle;
  final int speakerCount;
  final int deviceCount;
  final bool isPhone;
  final String? existingVehicleId;
  final String modelName;
  const CalibrationScreen({
    super.key,
    required this.vehicle,
    required this.speakerCount,
    required this.deviceCount,
    this.isPhone = false,
    this.existingVehicleId,
    required this.modelName,
  });
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Calibration",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Place your phone on top of the centre console and start the calibration.",
            style: TextStyle(color: kTextSecondary, fontSize: 16),
          ),
          const Spacer(),
          const Spacer(),
          PrimaryButton(
            text: "Start",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => FinalSuccessScreen(
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
