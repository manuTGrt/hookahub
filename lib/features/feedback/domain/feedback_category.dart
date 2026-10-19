/// Categoría del mensaje de contacto o feedback.
enum FeedbackCategory {
  bug('bug', 'Error'),
  suggestion('suggestion', 'Sugerencia'),
  other('other', 'Otro');

  const FeedbackCategory(this.value, this.label);

  /// Valor textual persistido en la base de datos (Supabase).
  final String value;

  /// Etiqueta visual mostrada al usuario en la interfaz.
  final String label;
}
