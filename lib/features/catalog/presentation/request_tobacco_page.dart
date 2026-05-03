import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../data/tobacco_repository.dart';
import 'providers/request_tobacco_provider.dart';

class RequestTobaccoPage extends StatelessWidget {
  const RequestTobaccoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RequestTobaccoProvider(
        TobaccoRepository(SupabaseService()),
      ),
      child: const _RequestTobaccoView(),
    );
  }
}

class _RequestTobaccoView extends StatefulWidget {
  const _RequestTobaccoView();

  @override
  State<_RequestTobaccoView> createState() => _RequestTobaccoViewState();
}

class _RequestTobaccoViewState extends State<_RequestTobaccoView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _flavorsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _flavorsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<RequestTobaccoProvider>();
    final success = await provider.submit(
      brand: _brandCtrl.text,
      name: _nameCtrl.text,
      description: _descCtrl.text,
      flavors: _flavorsCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Solicitud enviada! La revisaremos pronto.'),
          backgroundColor: Colors.green,
        ),
      );
      // Breve pausa para que el usuario vea el snackbar antes de cerrar
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } else {
      final state = provider.state;
      final message = state is RequestTobaccoError
          ? state.message
          : 'Error desconocido. Inténtalo de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      provider.reset();
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? fieldDark : fieldLight;
    const borderColor = turquoiseDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? darkNavy : navy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodyLarge?.color?.withOpacity(0.5),
            ),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: borderColor, width: 2.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2.2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.select<RequestTobaccoProvider, bool>(
      (p) => p.state is RequestTobaccoLoading,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Solicitar un Tabaco',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Si no encuentras un tabaco en nuestro catálogo, rellena este formulario y lo añadiremos lo antes posible.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildField(
                  controller: _brandCtrl,
                  label: 'Marca',
                  hint: 'Ej: Adalya, Al Fakher...',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _nameCtrl,
                  label: 'Nombre del tabaco',
                  hint: 'Ej: Love 66, Double Apple...',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _descCtrl,
                  label: 'Descripción (Opcional)',
                  hint: 'Añade detalles sobre el tabaco',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _flavorsCtrl,
                  label: 'Sabores (Opcional)',
                  hint: 'Ej: Sandía, Melón, Maracuyá...',
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: isLoading ? null : () => _handleSubmit(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Solicitar tabaco',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
