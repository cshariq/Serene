import 'package:flutter/material.dart';
import '../main.dart';
import 'setup_progress.dart';

class ConnectingScreen extends StatefulWidget {
  final bool isPhone;
  final String modelName;
  const ConnectingScreen({
    super.key,
    this.isPhone = false,
    this.modelName = "Device",
  });
  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => SetupProgressScreen(
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
            "Connecting to your device",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "This may take a while...",
            style: TextStyle(color: kTextSecondary, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              minHeight: 8,
              color: Color(0xFF3B5B75),
              backgroundColor: Color(0xFF263238),
            ),
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
