import 'package:flutter/material.dart';
import '../main.dart';
import 'pairing_instructions.dart';

class AddDeviceScreen extends StatelessWidget {
  const AddDeviceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = SereneStateProvider.of(context);
    final hasPhone = model.hasPhone; // Check global phone state

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add A New Device"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SereneSection(
          children: [
            _buildSelectionRow(
              context,
              "Serene Ultra",
              "Our flagship ANC speaker + hub",
              Colors.purple,
            ),
            _buildSelectionRow(
              context,
              "Serene Max",
              "Best in-class ANC speaker",
              Colors.green,
            ),
            _buildSelectionRow(
              context,
              "Serene Pro",
              "Our flagship ANC mic array",
              Colors.blueGrey,
            ),
            _buildSelectionRow(
              context,
              "Serene Mini",
              "Our entry level mic array",
              Colors.blue.shade200,
            ),
            _buildSelectionRow(
              context,
              "Serene Core",
              "A hub that allows pairing up to 12 devices",
              Colors.cyan,
            ),
            // Phone Option (Hidden if already added)
            if (!hasPhone)
              _buildSelectionRow(
                context,
                "This Device",
                "Use this phone as a sensor",
                Colors.grey,
                isPhone: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow(
    BuildContext context,
    String name,
    String subtitle,
    Color color, {
    bool isPhone = false,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) =>
              PairingInstructionScreen(isPhone: isPhone, modelName: name),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            DeviceRepresentation(modelName: isPhone ? "Phone" : name, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
