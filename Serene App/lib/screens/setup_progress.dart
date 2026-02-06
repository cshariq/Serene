import 'package:flutter/material.dart';
import '../main.dart';
import 'vehicle_selection.dart';

class SetupProgressScreen extends StatefulWidget {
  final bool isPhone;
  final String modelName;
  const SetupProgressScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  State<SetupProgressScreen> createState() => _SetupProgressScreenState();
}

class _SetupProgressScreenState extends State<SetupProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => VehicleSelectionScreen(
              isPhone: widget.isPhone,
              modelName: widget.modelName,
            ),
          ),
        );
      }
    });
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Setting Up...",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Your device is being setup...",
            style: TextStyle(color: kTextSecondary, fontSize: 15),
          ),
          const Spacer(),
          Center(
            child: DeviceRepresentation(
              modelName: widget.isPhone ? "Phone" : widget.modelName,
              size: 300,
            ),
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}
