import 'package:flutter/material.dart';

typedef FilterSheetBuilder =
    Widget Function(BuildContext context, StateSetter setSheetState);

class AdaptiveSearchFilterHeader extends StatelessWidget {
  const AdaptiveSearchFilterHeader({
    super.key,
    required this.searchField,
    required this.portraitFilters,
    required this.sheetTitle,
    required this.sheetBuilder,
    this.activeFilterCount = 0,
  });

  final Widget searchField;
  final List<Widget> portraitFilters;
  final String sheetTitle;
  final FilterSheetBuilder sheetBuilder;
  final int activeFilterCount;

  Future<void> _showFilterSheet(BuildContext context) async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sheetTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              sheetBuilder(context, setSheetState),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (landscape) {
      final filterButton = IconButton.filledTonal(
        tooltip: 'Show filters',
        onPressed: () => _showFilterSheet(context),
        icon: const Icon(Icons.filter_list),
      );

      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 8),
          if (activeFilterCount > 0)
            Badge(label: Text('$activeFilterCount'), child: filterButton)
          else
            filterButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [searchField, ...portraitFilters],
    );
  }
}
