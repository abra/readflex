import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Form payload submitted by [DictionaryAddWordSheet]. Optional fields
/// are normalised to `null` when blank so the bloc/repository layer
/// doesn't have to repeat empty-string checks.
class DictionaryAddWordFormData {
  const DictionaryAddWordFormData({
    required this.word,
    required this.translation,
    this.pronunciation,
    this.partOfSpeech,
  });

  final String word;
  final String translation;
  final String? pronunciation;
  final String? partOfSpeech;
}

/// Bottom sheet for manually adding a new dictionary entry.
///
/// Manual-only path — translation services aren't wired yet, so the form
/// is two required fields ([word], [translation]) and two optional
/// kicker fields ([pronunciation], [partOfSpeech]). The sheet validates
/// inputs locally and hands the payload to [onSubmit]; persistence is
/// the caller's responsibility (typically the screen-level bloc).
class DictionaryAddWordSheet extends StatefulWidget {
  const DictionaryAddWordSheet({required this.onSubmit, super.key});

  /// Called with the form payload after Save passes local validation.
  /// The sheet pops itself before invoking — UI control returns to the
  /// caller's screen so it can react to the new entry (e.g. trigger a
  /// reload).
  final ValueChanged<DictionaryAddWordFormData> onSubmit;

  @override
  State<DictionaryAddWordSheet> createState() => _DictionaryAddWordSheetState();
}

class _DictionaryAddWordSheetState extends State<DictionaryAddWordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _partOfSpeechController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _pronunciationController.dispose();
    _partOfSpeechController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final data = DictionaryAddWordFormData(
      word: _wordController.text.trim(),
      translation: _translationController.text.trim(),
      pronunciation: _trimmedOrNull(_pronunciationController.text),
      partOfSpeech: _trimmedOrNull(_partOfSpeechController.text),
    );
    Navigator.of(context).pop();
    widget.onSubmit(data);
  }

  static String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Add word',
      onClose: () => Navigator.of(context).pop(),
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _wordController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Word',
                hintText: 'e.g. serendipity',
              ),
              validator: _required('Word is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _translationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Translation',
                hintText: 'e.g. счастливая случайность',
              ),
              validator: _required('Translation is required'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _pronunciationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Pronunciation (optional)',
                hintText: '/ˌsɛr.ənˈdɪp.ɪ.ti/',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _partOfSpeechController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSubmit(),
              decoration: const InputDecoration(
                labelText: 'Part of speech (optional)',
                hintText: 'noun, verb, adjective…',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _handleSubmit,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static FormFieldValidator<String> _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }
}
