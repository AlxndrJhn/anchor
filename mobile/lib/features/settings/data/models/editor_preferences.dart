/// Editor preferences model
class EditorPreferences {
  /// Whether to sort checklist items (checked to bottom, unchecked to top)
  final bool sortChecklistItems;

  /// Whether deleted notes burn away, on this device.
  final bool burnDeleted;

  const EditorPreferences({
    this.sortChecklistItems = true,
    this.burnDeleted = true,
  });

  EditorPreferences copyWith({bool? sortChecklistItems, bool? burnDeleted}) {
    return EditorPreferences(
      sortChecklistItems: sortChecklistItems ?? this.sortChecklistItems,
      burnDeleted: burnDeleted ?? this.burnDeleted,
    );
  }
}
