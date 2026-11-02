import 'package:flutter/material.dart';
import 'package:mess_manager/app/theme/app_theme.dart';

class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    required this.validator,
    this.hintText = 'Password',
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final String hintText;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(
          Icons.lock_outlined,
          color: AppTheme.textSecondary,
        ),
        suffixIcon: IconButton(
          tooltip:
              '${_obscureText ? 'Show' : 'Hide'} ${widget.hintText.toLowerCase()}',
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppTheme.textSecondary,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}
