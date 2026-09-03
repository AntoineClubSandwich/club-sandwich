import 'dart:math' as math;

import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/encounters/data/encounter_providers.dart';
import 'package:club_sandwich/features/encounters/domain/encounter_cluster.dart';
import 'package:club_sandwich/features/encounters/domain/maraude_encounter.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

enum EncounterMapMode { points, clusters, heatmap }

enum _PeriodPreset { today, sevenDays, thirtyDays, year, custom }

class EncounterMapScreen extends ConsumerStatefulWidget {
  const EncounterMapScreen({super.key});

  @override
  ConsumerState<EncounterMapScreen> createState() => _EncounterMapScreenState();
}

class _EncounterMapScreenState extends ConsumerState<EncounterMapScreen> {
  final _mapController = MapController();
  var _mode = EncounterMapMode.points;
  var _preset = _PeriodPreset.thirtyDays;
  late DateTimeRange _customRange;
  String? _maraudeId;
  String? _venueId;
  String? _creatorId;
  var _zoom = 12.0;
  var _mapReady = false;
  String? _lastFitSignature;

  @override
  void initState() {
    super.initState();
    final today = _day(DateTime.now());
    _customRange = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }

  EncounterMapPeriod get _period {
    final today = _day(DateTime.now());
    return switch (_preset) {
      _PeriodPreset.today => EncounterMapPeriod(
        from: today,
        to: today.add(const Duration(days: 1)),
      ),
      _PeriodPreset.sevenDays => EncounterMapPeriod(
        from: today.subtract(const Duration(days: 6)),
        to: today.add(const Duration(days: 1)),
      ),
      _PeriodPreset.thirtyDays => EncounterMapPeriod(
        from: today.subtract(const Duration(days: 29)),
        to: today.add(const Duration(days: 1)),
      ),
      _PeriodPreset.year => EncounterMapPeriod(
        from: DateTime(today.year),
        to: DateTime(today.year + 1),
      ),
      _PeriodPreset.custom => EncounterMapPeriod(
        from: _day(_customRange.start),
        to: _day(_customRange.end).add(const Duration(days: 1)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = adminEncounterMapProvider(_period);
    final encounters = ref.watch(mapProvider);
    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.lg,
          ),
          child: encounters.when(
            loading: () => const AppLoadingState(
              label: 'Chargement de la carte des rencontres',
            ),
            error: (_, _) => AppErrorState(
              message: 'Impossible de charger la carte des rencontres.',
              onRetry: () => ref.invalidate(mapProvider),
            ),
            data: _buildContent,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<MaraudeEncounter> allEncounters) {
    final filtered = allEncounters
        .where((item) {
          return (_maraudeId == null || item.maraudeId == _maraudeId) &&
              (_venueId == null || item.venueId == _venueId) &&
              (_creatorId == null || item.createdBy == _creatorId);
        })
        .toList(growable: false);
    final summary = EncounterMapSummary.from(filtered);
    _scheduleFit(filtered);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Carte des rencontres', style: DsTypography.h2),
                      const SizedBox(height: 2),
                      Text(
                        'Visualisez les zones de distribution sans identifier les bénéficiaires.',
                        style: DsTypography.body.copyWith(
                          color: Theme.of(
                            context,
                          ).extension<DsTokens>()!.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (compact)
                  IconButton.filledTonal(
                    tooltip: 'Filtres',
                    onPressed: () => _showMobileFilters(allEncounters),
                    icon: const Icon(Icons.tune),
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            if (!compact)
              _FiltersBar(
                items: allEncounters,
                preset: _preset,
                maraudeId: _maraudeId,
                venueId: _venueId,
                creatorId: _creatorId,
                onPresetChanged: _changePreset,
                onMaraudeChanged: (value) =>
                    _changeFilter(() => _maraudeId = value),
                onVenueChanged: (value) =>
                    _changeFilter(() => _venueId = value),
                onCreatorChanged: (value) =>
                    _changeFilter(() => _creatorId = value),
              ),
            if (!compact) const SizedBox(height: DsSpacing.md),
            _KpiRow(summary: summary, compact: compact),
            const SizedBox(height: DsSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildMap(filtered)),
                    Positioned(
                      top: DsSpacing.md,
                      right: DsSpacing.md,
                      child: _ModeSelector(
                        mode: _mode,
                        compact: compact,
                        onChanged: (value) => setState(() => _mode = value),
                      ),
                    ),
                    if (filtered.isEmpty) const Center(child: _MapEmptyState()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(List<MaraudeEncounter> encounters) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(48.8566, 2.3522),
        initialZoom: 12,
        minZoom: 5,
        maxZoom: 19,
        onMapReady: () {
          _mapReady = true;
          _lastFitSignature = null;
          _scheduleFit(encounters);
        },
        onPositionChanged: (camera, _) {
          if ((camera.zoom - _zoom).abs() >= 0.25 && mounted) {
            setState(() => _zoom = camera.zoom);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.clubsandwich.app',
          maxNativeZoom: 19,
        ),
        if (_mode == EncounterMapMode.heatmap)
          CircleLayer(
            circles: [
              for (final item in encounters)
                CircleMarker(
                  point: LatLng(item.latitude, item.longitude),
                  radius: 34,
                  useRadiusInMeter: false,
                  color: const Color(0xFFEA5133).withValues(alpha: 0.13),
                  borderStrokeWidth: 0,
                ),
            ],
          ),
        if (_mode == EncounterMapMode.points)
          MarkerLayer(markers: _pointMarkers(encounters)),
        if (_mode == EncounterMapMode.clusters)
          MarkerLayer(markers: _clusterMarkers(encounters)),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Marker> _pointMarkers(List<MaraudeEncounter> encounters) => [
    for (final item in encounters)
      Marker(
        point: LatLng(item.latitude, item.longitude),
        width: 38,
        height: 38,
        child: Semantics(
          button: true,
          label: 'Rencontre ${_formatDateTime(item.createdAt)}',
          child: InkWell(
            onTap: () => _showEncounter(item),
            customBorder: const CircleBorder(),
            child: const _EncounterMarker(),
          ),
        ),
      ),
  ];

  List<Marker> _clusterMarkers(List<MaraudeEncounter> encounters) => [
    for (final cluster in clusterEncounters(encounters, _zoom))
      Marker(
        point: LatLng(cluster.latitude, cluster.longitude),
        width: 48,
        height: 48,
        child: cluster.encounters.length == 1
            ? InkWell(
                onTap: () => _showEncounter(cluster.encounters.single),
                customBorder: const CircleBorder(),
                child: const _EncounterMarker(),
              )
            : InkWell(
                onTap: () {
                  _mapController.move(
                    LatLng(cluster.latitude, cluster.longitude),
                    math.min(18, _zoom + 2),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${cluster.encounters.length} rencontres dans cette zone',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                customBorder: const CircleBorder(),
                child: _ClusterMarker(count: cluster.encounters.length),
              ),
      ),
  ];

  void _scheduleFit(List<MaraudeEncounter> encounters) {
    if (!_mapReady || encounters.isEmpty) return;
    final signature = encounters.map((item) => item.id).join(':');
    if (_lastFitSignature == signature) return;
    _lastFitSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || encounters.isEmpty) return;
      if (encounters.length == 1) {
        _mapController.move(
          LatLng(encounters.first.latitude, encounters.first.longitude),
          15,
        );
        return;
      }
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [
            for (final item in encounters)
              LatLng(item.latitude, item.longitude),
          ],
          padding: const EdgeInsets.all(72),
          maxZoom: 16,
        ),
      );
    });
  }

  Future<void> _showEncounter(MaraudeEncounter encounter) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.xl,
              DsSpacing.sm,
              DsSpacing.xl,
              DsSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rencontre', style: DsTypography.h2),
                const SizedBox(height: DsSpacing.md),
                _DetailRow('Date', _formatDateTime(encounter.createdAt)),
                _DetailRow('Maraude', encounter.artist ?? '-'),
                _DetailRow('Salle', encounter.venueName ?? '-'),
                _DetailRow('Enregistrée par', encounter.createdByName ?? '-'),
                _DetailRow(
                  'Équipe',
                  encounter.teamNames.isEmpty
                      ? '-'
                      : encounter.teamNames.join(' · '),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  'Coordonnées enregistrées sans arrondi · précision GPS '
                  'annoncée par l’appareil : ±${encounter.accuracy.round()} m.',
                  style: DsTypography.caption,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _showMobileFilters(List<MaraudeEncounter> items) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            0,
            DsSpacing.lg,
            DsSpacing.xl,
          ),
          child: _FiltersBar(
            items: items,
            preset: _preset,
            maraudeId: _maraudeId,
            venueId: _venueId,
            creatorId: _creatorId,
            vertical: true,
            onPresetChanged: _changePreset,
            onMaraudeChanged: (value) =>
                _changeFilter(() => _maraudeId = value),
            onVenueChanged: (value) => _changeFilter(() => _venueId = value),
            onCreatorChanged: (value) =>
                _changeFilter(() => _creatorId = value),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: _customRange,
      helpText: 'Période des rencontres',
      saveText: 'Appliquer',
    );
    if (range == null) return;
    setState(() {
      _customRange = range;
      _preset = _PeriodPreset.custom;
      _lastFitSignature = null;
    });
  }

  void _changePreset(_PeriodPreset? value) {
    if (value == null) return;
    if (value == _PeriodPreset.custom) {
      _pickCustomRange();
      return;
    }
    setState(() {
      _preset = value;
      _lastFitSignature = null;
    });
  }

  void _changeFilter(VoidCallback change) {
    setState(() {
      change();
      _lastFitSignature = null;
    });
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.items,
    required this.preset,
    required this.maraudeId,
    required this.venueId,
    required this.creatorId,
    required this.onPresetChanged,
    required this.onMaraudeChanged,
    required this.onVenueChanged,
    required this.onCreatorChanged,
    this.vertical = false,
  });

  final List<MaraudeEncounter> items;
  final _PeriodPreset preset;
  final String? maraudeId;
  final String? venueId;
  final String? creatorId;
  final ValueChanged<_PeriodPreset?> onPresetChanged;
  final ValueChanged<String?> onMaraudeChanged;
  final ValueChanged<String?> onVenueChanged;
  final ValueChanged<String?> onCreatorChanged;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final maraudes = _unique(items, (item) => item.maraudeId, (item) {
      return '${item.artist ?? 'Maraude'} · ${item.venueName ?? 'Salle'}';
    });
    final venues = _unique(
      items.where((item) => item.venueId != null).toList(),
      (item) => item.venueId!,
      (item) => item.venueName ?? 'Salle',
    );
    final creators = _unique(
      items,
      (item) => item.createdBy,
      (item) => item.createdByName ?? 'Utilisateur',
    );
    final controls = <Widget>[
      _FilterDropdown<_PeriodPreset>(
        label: 'Période',
        value: preset,
        entries: const {
          _PeriodPreset.today: 'Aujourd’hui',
          _PeriodPreset.sevenDays: '7 derniers jours',
          _PeriodPreset.thirtyDays: '30 derniers jours',
          _PeriodPreset.year: 'Cette année',
          _PeriodPreset.custom: 'Période personnalisée',
        },
        onChanged: onPresetChanged,
      ),
      _OptionalFilter(
        label: 'Maraude',
        value: maraudeId,
        entries: maraudes,
        onChanged: onMaraudeChanged,
      ),
      _OptionalFilter(
        label: 'Salle',
        value: venueId,
        entries: venues,
        onChanged: onVenueChanged,
      ),
      _OptionalFilter(
        label: 'Équipe',
        value: creatorId,
        entries: creators,
        onChanged: onCreatorChanged,
      ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filtres', style: DsTypography.h2),
          const SizedBox(height: DsSpacing.md),
          for (final control in controls) ...[
            control,
            const SizedBox(height: DsSpacing.sm),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var index = 0; index < controls.length; index++) ...[
          Expanded(child: controls[index]),
          if (index < controls.length - 1) const SizedBox(width: DsSpacing.sm),
        ],
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> entries;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      for (final entry in entries.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: onChanged,
  );
}

class _OptionalFilter extends StatelessWidget {
  const _OptionalFilter({
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> entries;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value-${entries.length}'),
    initialValue: value ?? '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tous')),
      for (final entry in entries.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: (value) =>
        onChanged(value == null || value.isEmpty ? null : value),
  );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.compact,
    required this.onChanged,
  });

  final EncounterMapMode mode;
  final bool compact;
  final ValueChanged<EncounterMapMode> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    borderRadius: BorderRadius.circular(12),
    child: compact
        ? PopupMenuButton<EncounterMapMode>(
            tooltip: 'Visualisation',
            initialValue: mode,
            onSelected: onChanged,
            icon: const Icon(Icons.layers_outlined),
            itemBuilder: (_) => [
              for (final value in EncounterMapMode.values)
                PopupMenuItem(value: value, child: Text(_modeLabel(value))),
            ],
          )
        : SegmentedButton<EncounterMapMode>(
            segments: [
              for (final value in EncounterMapMode.values)
                ButtonSegment(value: value, label: Text(_modeLabel(value))),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (values) => onChanged(values.single),
          ),
  );
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary, required this.compact});

  final EncounterMapSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Kpi('Rencontres', '${summary.encounterCount}'),
      _Kpi('Maraudes', '${summary.maraudeCount}'),
      _Kpi(
        'Rencontres / maraude',
        summary.encountersPerMaraude.toStringAsFixed(1).replaceFirst('.', ','),
      ),
      _Kpi('Zones actives', '${summary.activeZoneCount}'),
    ];
    return compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final card in cards) ...[
                  SizedBox(width: 155, child: card),
                  const SizedBox(width: DsSpacing.sm),
                ],
              ],
            ),
          )
        : Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index < cards.length - 1)
                  const SizedBox(width: DsSpacing.sm),
              ],
            ],
          );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DsCard(
    padding: const EdgeInsets.all(DsSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: DsTypography.h2),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _EncounterMarker extends StatelessWidget {
  const _EncounterMarker();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF293283),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
    ),
    child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 19),
  );
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF293283),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: Text(
      '$count',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState();

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(16),
    child: const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 36),
          SizedBox(height: DsSpacing.sm),
          Text('Aucune rencontre pour ces filtres.'),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Map<String, String> _unique(
  List<MaraudeEncounter> items,
  String Function(MaraudeEncounter) id,
  String Function(MaraudeEncounter) label,
) {
  final result = <String, String>{};
  for (final item in items) {
    result.putIfAbsent(id(item), () => label(item));
  }
  return result;
}

String _modeLabel(EncounterMapMode mode) => switch (mode) {
  EncounterMapMode.points => 'Points',
  EncounterMapMode.clusters => 'Clusters',
  EncounterMapMode.heatmap => 'Carte de chaleur',
};

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} · '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
