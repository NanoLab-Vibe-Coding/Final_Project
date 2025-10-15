// lib/domain/models/card_model.dart

class CardItem {
  final String id;
  final String label;
  final String speak;
  final bool sos;
  final String? call;
  final String? sms;

  CardItem({
    required this.id,
    required this.label,
    required this.speak,
    this.sos = false,
    this.call,
    this.sms,
  });

  factory CardItem.fromJson(Map<String, dynamic> j) => CardItem(
        id: j['id'] as String,
        label: j['label'] as String,
        speak: j['speak'] as String,
        sos: (j['sos'] ?? false) as bool,
        call: j['call'] as String?,
        sms: j['sms'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'speak': speak,
        'sos': sos,
        'call': call,
        'sms': sms,
      };
}

