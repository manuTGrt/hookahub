import 'package:flutter/material.dart';
import '../core/models/mix.dart';

/// Tarjeta reutilizable de mezcla con el mismo estilo que las tarjetas
/// de `CommunityPage`, pero con acciones configurables por props.
class MixCard extends StatelessWidget {
  const MixCard({
    super.key,
    required this.mix,
    required this.isFavorite,
    required this.onFavoriteTap,
    this.onShare,
    this.trailingIcon,
    this.onTrailingTap,
    this.time,
    this.onTap,
    this.isOwned = false,
    this.onEdit,
    this.onDelete,
  });

  final Mix mix;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onShare;
  final IconData? trailingIcon; // p. ej., bookmark/pin/delete
  final VoidCallback? onTrailingTap;
  final String? time; // texto auxiliar como "2h", "1d" para Comunidad
  final VoidCallback? onTap;
  final bool isOwned; // Si es true, muestra menú de editar/eliminar
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final mixColor = mix.color;
    String _toTitleCaseSpaces(String input) {
      // Convierte cada palabra a Title Case preservando los espacios originales.
      if (input.trim().isEmpty) return input.trim();
      final buffer = StringBuffer();
      bool capitalizeNext = true;
      for (var i = 0; i < input.length; i++) {
        final ch = input[i];
        final isWhitespace = ch.trim().isEmpty;
        if (isWhitespace) {
          buffer.write(ch); // preserva espacios tal cual
          capitalizeNext = true;
        } else {
          buffer.write(capitalizeNext ? ch.toUpperCase() : ch.toLowerCase());
          capitalizeNext = false;
        }
      }
      return buffer.toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: mixColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mixColor.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: mixColor,
                    child: Text(
                      mix.author.isNotEmpty ? mix.author[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mix.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'por ${mix.author}${time != null ? ' • $time' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (trailingIcon != null)
                    IconButton(
                      icon: Icon(trailingIcon, color: mixColor),
                      onPressed: onTrailingTap,
                    ),
                  if (isOwned && onEdit != null && onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: mixColor),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit!();
                        } else if (value == 'delete') {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tabacos:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.color
                          ?.withOpacity(0.8),
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: mix.ingredients
                    .map(
                      (ingredient) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: mixColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _toTitleCaseSpaces(ingredient),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // El bloque de rating ocupa el espacio restante.
                  Expanded(
                    child: Row(
                      children: () {
                        final hasRating = (mix.reviews > 0) && (mix.rating > 0);
                        if (hasRating) {
                          return [
                            Icon(Icons.star, size: 16, color: mixColor),
                            const SizedBox(width: 4),
                            Text(
                              mix.rating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mix.reviews == 1 ? '(1 reseña)' : '(${mix.reviews} reseñas)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5),
                                    ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ];
                        } else {
                          return [
                            Icon(Icons.star_border, size: 16, color: mixColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Sin valoraciones',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.6),
                                    ),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ];
                        }
                      }(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Acciones (tamaño inflexible)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: mixColor,
                        ),
                        onPressed: onFavoriteTap,
                      ),
                      if (onShare != null)
                        IconButton(
                          icon: Icon(Icons.share_outlined, size: 16, color: mixColor),
                          onPressed: onShare,
                        ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      ),
    );
  }
}
