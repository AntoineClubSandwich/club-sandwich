import 'package:club_sandwich/features/concerts/presentation/maraude_report_pdf_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maraudeReportPdfServiceProvider = Provider<MaraudeReportPdfService>(
  (ref) => const MaraudeReportPdfService(),
);
