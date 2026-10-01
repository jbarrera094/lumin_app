import 'package:flutter/material.dart';

class ModelLoadingOverlay extends StatelessWidget {
  const ModelLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Loading AI model...', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
