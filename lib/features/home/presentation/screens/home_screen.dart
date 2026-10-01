import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/model_loading_overlay.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(chatProvider.select((state) => state.status));

    ref.listen(chatProvider.select((state) => state.status), (_, next) {
      if (next == ChatStatus.error) {
        _showLoadFailure(context, ref);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Lumin')),
      body: SafeArea(
        child: status == ChatStatus.loading
            ? const ModelLoadingOverlay()
            : const Column(
                children: [
                  Expanded(child: ChatMessageList()),
                  ChatComposer(),
                ],
              ),
      ),
    );
  }

  void _showLoadFailure(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('model-error-dialog'),
        title: const Text('Something went wrong'),
        content: const Text(
          "Couldn't load the AI model. Please try again.",
        ),
        actions: [
          FilledButton(
            key: const Key('model-retry-button'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(chatProvider.notifier).loadModel();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
