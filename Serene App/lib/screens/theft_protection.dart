import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class TheftProtectionScreen extends StatefulWidget {
  const TheftProtectionScreen({super.key});

  @override
  State<TheftProtectionScreen> createState() => _TheftProtectionScreenState();
}

class _TheftProtectionScreenState extends State<TheftProtectionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = SereneStateProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Theft Protection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.vehicles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'No vehicles configured',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ...state.vehicles.map((vehicle) {
              final isProtected = vehicle.isTheftProtectionActive;
              final vehicleDevices = state.getDevicesForVehicle(vehicle.id);
              final currentDevice = vehicleDevices
                  .where((d) => d.isTheftDetector)
                  .firstOrNull;
              final eligibleDevices = vehicleDevices
                  .where((d) => d.model != 'Phone')
                  .toList();

              return Column(
                children: [
                  SereneSection(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: SereneTone.surfaceHigh(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            if (isProtected)
                              GradientIcon(
                                Icons.shield,
                                gradient: LinearGradient(
                                  colors: [kSuccessGreen, accentColor(context)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                size: 26,
                              )
                            else
                              Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                                size: 26,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SereneTone.surfaceLow(context),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          vehicle.type.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isProtected
                                              ? kSuccessGreen.withOpacity(0.15)
                                              : SereneTone.surfaceLow(context),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: isProtected
                                              ? Border.all(
                                                  color: kSuccessGreen,
                                                  width: 1,
                                                )
                                              : null,
                                        ),
                                        child: Text(
                                          isProtected ? 'PROTECTED' : 'OFF',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isProtected
                                                ? kSuccessGreen
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (eligibleDevices.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: Colors.orange.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'No devices available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade300,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: SereneTone.surfaceLow(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Transform.scale(
                                scale: 0.9,
                                child: Switch(
                                  value: isProtected,
                                  onChanged: (value) {
                                    HapticFeedback.lightImpact();
                                    state.toggleVehicleTheftProtection(
                                      vehicle.id,
                                      value,
                                    );
                                  },
                                  activeThumbColor: const Color(0xFF455A64),
                                  activeTrackColor: const Color(0xFF80CBC4),
                                  inactiveThumbColor:
                                      theme.brightness == Brightness.light
                                      ? Colors.grey.shade600
                                      : Colors.grey,
                                  inactiveTrackColor:
                                      theme.brightness == Brightness.light
                                      ? Colors.grey.shade300
                                      : theme.disabledColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isProtected) ...[
                    const SizedBox(height: 12),
                    SereneSection(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detector Device',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (eligibleDevices.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: SereneTone.surfaceLow(context),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: Colors.orange.shade300,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'No devices available for theft detection',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                SereneSection(
                                  children: [
                                    for (final device in eligibleDevices)
                                      Row(
                                        children: [
                                          DeviceRepresentation(
                                            modelName: device.model,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  device.name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${device.model} • ${device.batteryLevel.toInt()}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Radio<String>(
                                            value: device.id,
                                            groupValue: currentDevice?.id,
                                            activeColor: const Color(
                                              0xFF80CBC4,
                                            ),
                                            onChanged: (_) {
                                              HapticFeedback.selectionClick();
                                              state.setTheftDetectorDevice(
                                                device.id,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }
}
