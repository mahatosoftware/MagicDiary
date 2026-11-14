enum CustomFieldType {
  text,
  number,
  currency,
  date,
  boolean,
  dropdown,
  multiline,
  attachment,
  rating,
}

class CustomFieldDefinition {
  final String key;
  final String label;
  final CustomFieldType type;
  final bool isRequired;
  final bool isSensitive;
  final String? defaultValue;
  final List<String> dropdownOptions;
  final String? placeholder;
  final String? unit;

  const CustomFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.isSensitive = false,
    this.defaultValue,
    this.dropdownOptions = const [],
    this.placeholder,
    this.unit,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'isRequired': isRequired,
        'isSensitive': isSensitive,
        'defaultValue': defaultValue,
        'dropdownOptions': dropdownOptions,
        'placeholder': placeholder,
        'unit': unit,
      };

  factory CustomFieldDefinition.fromJson(Map<String, dynamic> json) {
    return CustomFieldDefinition(
      key: json['key'] as String,
      label: json['label'] as String,
      type: CustomFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CustomFieldType.text,
      ),
      isRequired: json['isRequired'] as bool? ?? false,
      isSensitive: json['isSensitive'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      dropdownOptions: (json['dropdownOptions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      placeholder: json['placeholder'] as String?,
      unit: json['unit'] as String?,
    );
  }
}
