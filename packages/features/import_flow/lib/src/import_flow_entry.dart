/// Where the Add-to-Library sheet starts.
///
/// [file] and [article] skip the menu tap, not the flow: Back from the step
/// they open still returns to the menu.
enum ImportFlowEntry {
  /// The choice between a device file and an article link.
  menu,

  /// The file path, as if the file row was tapped: the consent step while
  /// book terms are not accepted, otherwise the platform picker over the menu.
  file,

  /// The article URL step.
  article,
}
