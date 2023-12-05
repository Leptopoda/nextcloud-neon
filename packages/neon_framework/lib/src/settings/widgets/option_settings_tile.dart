import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:neon_framework/settings.dart';
import 'package:neon_framework/src/settings/models/option.dart';
import 'package:neon_framework/src/settings/widgets/settings_tile.dart';
import 'package:neon_framework/src/theme/dialog.dart';
import 'package:neon_framework/src/utils/adaptive.dart';
import 'package:neon_framework/src/widgets/adaptive_widgets/list_tile.dart';
import 'package:neon_framework/utils.dart';

@internal
class OptionSettingsTile extends InputSettingsTile {
  const OptionSettingsTile({
    required super.option,
    super.key,
  });

  @override
  Widget build(final BuildContext context) => switch (option) {
        ToggleOption() => ToggleSettingsTile(option: option as ToggleOption),
        SelectOption() => SelectSettingsTile(option: option as SelectOption),
      };
}

@internal
class ToggleSettingsTile extends InputSettingsTile<ToggleOption> {
  const ToggleSettingsTile({
    required super.option,
    super.key,
  });

  @override
  Widget build(final BuildContext context) => ValueListenableBuilder(
        valueListenable: option,
        builder: (final context, final value, final child) => SwitchListTile.adaptive(
          title: child,
          value: value,
          onChanged: option.enabled ? (final value) => option.value = value : null,
        ),
        child: Text(option.label(context)),
      );
}

@internal
class SelectSettingsTile<T> extends InputSettingsTile<SelectOption<T>> {
  const SelectSettingsTile({
    required super.option,
    this.immediateSelection = true,
    super.key,
  });

  final bool immediateSelection;

  @override
  Widget build(final BuildContext context) => ValueListenableBuilder(
        valueListenable: option,
        builder: (final context, final value, final child) {
          final valueText = option.values[value]?.call(context);
          return AdaptiveListTile.additionalInfo(
            enabled: option.enabled,
            title: child!,
            additionalInfo: valueText != null ? Text(valueText) : null,
            onTap: () async {
              assert(option.enabled, 'Option must be enabled to handle taps');
              final showCupertino = isCupertino(context);

              if (showCupertino) {
                await Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (final _) => SelectSettingsTileScreen(option: option),
                  ),
                );
              } else {
                final result = await showAdaptiveDialog<T>(
                  context: context,
                  builder: (final context) => SelectSettingsTileDialog(
                    option: option,
                    immediateSelection: immediateSelection,
                  ),
                );

                if (result != null) {
                  option.value = result;
                }
              }
            },
          );
        },
        child: Text(
          option.label(context),
        ),
      );
}

@internal
class SelectSettingsTileDialog<T> extends StatefulWidget {
  const SelectSettingsTileDialog({
    required this.option,
    this.immediateSelection = true,
    super.key,
  });

  final SelectOption<T> option;

  final bool immediateSelection;

  @override
  State<SelectSettingsTileDialog<T>> createState() => _SelectSettingsTileDialogState<T>();
}

class _SelectSettingsTileDialogState<T> extends State<SelectSettingsTileDialog<T>> {
  late T value;
  late SelectOption<T> option = widget.option;

  @override
  void initState() {
    value = option.value;

    super.initState();
  }

  void submit() => Navigator.pop(context, value);
  void cancel() => Navigator.pop(context);

  @override
  Widget build(final BuildContext context) {
    final content = SingleChildScrollView(
      child: Column(
        children: [
          ...option.values.keys.map(
            (final k) => RadioListTile(
              title: Text(
                option.values[k]!(context),
                overflow: TextOverflow.ellipsis,
              ),
              value: k,
              groupValue: value,
              onChanged: (final value) {
                setState(() {
                  this.value = value as T;
                });

                if (widget.immediateSelection) {
                  submit();
                }
              },
            ),
          ),
        ],
      ),
    );

    final actions = [
      TextButton(
        onPressed: cancel,
        child: Text(NeonLocalizations.of(context).actionClose),
      ),
      TextButton(
        onPressed: submit,
        child: Text(NeonLocalizations.of(context).actionContinue),
      ),
    ];

    return AlertDialog(
      title: Text(
        option.label(context),
      ),
      content: content,
      actions: widget.immediateSelection ? null : actions,
    );
  }
}

@internal
class SelectSettingsTileScreen<T> extends StatelessWidget {
  const SelectSettingsTileScreen({
    required this.option,
    super.key,
  });

  final SelectOption<T> option;

  @override
  Widget build(final BuildContext context) {
    final dialogTheme = NeonDialogTheme.of(context);

    final selector = ValueListenableBuilder(
      valueListenable: option,
      builder: (final context, final value, final child) => CupertinoListSection.insetGrouped(
        hasLeading: false,
        header: child,
        children: [
          ...option.values.keys.map(
            (final k) => RadioListTile.adaptive(
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(
                option.values[k]!(context),
                overflow: TextOverflow.ellipsis,
              ),
              value: k,
              groupValue: value,
              onChanged: (final value) {
                option.value = value as T;
              },
            ),
          ),
        ],
      ),
      child: Text(
        option.label(context),
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: dialogTheme.constraints,
          child: selector,
        ),
      ),
    );
  }
}