import 'package:flutter/material.dart';

class SubmitReportPage extends StatefulWidget {
  const SubmitReportPage({super.key});

  @override
  State<SubmitReportPage> createState() => _SubmitReportState();
}

class _SubmitReportState extends State<SubmitReportPage> {
  // Step 1 state
  String? selectedFloodType = "Street Flooding";
  String? selectedWaterLevel = "Medium";

  final List<String> floodTypes = [
    "Street Flooding",
    "River Overflow",
    "Drainage Issue",
    "Other",
  ];

  final List<Map<String, String>> waterLevels = [
    {"label": "Low", "sub": "(< 10 cm)"},
    {"label": "Medium", "sub": "(10 - 30 cm)"},
    {"label": "High", "sub": "(> 30 cm)"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // ---- Step indicator ----
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: _StepIndicator(
                currentStep: 1,
                steps: ["Location", "Details", "Photos", "Submit"],
              ),
            ),

            // ---- Scrollable form content ----
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Location ----
                    const Text(
                      "Location",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Jalan Tun Razak, Kuala Lumpur",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "5.5041, 101.7128",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.gps_fixed,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---- Type of Flooding ----
                    const Text(
                      "Type of Flooding",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.6,
                      children: floodTypes.map((type) {
                        final bool isSelected = selectedFloodType == type;
                        return _SelectableChip(
                          label: type,
                          selected: isSelected,
                          onTap: () {
                            setState(() => selectedFloodType = type);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ---- Water Level ----
                    const Text(
                      "Water Level (Approx.)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: waterLevels.map((level) {
                        final bool isSelected =
                            selectedWaterLevel == level["label"];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _SelectableChip(
                              label: level["label"]!,
                              sublabel: level["sub"],
                              selected: isSelected,
                              onTap: () {
                                setState(
                                      () => selectedWaterLevel = level["label"],
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ---- Next button ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: navigate to Details step
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

/// Horizontal numbered step indicator with connecting lines.
class _StepIndicator extends StatelessWidget {
  final int currentStep; // 1-based index of active step
  final List<String> steps;

  const _StepIndicator({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // connecting line between circles
          final leftStep = (i ~/ 2) + 1;
          final isActive = leftStep < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isActive ? Colors.blue : Colors.grey.shade300,
            ),
          );
        }

        final stepNumber = (i ~/ 2) + 1;
        final isActive = stepNumber == currentStep;
        final isDone = stepNumber < currentStep;

        return Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isActive || isDone)
                    ? Colors.blue
                    : Colors.grey.shade300,
              ),
              alignment: Alignment.center,
              child: Text(
                "$stepNumber",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepNumber - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Selectable rounded-rectangle chip used for flood type / water level.
class _SelectableChip extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.blue.shade700 : Colors.black87,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.blue.shade400
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}