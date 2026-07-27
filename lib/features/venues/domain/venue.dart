class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.publicAddressLine1,
    required this.postalCode,
    required this.city,
    this.publicAddressLine2,
    this.artistEntranceAddressLine1,
    this.artistEntranceAddressLine2,
    this.artistEntrancePostalCode,
    this.artistEntranceCity,
    this.accessInstructions,
  });

  final String id;
  final String name;
  final String publicAddressLine1;
  final String? publicAddressLine2;
  final String postalCode;
  final String city;
  final String? artistEntranceAddressLine1;
  final String? artistEntranceAddressLine2;
  final String? artistEntrancePostalCode;
  final String? artistEntranceCity;
  final String? accessInstructions;

  String get formattedAddress {
    final line2 = publicAddressLine2;
    return [
      publicAddressLine1,
      if (line2 != null && line2.trim().isNotEmpty) line2,
      '$postalCode $city',
    ].join(', ');
  }

  String? get formattedArtistEntrance {
    final addressLine1 = artistEntranceAddressLine1?.trim();
    if (addressLine1 == null || addressLine1.isEmpty) return null;
    final addressLine2 = artistEntranceAddressLine2?.trim();
    final postalCode = artistEntrancePostalCode?.trim();
    final city = artistEntranceCity?.trim();
    return [
      addressLine1,
      if (addressLine2 != null && addressLine2.isNotEmpty) addressLine2,
      [
        if (postalCode != null && postalCode.isNotEmpty) postalCode,
        if (city != null && city.isNotEmpty) city,
      ].join(' '),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      publicAddressLine1: json['public_address_line1'] as String,
      publicAddressLine2: json['public_address_line2'] as String?,
      postalCode: json['postal_code'] as String,
      city: json['city'] as String,
      artistEntranceAddressLine1: _accessDetail(
        json,
        'artist_entrance_address_line1',
      ),
      artistEntranceAddressLine2: _accessDetail(
        json,
        'artist_entrance_address_line2',
      ),
      artistEntrancePostalCode: _accessDetail(
        json,
        'artist_entrance_postal_code',
      ),
      artistEntranceCity: _accessDetail(json, 'artist_entrance_city'),
      accessInstructions: _accessDetail(json, 'access_instructions'),
    );
  }
}

String? _accessDetail(Map<String, dynamic> json, String key) {
  final relation = json['access_details'];
  if (relation is Map<String, dynamic>) return relation[key] as String?;
  if (relation is List<dynamic> && relation.isNotEmpty) {
    return (relation.first as Map<String, dynamic>)[key] as String?;
  }
  return null;
}
