import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_report.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/distributions/presentation/maraude_distribution_form_dialog.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

typedef PdfAssetLoader = Future<ByteData> Function(String assetPath);

class MaraudeReportPdfService {
  const MaraudeReportPdfService() : _assetLoader = null;

  const MaraudeReportPdfService.withAssetLoader(this._assetLoader);

  static const regularFontAsset = 'assets/fonts/NotoSans-Regular.ttf';
  static const boldFontAsset = 'assets/fonts/NotoSans-Bold.ttf';

  final PdfAssetLoader? _assetLoader;

  Future<Uint8List> buildPdf(MaraudeReport report) async {
    final loadAsset = _assetLoader ?? rootBundle.load;
    final regularFontData = await loadAsset(regularFontAsset);
    final boldFontData = await loadAsset(boldFontAsset);
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFontData),
      bold: pw.Font.ttf(boldFontData),
    );
    final document = pw.Document(
      title: 'Bilan de maraude - ${report.artist}',
      author: 'Club Sandwich',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: theme,
        build: (context) => [
          pw.Text(
            'Bilan de maraude',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#293283'),
            ),
          ),
          pw.SizedBox(height: 24),
          _section('Général', [
            _row('Artiste', report.artist),
            _row('Salle', report.venueName ?? '-'),
            _row('Date', formatLongFrenchDate(report.concertDate)),
            _row(
              'Durée réelle',
              formatMaraudeDuration(report.actualDuration).replaceAll('—', '-'),
            ),
          ]),
          _section('Équipe', [
            _row('Bénévoles sélectionnés', '${report.selectedCount}'),
            _row('Présents', '${report.presentCount}'),
            _row('Absents', '${report.absentCount}'),
          ]),
          _section('Collecte', [
            _row('Nombre de lots', '${report.collectionSummary.lotCount}'),
            _row(
              'Poids total',
              '${_number(report.collectionSummary.totalWeightKg)} kg',
            ),
            _row(
              'Quantité totale de pièces',
              _number(report.collectionSummary.totalPieces),
            ),
            if (report.collections.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              for (final collection in report.collections)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(_collectionLine(collection)),
                ),
            ],
          ]),
          _distributionSection(report.distribution),
          _section('Commentaire de fin', [
            pw.Text(_textOrDash(report.closingComment)),
          ]),
        ],
      ),
    );

    return document.save();
  }

  Future<bool> export(MaraudeReport report) async {
    final bytes = await buildPdf(report);
    final date = report.concertDate;
    final filename =
        'bilan-maraude-${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}.pdf';
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  pw.Widget _distributionSection(MaraudeDistribution? distribution) {
    if (distribution == null) {
      return _section('Distribution', [pw.Text('Aucune distribution.')]);
    }
    return _section('Distribution', [
      _row('Lieu', _textOrDash(distribution.distributionLocation)),
      _row(
        'Bénéficiaires estimés',
        distribution.estimatedBeneficiaries?.toString() ?? '-',
      ),
      _row(
        'Repas distribués',
        distribution.distributedMeals?.toString() ?? '-',
      ),
      _row(
        'Poids restant',
        distribution.remainingWeightKg == null
            ? '-'
            : '${formatDistributionNumber(distribution.remainingWeightKg!)} kg',
      ),
      _row('Début', _dateTime(distribution.distributionStartedAt)),
      _row('Fin', _dateTime(distribution.distributionCompletedAt)),
      _row('Incident', _textOrDash(distribution.incidentComment)),
    ]);
  }

  pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#293283'),
            ),
          ),
          pw.Divider(color: PdfColor.fromHex('#DDF0F6')),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}

String _collectionLine(MaraudeCollection collection) {
  final weight = collection.weightKg == null
      ? ''
      : ' - ${_number(collection.weightKg!)} kg';
  return '${collection.category.label} : '
      '${_number(collection.quantity)} ${collection.unit.label}$weight';
}

String _dateTime(DateTime? value) {
  if (value == null) return '-';
  return formatFrenchDateTime(value).replaceFirst('\n', ' à ');
}

String _textOrDash(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? '-' : trimmed;
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}
