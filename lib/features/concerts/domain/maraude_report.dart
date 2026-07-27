import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';

class MaraudeReport {
  const MaraudeReport({
    required this.artist,
    required this.venueName,
    required this.concertDate,
    required this.selectedCount,
    required this.presentCount,
    required this.absentCount,
    required this.collectionSummary,
    required this.collections,
    this.actualStartAt,
    this.actualEndAt,
    this.distribution,
    this.closingComment,
  });

  factory MaraudeReport.fromConcert(
    Concert concert,
    ConcertVolunteerCounts volunteerCounts,
  ) {
    return MaraudeReport(
      artist: concert.artist,
      venueName: concert.venueName,
      concertDate: concert.date,
      actualStartAt: concert.actualStartAt,
      actualEndAt: concert.actualEndAt,
      selectedCount: volunteerCounts.selectedCount,
      presentCount: volunteerCounts.presentCount,
      absentCount: volunteerCounts.absentCount,
      collectionSummary: MaraudeCollectionSummary.fromCollections(
        concert.collections,
      ),
      collections: concert.collections,
      distribution: concert.distribution,
      closingComment: concert.closingComment,
    );
  }

  final String artist;
  final String? venueName;
  final DateTime concertDate;
  final DateTime? actualStartAt;
  final DateTime? actualEndAt;
  final int selectedCount;
  final int presentCount;
  final int absentCount;
  final MaraudeCollectionSummary collectionSummary;
  final List<MaraudeCollection> collections;
  final MaraudeDistribution? distribution;
  final String? closingComment;

  Duration? get actualDuration {
    final start = actualStartAt;
    final end = actualEndAt;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }
}

String formatMaraudeDuration(Duration? duration) {
  if (duration == null) return '—';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h ${minutes.toString().padLeft(2, '0')}';
}
