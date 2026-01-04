import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../core/models/mix.dart';
import '../../../core/models/tobacco.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../catalog/data/tobacco_repository.dart';
import '../../catalog/presentation/providers/tobacco_lookup_provider.dart';
import 'community_provider.dart';

// Utilidad: convierte cada palabra a "Title Case" (primera mayúscula, resto minúsculas).
String titleCase(String input) {
  if (input.isEmpty) return input;
  final words = input.trim().split(RegExp(r"\s+")).map((w) {
    final parts = w.split('-');
    final cased = parts.map((p) {
      if (p.isEmpty) return p;
      final lower = p.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join('-');
    return cased;
  }).join(' ');
  return words;
}

/// Página para crear o editar una mezcla de la comunidad.
/// Si [mixToEdit] es no nulo, funciona en modo edición.
/// Devuelve un [Mix] vía `Navigator.pop(context, mix)` si la creación/edición es válida.
class CreateMixPage extends StatefulWidget {
  const CreateMixPage({super.key, required this.currentUser, this.mixToEdit});
  final String currentUser; // Autor de la mezcla
  final Mix? mixToEdit; // Si no es null, la página funciona en modo edición

  @override
  State<CreateMixPage> createState() => _CreateMixPageState();
}

class _CreateMixPageState extends State<CreateMixPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _nameError;
  String? _descError;
  bool _loadingExisting = false; // para cargar datos en modo edición

  // Lista seleccionada gestionada localmente; los candidatos vienen desde TobaccoLookupProvider

  final List<_SelectedIngredient> _ingredients = [];
  Tobacco? _pendingSelection; // tabaco elegido en autocompletar aún no añadido

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      // Usar addPostFrameCallback para asegurar que el contexto esté disponible
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadExistingMix();
        }
      });
    }
  }

  bool get _isEdit => widget.mixToEdit != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final ing in _ingredients) {
      ing.percentCtrl.dispose();
    }
    super.dispose();
  }

  bool get _canAddMore => _ingredients.length < 4;
  bool get _hasMinIngredients => _ingredients.length >= 2;

  double get _totalPercent => _ingredients.fold<double>(0, (a, b) => a + (double.tryParse(b.percentCtrl.text) ?? 0));

  bool get _percentagesValid {
    if (_ingredients.isEmpty) return false;
    for (final ing in _ingredients) {
      final v = double.tryParse(ing.percentCtrl.text) ?? 0;
      if (v <= 0) return false;
    }
    // Requiere que sumen 100 (tolerancia pequeña)
    return (_totalPercent - 100).abs() < 0.5; // tolerancia 0.5%
  }

  // El botón se habilita solo según ingredientes y porcentajes, NO por título/descr.
  bool get _canPressCreate => _hasMinIngredients && _percentagesValid && _ingredients.length <= 4;

  /// Carga los datos de la mezcla existente en modo edición
  Future<void> _loadExistingMix() async {
    final mix = widget.mixToEdit!;
    setState(() => _loadingExisting = true);
    
    try {
      _nameCtrl.text = mix.name;
      
      // Cargar detalles desde repositorio para obtener descripción y componentes
      final repo = context.read<CommunityProvider>().repository;
      final details = await repo.fetchMixDetails(mix.id);
      
      if (details == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar los detalles de la mezcla')),
          );
          setState(() => _loadingExisting = false);
        }
        return;
      }
      
      final desc = details['description'] as String?;
      final comps = (details['components'] as List?) ?? [];
      
      if (mounted) {
        _descCtrl.text = desc ?? '';
      }

      // Resolver cada componente a Tobacco (si existe en catálogo) o crear placeholder
      final tobRepo = TobaccoRepository(SupabaseService());
      final List<_SelectedIngredient> loaded = [];
      
      for (final c in comps) {
        final name = c['tobacco_name'] as String;
        final brand = c['brand'] as String;
        final percent = (c['percentage'] as num).toDouble();
        
        Tobacco? t;
        try {
          t = await tobRepo.findByNameAndBrand(name: name, brand: brand);
        } catch (_) {
          // Si no se encuentra en catálogo, crear placeholder
        }
        
        t ??= Tobacco(
          id: 'edit-${name.toLowerCase().replaceAll(' ', '-')}-${brand.toLowerCase().replaceAll(' ', '-')}',
          name: name,
          brand: brand,
          flavors: const [],
          rating: 0,
          reviews: 0,
        );
        
        final sel = _SelectedIngredient(tobacco: t);
        // Formatear el porcentaje sin decimales si es entero
        sel.percentCtrl.text = percent.truncateToDouble() == percent 
            ? percent.toStringAsFixed(0) 
            : percent.toStringAsFixed(1);
        loaded.add(sel);
      }
      
      if (mounted) {
        setState(() {
          _ingredients
            ..clear()
            ..addAll(loaded);
          _loadingExisting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingExisting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  void _addIngredient(Tobacco t) {
    if (!_canAddMore) return;
    if (_ingredients.any((e) => e.tobacco.id == t.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ese tabaco ya está en la mezcla.')));
      return;
    }
    setState(() {
      _ingredients.add(_SelectedIngredient(tobacco: t));
      _pendingSelection = null;
    });
  }

  void _removeIngredient(String id) {
    setState(() {
      _ingredients.removeWhere((e) => e.tobacco.id == id);
    });
  }

  Future<void> _handleCreate() async {
    // Validaciones diferidas de título y descripción.
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    String? nameErr;
    String? descErr;
    if (name.isEmpty) {
      nameErr = 'El título es obligatorio';
    } else if (name.length < 3) {
      nameErr = 'Mínimo 3 caracteres';
    }
    if (desc.isEmpty) {
      descErr = 'La descripción es obligatoria';
    }
    setState(() {
      _nameError = nameErr;
      _descError = descErr;
    });
    if (nameErr != null || descErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa los errores antes de crear.')));
      return;
    }
    if (!_canPressCreate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrige ingredientes/porcentajes.')));
      return;
    }

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener el usuario autenticado
      final supabaseService = SupabaseService();
      final currentUser = supabaseService.client.auth.currentUser;
      
      if (currentUser == null) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión para crear una mezcla.')),
        );
        return;
      }

      // Preparar los componentes para el provider con colores distintos por ingrediente
      // Paleta fija (coincide con los tonos usados en MixDetailPage)
      const paletteHex = [
        '#87DAD2', '#4E9891', '#1AA6B8', '#245F5C',
        '#6FC2B9', '#3A8780', '#0F96A6', '#0A8EA0'
      ];
      final components = _ingredients.asMap().entries.map((entry) {
        final i = entry.key;
        final ing = entry.value;
        return {
          'tobacco_name': ing.tobacco.name,
          'brand': ing.tobacco.brand,
          'percentage': double.parse(ing.percentCtrl.text),
          'color': paletteHex[i % paletteHex.length],
        };
      }).toList();

      final communityProvider = context.read<CommunityProvider>();
      Mix? resultMix;
      
      if (_isEdit) {
        // Modo edición: actualizar mezcla existente
        resultMix = await communityProvider.editMix(
          mixId: widget.mixToEdit!.id,
          name: name,
          description: desc,
          components: components,
        );
      } else {
        // Modo creación: crear nueva mezcla
        resultMix = await communityProvider.createMix(
          name: name,
          description: desc,
          components: components,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo de carga

      if (resultMix != null) {
        // Retornar a la pantalla anterior con la mezcla creada/editada
        Navigator.of(context).pop(resultMix);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? '¡Mezcla actualizada exitosamente!' : '¡Mezcla creada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Error al actualizar la mezcla' : 'Error al crear la mezcla'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit 
              ? 'Error al actualizar la mezcla: ${e.toString()}' 
              : 'Error al crear la mezcla: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Campo de texto estilizado acorde a los usados en EditProfilePage.
  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark; // mismo color que perfil
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textAlignVertical: maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: borderTurquoise,
              )
            : null,
        hintText: hint,
        errorText: errorText,
        hintStyle: TextStyle(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
        ),
        filled: true,
        fillColor: isDark ? fieldDark : fieldLight,
        contentPadding: EdgeInsets.fromLTRB( icon != null ? 0 : 16, 14, 16, 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Si estamos en modo edición y cargando datos, mostrar solo indicador de carga
    if (_isEdit && _loadingExisting) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: 'Editar Mezcla',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Cargando mezcla...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: _isEdit ? 'Editar Mezcla' : 'Crear Mezcla',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Etiqueta y campo: Título de la mezcla
                      Text(
                        'Título de la mezcla',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? darkNavy : navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _styledField(
                        controller: _nameCtrl,
                        hint: 'Introduce el título',
                        errorText: _nameError,
                        onChanged: (_) {
                          if (_nameError != null) setState(() => _nameError = null);
                        },
                      ),
                      const SizedBox(height: 24),
                      // Etiqueta y campo: Descripción
                      Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? darkNavy : navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _styledField(
                        controller: _descCtrl,
                        hint: 'Añade una descripción para tu mezcla',
                        errorText: _descError,
                        maxLines: 3,
                        onChanged: (_) {
                          if (_descError != null) setState(() => _descError = null);
                        },
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tabacos (2 - 4)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? darkNavy : navy,
                              ),
                            ),
                          ),
                          if (_ingredients.isNotEmpty)
                            Text('Total: ${_totalPercent.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _percentagesValid ? theme.colorScheme.primary : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ChangeNotifierProvider(
                        create: (_) => TobaccoLookupProvider(
                          TobaccoRepository(SupabaseService()),
                          autoLoad: !_isEdit, // No cargar automáticamente si estamos editando
                        ),
                        child: Consumer<TobaccoLookupProvider>(
                          builder: (context, lookup, _) {
                            final existingIds = _ingredients.map((e) => e.tobacco.id).toSet();
                            final items = lookup.items.where((t) => !existingIds.contains(t.id)).toList();
                            return _IngredientSelector(
                              items: items,
                              enabled: _canAddMore,
                              hasMore: lookup.hasMore,
                              isLoading: lookup.isLoading,
                              onQueryChanged: lookup.setQuery,
                              onLoadMore: lookup.loadMore,
                              onSelected: (t) {
                                _pendingSelection = t;
                                setState(() {});
                              },
                              pending: _pendingSelection,
                              onAdd: () {
                                if (_pendingSelection != null) _addIngredient(_pendingSelection!);
                              },
                            );
                          },
                        ),
                      ),
                      if (!_canAddMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Máximo de 4 tabacos alcanzado',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                        ),
                      const SizedBox(height: 16),
                      if (_ingredients.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Selecciona al menos dos tabacos y asigna porcentajes que sumen 100%.',
                                    style: theme.textTheme.bodyMedium),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (final ing in _ingredients)
                              _SlidableIngredientRow(
                                key: ValueKey('slide-${ing.tobacco.id}'),
                                onDelete: () => _removeIngredient(ing.tobacco.id),
                                child: _IngredientRow(
                                  ingredient: ing,
                                  onChanged: () => setState(() {}),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(_isEdit ? 'Guardar cambios' : 'Crear mezcla'),
                          onPressed: _canPressCreate ? _handleCreate : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Los disponibles ahora los filtra el Consumer directamente desde el provider
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.title});
  final VoidCallback onBack;
  final String title;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Atrás',
            ),
          ),
          Center(
            child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _IngredientSelector extends StatefulWidget {
  const _IngredientSelector({
    required this.items,
    required this.onSelected,
    required this.onAdd,
    required this.enabled,
    required this.onQueryChanged,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoading,
    this.pending,
  });
  final List<Tobacco> items;
  final ValueChanged<Tobacco> onSelected;
  final VoidCallback onAdd;
  final bool enabled;
  final Tobacco? pending;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function({bool resetCursor}) onLoadMore;
  final bool hasMore;
  final bool isLoading;

  @override
  State<_IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends State<_IngredientSelector> {
  final _textCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _expanded = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onTextChanged() {
    if (!mounted) return;
    final q = _textCtrl.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) widget.onQueryChanged(q);
    });
  }

  @override
  void didUpdateWidget(covariant _IngredientSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantener el texto de búsqueda; no lo limpiamos al cambiar pending
  }

  void _onScroll() {
    if (!mounted || !widget.enabled || !widget.hasMore || widget.isLoading) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 120) {
      // cargar más al acercarse al final
      widget.onLoadMore(resetCursor: false);
    }
  }

  void _toggleExpanded() {
    if (!mounted || !widget.enabled) return;
    
    // Si estamos abriendo el desplegable y no hay items ni está cargando,
    // cargar datos iniciales (útil cuando autoLoad=false en el provider)
    if (!_expanded && widget.items.isEmpty && !widget.isLoading) {
      widget.onLoadMore(resetCursor: true);
    }
    
    setState(() {
      _expanded = !_expanded;
    });
    
    // Resetear scroll al abrir el desplegable
    if (_expanded && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleAdd() {
    if (!mounted) return;
    widget.onAdd();
    setState(() {
      _expanded = false;
    });
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark ? fieldDark : fieldLight,
        border: Border.all(
          color: turquoiseDark,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _textCtrl,
                  enabled: widget.enabled,
                  onTap: _toggleExpanded,
                ),
              ),
              const SizedBox(width: 12),
              _ModernAddButton(
                enabled: widget.enabled && widget.pending != null,
                onPressed: widget.enabled && widget.pending != null ? _handleAdd : null,
                tooltip: widget.enabled ? 'Añadir tabaco' : 'Máximo alcanzado',
              ),
            ],
          ),
          if (_expanded && widget.enabled)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.only(top: 12),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: isDark ? fieldDark : fieldLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: turquoiseDark,
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.items.length + ((widget.hasMore || widget.isLoading) ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                    itemBuilder: (context, i) {
                      final isLoaderTile = i >= widget.items.length;
                      if (isLoaderTile) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: widget.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    widget.hasMore ? 'Cargar más…' : 'No hay más resultados',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                    ),
                                  ),
                          ),
                        );
                      }
                      final t = widget.items[i];
                      final selected = widget.pending?.id == t.id;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onSelected(t);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: selected
                                ? BoxDecoration(
                                    color: turquoise.withOpacity(0.1),
                                    border: const Border(
                                      left: BorderSide(
                                        color: turquoiseDark,
                                        width: 3,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleCase(t.name),
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                          color: selected ? turquoiseDark : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        titleCase(t.brand),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: turquoiseDark,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_expanded && widget.enabled && widget.items.isEmpty && !widget.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Sin resultados',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                ),
              ),
            ),
          if (widget.pending != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: turquoise.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: turquoiseDark,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: turquoiseDark,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seleccionado: ${titleCase(widget.pending!.name)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: turquoiseDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModernAddButton extends StatelessWidget {
  const _ModernAddButton({
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });
  
  final bool enabled;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [
                    isDark ? darkTurquoise : turquoise,
                    isDark ? darkTurquoise.withOpacity(0.8) : turquoiseDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : theme.disabledColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (isDark ? darkTurquoise : turquoise).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: enabled ? 1.0 : 0.9,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    enabled ? Icons.add_rounded : Icons.block,
                    key: ValueKey(enabled),
                    color: enabled ? Colors.white : theme.disabledColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.enabled, required this.onTap});
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.search_rounded,
          color: turquoiseDark,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            return value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: turquoiseDark.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: enabled ? () {
                      controller.clear();
                      FocusScope.of(context).requestFocus(FocusNode());
                    } : null,
                  )
                : const SizedBox.shrink();
          },
        ),
        hintText: 'Buscar tabaco por nombre o marca...',
        hintStyle: TextStyle(
          color: (theme.textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
        ),
        filled: true,
        fillColor: isDark ? fieldDark : fieldLight,
        contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 2.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: turquoiseDark.withOpacity(0.5), width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        hintText: '%',
        filled: true,
        fillColor: isDark ? fieldDark : fieldLight,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 2.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.onChanged});
  final _SelectedIngredient ingredient;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turquoiseDark, width: 1.5),
        color: isDark ? fieldDark : fieldLight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleCase(ingredient.tobacco.name),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text(titleCase(ingredient.tobacco.brand),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    )),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: _PercentField(controller: ingredient.percentCtrl, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Fila deslizable personalizada: al arrastrar hacia la izquierda se revela el botón de borrar y
/// puede quedar parcialmente abierta. Al completar el deslizamiento extremo también se borra.
class _SlidableIngredientRow extends StatefulWidget {
  const _SlidableIngredientRow({super.key, required this.child, required this.onDelete});
  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SlidableIngredientRow> createState() => _SlidableIngredientRowState();
}

class _SlidableIngredientRowState extends State<_SlidableIngredientRow> with SingleTickerProviderStateMixin {
  // Anchura del área de acción (botón borrar)
  static const double _actionWidth = 76; // ancho suficiente para icono + margen
  late AnimationController _controller; // controla animación de arrastre
  late Animation<double> _animation;
  double _dragExtent = 0; // negativo hacia la izquierda
  bool _closing = false;
  double _maxSlideWidth = 0; // ancho total disponible para permitir swipe completo

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    setState(() {
      _dragExtent += details.delta.dx;
      // Limitamos el arrastre solo hacia la izquierda y hasta -_actionWidth
      if (_dragExtent > 0) _dragExtent = 0;
      final limit = _maxSlideWidth > 0 ? -_maxSlideWidth : -_actionWidth;
      if (_dragExtent < limit) _dragExtent = limit;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    // Si la velocidad es muy negativa, borrar directamente.
    if (velocity < -800) {
      _triggerDelete();
      return;
    }
    // Si se ha deslizado casi hasta el final del ancho, borrar.
    if (_maxSlideWidth > 0 && _dragExtent <= -_maxSlideWidth * 0.9) {
      _triggerDelete();
      return;
    }
    // Decide si queda abierto (mostrar botón) o se cierra (solo zona de acción inicial).
    final openThreshold = -_actionWidth * 0.35; // ~35% para quedar abierto
    if (_dragExtent <= openThreshold) {
      // Snap a abierto (-_actionWidth) usando animación si no llegó al umbral de borrado.
      _animateTo(-_actionWidth);
    } else {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    final start = _dragExtent;
    final delta = target - start;
    if (delta == 0) return;
    _controller.reset();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.addListener(() {
      setState(() {
        _dragExtent = start + delta * _animation.value;
      });
    });
    _controller.forward().whenComplete(() {
      _controller.removeListener(() {}); // listener anónimo no removible -> noop seguro
    });
  }

  void _triggerDelete() {
    if (_closing) return;
    _closing = true;
    // Animación rápida hacia fuera antes de eliminar.
    final target = _maxSlideWidth > 0 ? -_maxSlideWidth : -(_actionWidth + 40);
    _animateTo(target);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) widget.onDelete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (-_dragExtent / _actionWidth).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxSlideWidth = constraints.maxWidth; // actualizar cada build
        return GestureDetector(
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Stack(
            children: [
              // Fondo con botón borrar
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: progress == 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.only(left: 12),
                    child: Opacity(
                      opacity: progress,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: _actionWidth,
                          height: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Material(
                              color: theme.colorScheme.error,
                              child: InkWell(
                                onTap: _triggerDelete,
                                child: const Center(
                                  child: Tooltip(
                                    message: 'Borrar',
                                    child: Icon(Icons.delete_outline, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Contenido desplazable
              Transform.translate(
                offset: Offset(_dragExtent, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Colors.transparent,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _SelectedIngredient {
  _SelectedIngredient({required this.tobacco}) : percentCtrl = TextEditingController(text: _defaultPercent.toStringAsFixed(0));
  final Tobacco tobacco;
  final TextEditingController percentCtrl;

  static double get _defaultPercent => 25; // valor inicial equilibrado
}
