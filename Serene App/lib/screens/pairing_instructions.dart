import 'package:flutter/material.dart';
import '../main.dart';
import 'connecting.dart';

class PairingInstructionScreen extends StatelessWidget {
  final bool isPhone;
  final String modelName;
  const PairingInstructionScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  Widget build(BuildContext context) {
    if (isPhone) {
      Future.delayed(
        Duration.zero,
        () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) =>
                ConnectingScreen(isPhone: true, modelName: modelName),
          ),
        ),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
            DeviceRepresentation(modelName: modelName, size: 250),
            const SizedBox(height: 60),
            const Text(
              "Locate the power button on the side of the device. Press it until the device glows blue",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            PrimaryButton(
              text: "Continue",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ConnectingScreen(modelName: modelName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
