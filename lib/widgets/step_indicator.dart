import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const StepIndicator({super.key, required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = constraints.maxWidth / (steps.length * 2);

        return Column(
          children: [
            SizedBox(
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: sideInset,
                    right: sideInset,
                    child: Row(
                      children: List.generate(steps.length - 1, (index) {
                        return Expanded(
                          child: Container(
                            height: 2,
                            color: index + 1 < currentStep
                                ? Colors.blue
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),
                  ),
                  Row(
                    children: List.generate(steps.length, (index) {
                      final stepNumber = index + 1;
                      final isActive = stepNumber == currentStep;
                      final isDone = stepNumber < currentStep;

                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive || isDone
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                            child: Text(
                              '$stepNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                steps.length,
                (index) => Expanded(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: index + 1 == currentStep
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: index + 1 == currentStep
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
