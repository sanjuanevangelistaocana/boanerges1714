import 'package:flutter/material.dart';
import 'package:boanerges1714/config/responsive.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  List<Widget> actions = const [],
  double desiredWidth = 560,
  bool fullscreen = false,
  bool fullscreenOnMobile = false,
  bool barrierDismissible = true,
}) {
  final isSmallScreen = context.responsive.isSmallMobile ||
      context.responsive.width < ResponsiveBreakpoints.tablet;
  final useFullscreen = fullscreen || (fullscreenOnMobile && isSmallScreen);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final body = _ResponsiveDialogBody(
        title: title,
        actions: actions,
        builder: builder,
      );
      if (useFullscreen) {
        return Dialog.fullscreen(
          child: SafeArea(child: body),
        );
      }
      final width = MediaQuery.of(dialogContext).size.width;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width - 32 < desiredWidth ? width - 32 : desiredWidth,
            maxHeight: MediaQuery.of(dialogContext).size.height * .86,
          ),
          child: body,
        ),
      );
    },
  );
}

class _ResponsiveDialogBody extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final WidgetBuilder builder;

  const _ResponsiveDialogBody({
    required this.title,
    required this.actions,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = context.responsive.isSmallMobile;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: builder(context),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            if (isSmallScreen)
              ..._withVerticalDialogSpacing(actions)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _withHorizontalDialogSpacing(actions),
              ),
          ],
        ],
      ),
    );
  }
}

List<Widget> _withHorizontalDialogSpacing(
  List<Widget> children, {
  double spacing = 8,
}) {
  final result = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) result.add(SizedBox(width: spacing));
    result.add(children[index]);
  }
  return result;
}

List<Widget> _withVerticalDialogSpacing(
  List<Widget> children, {
  double spacing = 8,
}) {
  final result = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) result.add(SizedBox(height: spacing));
    result.add(
      SizedBox(width: double.infinity, child: children[index]),
    );
  }
  return result;
}
