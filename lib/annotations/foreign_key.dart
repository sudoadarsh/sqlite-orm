class ForeignKey {
  /// The table of be referenced.
  final String table;
  /// The column to be referenced from the [table]. If null, the annotated field name will be considered.
  final String? column;
  /// To enable/ disable cascade deletion.
  final bool onDeleteCascade;

  const ForeignKey(this.table, this.column, [this.onDeleteCascade = true]);
}
