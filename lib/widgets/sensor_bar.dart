import 'package:flutter/material.dart';

/// Visualises the 5‑channel line‑follower sensor array.
///
/// Each sensor is a rounded rectangle that glows cyan when active (on‑line)
/// and dims when inactive.
class SensorBar extends StatelessWidget {
  final List<int> sensors; // length == 5, values 0 or 1
  static const _labels = ['S1', 'S2', 'S3', 'S4', 'S5'];

  const SensorBar({super.key, required this.sensors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final active = i < sensors.length && sensors[i] == 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF1A1F45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFF2A3060),
                    width: 1.5,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withOpacity(0.5),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: active
                      ? const Icon(Icons.circle, size: 14, color: Colors.white)
                      : Icon(Icons.circle_outlined,
                          size: 14,
                          color: Colors.white.withOpacity(0.2)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF6B7DB3),
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
