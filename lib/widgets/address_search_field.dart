import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/nearby_locations.dart';
import '../services/address_search_service.dart';

class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    this.onQueryEdited,
    this.hintText = 'Search for your address',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  final void Function(String name, double latitude, double longitude) onSelected;
  final VoidCallback? onQueryEdited;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final _searchService = AddressSearchService();
  Timer? _debounce;
  List<AddressSearchResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _suppressNextChange = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = widget.focusNode.hasFocus);
  }

  void _onTextChanged() {
    if (_suppressNextChange) {
      _suppressNextChange = false;
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    widget.onQueryEdited?.call();

    final query = widget.controller.text.trim();
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final results = await _searchService.search(query);
    if (!mounted || widget.controller.text.trim() != query) return; // stale response
    setState(() {
      _results = results;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  void _select(String name, double lat, double lng) {
    _suppressNextChange = true;
    widget.controller.text = name;
    widget.focusNode.unfocus();
    widget.onSelected(name, lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final showingQuickPicks = query.length < 3;
    final quickPicks = kNearbyLocations
        .where((l) => query.isEmpty || l.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            labelText: 'Search location',
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onQueryEdited?.call();
                        },
                      )
                    : null),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        if (_hasFocus && showingQuickPicks && quickPicks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ResultsBox(
            children: quickPicks
                .map(
                  (location) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                    title: Text(location.name),
                    onTap: () => _select(location.name, location.latitude, location.longitude),
                  ),
                )
                .toList(),
          ),
        ] else if (_hasFocus && !showingQuickPicks) ...[
          const SizedBox(height: 8),
          _ResultsBox(
            children: _results.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _hasSearched
                            ? 'No matching addresses found.'
                            : 'Keep typing to search…',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ]
                : _results
                    .map(
                      (r) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                        title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _select(r.displayName, r.latitude, r.longitude),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }
}

class _ResultsBox extends StatelessWidget {
  const _ResultsBox({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: children,
        ),
      ),
    );
  }
}
