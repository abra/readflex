import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'translate_cubit.dart';

Future<void> showTranslateSheet(
  BuildContext context, {
  required TextSelectionContext selection,
  required ContextualTranslationService translationService,
  required PreferencesService preferencesService,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => TranslateSheet(
      selection: selection,
      translationService: translationService,
      preferencesService: preferencesService,
    ),
  );
}

class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.selection,
    required this.translationService,
    required this.preferencesService,
    super.key,
  });

  final TextSelectionContext selection;
  final ContextualTranslationService translationService;
  final PreferencesService preferencesService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranslateCubit(
        translationService: translationService,
        preferencesService: preferencesService,
      )..translate(selection),
      child: _TranslateSheetView(selection: selection),
    );
  }
}

class _TranslateSheetView extends StatelessWidget {
  const _TranslateSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    final strings = TranslateSheetStrings.of(context);
    return ActionBottomSheetLayout(
      title: strings.title,
      headerSpacing: AppSpacing.sm,
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: BlocBuilder<TranslateCubit, TranslateSheetState>(
        builder: (context, state) {
          final cubit = context.read<TranslateCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectionPreviewCard(text: selection.effectiveSelectedText),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _LanguageDropdown(
                      semanticsLabel: strings.sourceLabel,
                      value: state.sourceLanguageCode,
                      items: [
                        _LanguageOption(
                          code: autoSourceLanguageCode,
                          name: strings.autoSource,
                        ),
                        ..._supportedLanguageOptions,
                      ],
                      enabled: !state.isBusy,
                      onChanged: (value) {
                        if (value == null) return;
                        cubit.setSourceLanguage(selection, value);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _LanguageDropdown(
                      semanticsLabel: strings.targetLabel,
                      value: state.targetLanguageCode,
                      items: _supportedLanguageOptions,
                      enabled: !state.isBusy,
                      onChanged: (value) {
                        if (value == null) return;
                        cubit.setTargetLanguage(selection, value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _TranslateBody(selection: selection, state: state),
            ],
          );
        },
      ),
    );
  }
}

class _TranslateBody extends StatelessWidget {
  const _TranslateBody({required this.selection, required this.state});

  final TextSelectionContext selection;
  final TranslateSheetState state;

  @override
  Widget build(BuildContext context) {
    final strings = TranslateSheetStrings.of(context);
    final cubit = context.read<TranslateCubit>();
    return switch (state.status) {
      TranslateSheetStatus.initial ||
      TranslateSheetStatus.loading => const _LoadingTranslation(),
      TranslateSheetStatus.downloadingOfflineModel => _MessageWithAction(
        title: strings.downloadingModels,
        body: strings.downloadingModelsBody,
        loading: true,
      ),
      TranslateSheetStatus.success => _TranslationResultView(
        result: state.result!,
      ),
      TranslateSheetStatus.sourceLanguageRequired => _MessageWithAction(
        title: strings.sourceRequiredTitle,
        body: strings.sourceRequiredBody,
        actionLabel: strings.retry,
        onPressed: () => cubit.translate(selection),
      ),
      TranslateSheetStatus.offlineModelRequired => _MessageWithAction(
        title: strings.offlineModelTitle,
        body: strings.offlineModelBody(
          _languageName(state.failure?.sourceLanguage),
          _languageName(state.failure?.targetLanguage),
        ),
        actionLabel: strings.downloadModels,
        onPressed: () =>
            cubit.translate(selection, allowOfflineModelDownload: true),
      ),
      TranslateSheetStatus.failure => _MessageWithAction(
        title: strings.failureTitle,
        body: state.failure?.message ?? strings.failureBody,
        actionLabel: strings.retry,
        onPressed: () => cubit.translate(selection),
      ),
    };
  }
}

class _TranslationResultView extends StatelessWidget {
  const _TranslationResultView({required this.result});

  final ContextualTranslationResult result;

  @override
  Widget build(BuildContext context) {
    final strings = TranslateSheetStrings.of(context);
    final primary =
        result.translation.contextualTranslation ??
        result.translation.translatedFragment ??
        result.translation.baseTranslation ??
        result.translation.sentenceTranslation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _directionLabel(result, strings),
                style: context.text.labelMedium.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (result.reliability == ContextualTranslationReliability.offline)
              _OfflineBadge(label: strings.offlineBadge),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (primary != null)
          SelectableText(primary, style: context.text.headlineSmall),
        if (result.analysis?.lemma != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.analysis!.lemma!,
            style: context.text.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        if (result.translation.sentenceTranslation != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.sentenceTranslation,
            style: context.text.labelMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            result.translation.sentenceTranslation!,
            style: context.text.bodyMedium,
          ),
        ],
        if (result.explanation != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(result.explanation!, style: context.text.bodyMedium),
        ],
        if (result.alternatives.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.alternatives,
            style: context.text.labelMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final alternative in result.alternatives)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                alternative.translation,
                style: context.text.bodyMedium,
              ),
            ),
        ],
      ],
    );
  }
}

class _LoadingTranslation extends StatelessWidget {
  const _LoadingTranslation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _MessageWithAction extends StatelessWidget {
  const _MessageWithAction({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onPressed,
    this.loading = false,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onPressed,
            child: AppButtonLabel(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.semanticsLabel,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  final String semanticsLabel;
  final String value;
  final List<_LanguageOption> items;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    );
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: SizedBox(
        height: AppSizes.buttonHeight,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(AppIcons.chevronDown, size: AppIconSize.xs),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.colors.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<String>(
                value: item.code,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: context.text.labelSmall),
      ),
    );
  }
}

String _directionLabel(
  ContextualTranslationResult result,
  TranslateSheetStrings strings,
) {
  final source =
      _languageName(result.detectedSourceLanguage) ?? strings.autoSource;
  final target = _languageName(result.targetLanguage) ?? '';
  return target.isEmpty ? source : '$source -> $target';
}

String? _languageName(String? code) {
  if (code == null || code.isEmpty) return null;
  final normalized = code.toLowerCase().split(RegExp(r'[-_]')).first;
  for (final option in _supportedLanguageOptions) {
    if (option.code == normalized) return option.name;
  }
  return normalized.toUpperCase();
}

class _LanguageOption {
  const _LanguageOption({required this.code, required this.name});

  final String code;
  final String name;
}

final _supportedLanguageOptions = ReadflexSupportedLocales.languages
    .map(
      (language) => _LanguageOption(code: language.code, name: language.name),
    )
    .toList(growable: false);

class TranslateSheetStrings {
  const TranslateSheetStrings({
    required this.title,
    required this.sourceLabel,
    required this.targetLabel,
    required this.autoSource,
    required this.offlineBadge,
    required this.sentenceTranslation,
    required this.alternatives,
    required this.sourceRequiredTitle,
    required this.sourceRequiredBody,
    required this.offlineModelTitle,
    required this.offlineModelBody,
    required this.downloadModels,
    required this.downloadingModels,
    required this.downloadingModelsBody,
    required this.failureTitle,
    required this.failureBody,
    required this.retry,
  });

  final String title;
  final String sourceLabel;
  final String targetLabel;
  final String autoSource;
  final String offlineBadge;
  final String sentenceTranslation;
  final String alternatives;
  final String sourceRequiredTitle;
  final String sourceRequiredBody;
  final String offlineModelTitle;
  final String Function(String? source, String? target) offlineModelBody;
  final String downloadModels;
  final String downloadingModels;
  final String downloadingModelsBody;
  final String failureTitle;
  final String failureBody;
  final String retry;

  static TranslateSheetStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return switch (code) {
      'ru' => TranslateSheetStrings(
        title: 'Перевод',
        sourceLabel: 'С языка',
        targetLabel: 'На язык',
        autoSource: 'Авто',
        offlineBadge: 'Offline',
        sentenceTranslation: 'Предложение',
        alternatives: 'Варианты',
        sourceRequiredTitle: 'Нужно выбрать исходный язык',
        sourceRequiredBody:
            'Без сети исходный язык нельзя определить автоматически.',
        offlineModelTitle: 'Нужны offline-модели',
        offlineModelBody: (source, target) =>
            'Скачай модели для пары ${source ?? '?'} -> ${target ?? '?'}.',
        downloadModels: 'Скачать модели',
        downloadingModels: 'Скачиваем модели',
        downloadingModelsBody:
            'После загрузки перевод будет выполнен на устройстве.',
        failureTitle: 'Не удалось перевести',
        failureBody: 'Проверь сеть или попробуй позже.',
        retry: context.l10n.commonRetry,
      ),
      _ => TranslateSheetStrings(
        title: 'Translation',
        sourceLabel: 'From',
        targetLabel: 'To',
        autoSource: 'Auto',
        offlineBadge: 'Offline',
        sentenceTranslation: 'Sentence',
        alternatives: 'Alternatives',
        sourceRequiredTitle: 'Choose the source language',
        sourceRequiredBody:
            'Offline translation needs a concrete source language.',
        offlineModelTitle: 'Offline models required',
        offlineModelBody: (source, target) =>
            'Download models for ${source ?? '?'} -> ${target ?? '?'}.',
        downloadModels: 'Download models',
        downloadingModels: 'Downloading models',
        downloadingModelsBody:
            'Translation will run on device after the models are ready.',
        failureTitle: 'Translation failed',
        failureBody: 'Check the network connection or try again later.',
        retry: context.l10n.commonRetry,
      ),
    };
  }
}
