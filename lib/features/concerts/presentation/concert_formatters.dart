String formatLongFrenchDate(DateTime date) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatDatabaseTime(String value) {
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}

String formatFrenchDateTime(DateTime value) {
  final localValue = value.toLocal();
  final hours = localValue.hour.toString().padLeft(2, '0');
  final minutes = localValue.minute.toString().padLeft(2, '0');
  return '${formatLongFrenchDate(localValue)}\n$hours:$minutes';
}

String recommendedArrivalFromDatabase(String cateringClosesAt) {
  final parts = cateringClosesAt.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final totalMinutes = (hour * 60 + minute - 15) % (24 * 60);
  return '${(totalMinutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(totalMinutes % 60).toString().padLeft(2, '0')}';
}

String? validateOptionalEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  final separator = email.indexOf('@');
  final lastDot = email.lastIndexOf('.');
  if (separator <= 0 ||
      separator == email.length - 1 ||
      lastDot <= separator + 1 ||
      lastDot == email.length - 1) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
}
