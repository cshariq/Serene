import 'package:flutter/material.dart';
import '../main.dart';

class FinalSuccessScreen extends StatelessWidget {
  final VehicleData vehicle;
  final int speakerCount;
  final int deviceCount;
  final bool isPhone;
  final String? existingVehicleId;
  final String modelName;
  const FinalSuccessScreen({
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
          const Spacer(),
          const Text(
            "You're All Set!",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          DeviceRepresentation(
            modelName: isPhone ? "Phone" : modelName,
            size: 250,
          ),
          const Spacer(),
          PrimaryButton(
            text: "Continue",
            onPressed: () {
              final model = SereneStateProvider.of(context);
              if (existingVehicleId != null) {
                model.addDevicesToExistingVehicle(
                  existingVehicleId!,
                  deviceCount,
                  modelName,
                  isPhoneSetup: isPhone,
                );
              } else {
                model.addSystemSetup(
                  vehicle,
                  speakerCount,
                  deviceCount,
                  modelName,
                  isPhoneSetup: isPhone,
                );
              }
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    ),
  );
}
