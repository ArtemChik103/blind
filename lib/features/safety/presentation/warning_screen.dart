import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/shared_prefs_service.dart';

class WarningScreen extends ConsumerStatefulWidget {
  const WarningScreen({super.key});

  @override
  ConsumerState<WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends ConsumerState<WarningScreen> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  AppStrings.warningTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Semantics(
                    child: const Text(
                      AppStrings.warningMessage,
                      style: TextStyle(color: Colors.white, fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: AppStrings.acceptTerms,
                child: CheckboxListTile(
                  value: _isAccepted,
                  onChanged: (value) {
                    setState(() {
                      _isAccepted = value ?? false;
                    });
                  },
                  title: const Text(
                    AppStrings.acceptTerms,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  checkColor: Colors.black,
                  activeColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                enabled: _isAccepted,
                child: ElevatedButton(
                  onPressed: _isAccepted
                      ? () async {
                          await ref
                              .read(riskAcceptanceProvider.notifier)
                              .accept();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/camera');
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text(AppStrings.startSonar),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
