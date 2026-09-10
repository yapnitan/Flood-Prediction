import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/nearby_locations.dart';
import '../services/location_service.dart';

class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.onCoordinates,
    required this.onArea,
    this.focusNode,
    this.onManualEdit,
    this.validator,
    this.locationService,
  });

  final TextEditingController controller;
  final InputDecoration decoration;

  final void Function(double latitude, double longitude) onCoordinates;

  final void Function({String? state, String? district, String? postcode}) onArea;

  final FocusNode? focusNode;

  final VoidCallback? onManualEdit;

  final String? Function(String?)? validator;

  final LocationService? locationService;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  Timer? _debounceTimer;
  int _searchToken = 0;

  List<PlaceSearchResult> _results = const [];
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _limit = _pageSize;
  bool _panelOpen = false;
  String _query = '';

  static const _minQueryLength = 3;
  static const _debounce = Duration(milliseconds: 400);
  static const _pageSize = 8;
  static const _maxLimit = 40;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _refreshFor(widget.controller.text);
    } else {
      // Delay so a tap on a result registers before the panel closes.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) setState(() => _panelOpen = false);
      });
    }
  }

  List<PlaceSearchResult> _quickPicks(String query) {
    final q = query.trim().toLowerCase();
    return kNearbyLocations
        .where((l) => q.isEmpty || l.name.toLowerCase().contains(q))
        .map((l) => PlaceSearchResult(
              displayName: l.name,
              latitude: l.latitude,
              longitude: l.longitude,
            ))
        .toList();
  }

  void _onChanged(String text) {
    widget.onManualEdit?.call();
    _refreshFor(text);
  }

  void _refreshFor(String text) {
    final query = text.trim();
    _query = query;
    _debounceTimer?.cancel();

    if (query.length < _minQueryLength) {
      final picks = _quickPicks(query);
      setState(() {
        _results = picks;
        _searching = false;
        _hasMore = false;
        _panelOpen = _focusNode.hasFocus && picks.isNotEmpty;
      });
      return;
    }

    _limit = _pageSize;
    setState(() {
      _searching = true;
      _panelOpen = _focusNode.hasFocus;
    });
    _debounceTimer = Timer(_debounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final results = await _locationService.searchPlaces(query, limit: _limit);
    if (!mounted || token != _searchToken || query != _query) return;
    setState(() {
      _results = results.isNotEmpty ? results : _quickPicks(query);
      _searching = false;
      _hasMore = results.length >= _limit && _limit < _maxLimit;
      _panelOpen = _focusNode.hasFocus;
    });
  }

  Future<void> _loadMore() async {
    final query = _query;
    setState(() => _loadingMore = true);
    _limit = (_limit + _pageSize).clamp(0, _maxLimit);
    final results = await _locationService.searchPlaces(query, limit: _limit);
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _loadingMore = false;
      _hasMore = results.length >= _limit && _limit < _maxLimit;
    });
  }

  Future<void> _select(PlaceSearchResult place) async {
    _debounceTimer?.cancel();
    _searchToken++; // supersede any in-flight search
    widget.controller.text = place.displayName;
    setState(() {
      _panelOpen = false;
      _results = const [];
      _searching = false;
      _hasMore = false;
      _loadingMore = false;
    });
    _focusNode.unfocus();

    widget.onCoordinates(place.latitude, place.longitude);

    if (place.state != null || place.district != null || place.postcode != null) {
      widget.onArea(
        state: place.state,
        district: place.district,
        postcode: place.postcode,
      );
      return;
    }

    final geocode =
        await _locationService.reverseGeocode(place.latitude, place.longitude);
    if (!mounted || geocode == null) return;
    widget.onArea(
      state: geocode.state,
      district: geocode.district,
      postcode: geocode.postcode,
    );
  }

  Widget? _areaSubtitle(PlaceSearchResult place) {
    final parts = [
      if ((place.district ?? '').trim().isNotEmpty) place.district!.trim(),
      if ((place.state ?? '').trim().isNotEmpty) place.state!.trim(),
    ];
    return parts.isEmpty ? null : Text(parts.join(', '));
  }

  Widget _resultTile(PlaceSearchResult place) {
    final subtitle = _areaSubtitle(place);
    return ListTile(
      dense: true,
      isThreeLine: subtitle != null,
      leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
      title: Text(
        place.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle,
      onTap: () => _select(place),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: widget.decoration,
          validator: widget.validator,
          onChanged: _onChanged,
        ),
        if (_panelOpen) ...[
          const SizedBox(height: 4),
          Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Searching…'),
                      ],
                    ),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _query.length < _minQueryLength
                              ? 'Type at least $_minQueryLength characters to search'
                              : 'No matching places found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final place in _results)
                            _resultTile(place),
                          if (_hasMore)
                            ListTile(
                              dense: true,
                              title: Center(
                                child: _loadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Load more',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                              ),
                              onTap: _loadingMore ? null : _loadMore,
                            ),
                        ],
                      ),
            ),
          ),
        ],
      ],
    );
  }
}
