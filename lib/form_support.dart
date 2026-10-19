import 'package:flutter/material.dart';

/// Completes after the dialog has left the tree, so callers can safely dispose
/// controllers and refresh the screen beneath its closing animation.
Future<T?> showCompletedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}

class Validators {
  static String? requiredText(String? value, {int max = 150}) =>
      value == null || value.trim().isEmpty
      ? 'Ovo polje je obavezno.'
      : value.trim().length > max
      ? 'Dozvoljeno je najviše $max znakova.'
      : null;
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Unesite email u formatu ime@domena.com.';
  static String? phone(String? value) {
    final s = value?.trim() ?? '';
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?[0-9 ()-]+$').hasMatch(s) &&
            digits.length >= 7 &&
            digits.length <= 15
        ? null
        : 'Telefon mora imati 7–15 cifara; npr. +387 61 123 456.';
  }

  static String? password(String? value, {bool optional = false}) =>
      optional && (value ?? '').isEmpty
      ? null
      : (value?.length ?? 0) < 8 || (value?.length ?? 0) > 72
      ? 'Lozinka mora imati 8–72 znaka.'
      : null;
  static String? number(String? value, num min, num max) {
    final n = num.tryParse((value ?? '').replaceAll(',', '.'));
    return n == null || n < min || n > max
        ? 'Unesite broj između $min i $max.'
        : null;
  }

  static String? integer(String? value, int min, int max) {
    final n = int.tryParse(value ?? '');
    return n == null || n < min || n > max
        ? 'Unesite cijeli broj između $min i $max.'
        : null;
  }
}

class FormDialog extends StatefulWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.content,
    this.saveLabel = 'Sačuvajte',
  });
  final String title, saveLabel;
  final Widget content;
  @override
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  final keyForm = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Expanded(child: Text(widget.title)),
        IconButton(
          tooltip: 'Zatvorite',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: Form(
      key: keyForm,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: widget.content,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Nazad'),
      ),
      FilledButton(
        onPressed: () {
          if (keyForm.currentState!.validate()) Navigator.pop(context, true);
        },
        child: Text(widget.saveLabel),
      ),
    ],
  );
}
