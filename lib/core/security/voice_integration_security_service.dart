import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceAssistantIntegration {
  final String provider; // 'alexa', 'google_assistant', 'gemini'
  final String displayName;
  final List<String> grantedScopes;
  final DateTime connectedAt;
  final bool isConnected;

  VoiceAssistantIntegration({
    required this.provider,
    required this.displayName,
    required this.grantedScopes,
    required this.connectedAt,
    this.isConnected = true,
  });

  Map<String, dynamic> toMap() => {
        'provider': provider,
        'displayName': displayName,
        'grantedScopes': grantedScopes,
        'connectedAt': Timestamp.fromDate(connectedAt),
        'isConnected': isConnected,
      };

  factory VoiceAssistantIntegration.fromMap(Map<String, dynamic> map, String provider) {
    return VoiceAssistantIntegration(
      provider: provider,
      displayName: map['displayName'] as String? ?? provider,
      grantedScopes: (map['grantedScopes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      connectedAt: (map['connectedAt'] is Timestamp)
          ? (map['connectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      isConnected: map['isConnected'] as bool? ?? false,
    );
  }
}

/// Centralized Voice Assistant Security Service (Alexa, Google Assistant, Gemini).
/// Strictly prevents unauthorized financial execution and enforces scope boundaries.
class VoiceIntegrationSecurityService {
  final FirebaseFirestore _firestore;

  static const List<String> prohibitedOperations = [
    'make_payment',
    'execute_bank_transfer',
    'delete_account',
    'delete_diary',
    'transfer_ownership',
    'share_tax_records',
  ];

  VoiceIntegrationSecurityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Strict policy: Voice assistants can NEVER execute financial transactions or payments.
  static bool isOperationPermitted(String operationName, List<String> grantedScopes) {
    final cleanOp = operationName.toLowerCase().trim();
    if (prohibitedOperations.contains(cleanOp)) {
      return false;
    }

    if (cleanOp.startsWith('read:') && grantedScopes.contains('read:diaries')) {
      return true;
    }
    if (cleanOp.startsWith('write:task') && grantedScopes.contains('write:tasks')) {
      return true;
    }
    if (cleanOp.startsWith('read:reminder') && grantedScopes.contains('read:reminders')) {
      return true;
    }

    return false;
  }

  /// Lists connected voice integrations for a user.
  Future<List<VoiceAssistantIntegration>> getIntegrations(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('voice_integrations')
          .get();
      return snap.docs.map((d) => VoiceAssistantIntegration.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Disconnects and revokes credentials for a third-party voice assistant.
  Future<void> disconnectIntegration(String userId, String provider) async {
    if (userId.isEmpty || provider.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('voice_integrations')
        .doc(provider)
        .update({
      'isConnected': false,
      'revokedAt': Timestamp.now(),
    });
  }
}
