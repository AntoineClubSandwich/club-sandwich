class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.publicAddressLine1,
    required this.postalCode,
    required this.city,
    this.publicAddressLine2,
  });

  final String id;
  final String name;
  final String publicAddressLine1;
  final String? publicAddressLine2;
  final String postalCode;
  final String city;

  String get formattedAddress {
    final line2 = publicAddressLine2;
    return [
      publicAddressLine1,
      if (line2 != null && line2.trim().isNotEmpty) line2,
      '$postalCode $city',
    ].join(', ');
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      publicAddressLine1: json['public_address_line1'] as String,
      publicAddressLine2: json['public_address_line2'] as String?,
      postalCode: json['postal_code'] as String,
      city: json['city'] as String,
    );
  }
}
