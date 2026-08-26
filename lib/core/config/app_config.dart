import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide configuration controlled by an administrator directly from the
/// Firestore console. Lives in `config/app` (collection `config`, document
/// `app`). Clients only ever READ this document; it is edited by hand in the
/// Firebase console.
///
/// Example document:
/// ```
/// config (collection)
///   └── app (document)
///        ├── maintenanceMode: false
///        ├── maintenanceTitle: "We'll be right back"
///        └── maintenanceMessage: "We are applying some updates."
/// ```
class AppConfig {
  final bool maintenanceMode;
  final String? maintenanceTitle;
  final String? maintenanceMessage;

  const AppConfig({
    this.maintenanceMode = false,
    this.maintenanceTitle,
    this.maintenanceMessage,
  });

  /// Safe default used when the document does not exist yet or cannot be read.
  static const AppConfig defaults = AppConfig();

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return AppConfig(
      maintenanceMode: data['maintenanceMode'] == true,
      maintenanceTitle: (data['maintenanceTitle'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['maintenanceTitle'] as String).trim(),
      maintenanceMessage:
          (data['maintenanceMessage'] as String?)?.trim().isEmpty ?? true
              ? null
              : (data['maintenanceMessage'] as String).trim(),
    );
  }
}

/// Streams `config/app` in real-time so toggling `maintenanceMode` in the
/// Firebase console reflects in every running client within seconds.
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .snapshots()
      .map((doc) => AppConfig.fromMap(doc.data()));
});
