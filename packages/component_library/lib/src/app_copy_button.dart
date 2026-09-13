import 'dart:async';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';

/// Copy feedback is local UI state; the caller owns the clipboard operation.
class AppCopyButton extends StatefulWidget {
  const AppCopyButton({
    required this.onCopy,
    required this.copyLabel,
    required this.copiedLabel,
    required this.failureLabel,
    super.key,
  });

  final Future<void> Function() onCopy;
  final String copyLabel;
  final String copiedLabel;
  final String failureLabel;

  @override
  State<AppCopyButton> createState() => _AppCopyButtonState();
}

class _AppCopyButtonState extends State<AppCopyButton> {
  Timer? _feedbackTimer;
  bool _copying = false;
  bool? _succeeded;

  Future<void> _copy() async {
    if (_copying) return;
    _feedbackTimer?.cancel();
    setState(() {
      _copying = true;
      _succeeded = null;
    });
    bool succeeded;
    try {
      await widget.onCopy();
      succeeded = true;
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() {
      _copying = false;
      _succeeded = succeeded;
    });
    if (succeeded) {
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _succeeded = null);
      });
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: _succeeded != null,
      child: IconButton(
        tooltip: switch (_succeeded) {
          true => widget.copiedLabel,
          false => widget.failureLabel,
          null => widget.copyLabel,
        },
        onPressed: _copying ? null : _copy,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(AppSizes.buttonHeight),
          backgroundColor: Colors.transparent,
        ),
        icon: Icon(
          switch (_succeeded) {
            true => AppIcons.check,
            false => AppIcons.error,
            null => AppIcons.copy,
          },
          size: AppIconSize.sm,
        ),
      ),
    );
  }
}
