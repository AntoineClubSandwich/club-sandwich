import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/consumables/presentation/consumables_screen.dart';
import 'package:club_sandwich/features/equipment/presentation/equipment_screen.dart';
import 'package:flutter/material.dart';

enum StockSection { consumables, equipment }

class StockScreen extends StatefulWidget {
  const StockScreen({
    this.initialSection = StockSection.consumables,
    super.key,
  });

  final StockSection initialSection;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late StockSection _section = widget.initialSection;

  @override
  void didUpdateWidget(covariant StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _section = widget.initialSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.xl,
                DsSpacing.xl,
                DsSpacing.xl,
                0,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: DsSpacing.lg,
                runSpacing: DsSpacing.md,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock', style: DsTypography.h1),
                      const Text(
                        'Gérez séparément les consommables et le matériel durable.',
                      ),
                    ],
                  ),
                  SegmentedButton<StockSection>(
                    segments: const [
                      ButtonSegment(
                        value: StockSection.consumables,
                        label: Text('Consommables'),
                        icon: Icon(Icons.shopping_basket_outlined),
                      ),
                      ButtonSegment(
                        value: StockSection.equipment,
                        label: Text('Parc matériel'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {_section},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _section = selection.single);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _section.index,
                children: const [
                  ConsumablesScreen(embedded: true),
                  EquipmentScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
