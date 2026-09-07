import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/asset_categories.dart';

/// Claude's best-effort read of an asset-loss evidence photo. Every field is
/// a suggestion the resident can override on the form.
class AssetAiSuggestion {
  const AssetAiSuggestion({
    this.category,
    this.assetName,
    this.condition,
    this.quantity,
    this.estimatedValuePerItem,
    this.description,
    this.note,
  });

  final String? category;
  final String? assetName;

  /// A key from [assetConditions] (e.g. `severely_damaged`), already mapped
  /// back from whatever label the model returned.
  final String? condition;
  final int? quantity;
  final double? estimatedValuePerItem;
  final String? description;

  /// Model's note about anything uncertain — shown to the user, not stored.
  final String? note;
}

/// Vision-assisted prefill for the "Report Asset Loss" wizard. Sends the
/// evidence photo to Claude (Anthropic Messages API over raw HTTP — there is
/// no official Dart SDK) and asks it to identify the item, judge its
/// flood-damage condition, and estimate a replacement value in RM.
///
/// The API key lives in `.env` as `ANTHROPIC_API_KEY` (gitignored). It ships
/// in the app binary — acceptable for this coursework build; a production
/// app would proxy the call through a server so the key stays secret.
class AssetAiService {
  AssetAiService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Swap to `claude-sonnet-5` or `claude-haiku-4-5` to cut cost several-fold
  /// — identifying an item and estimating its value from a photo runs fine
  /// on the smaller models.
  static const _model = 'claude-opus-5';

  static const _maxPhotos = 3;

  String? get _apiKey {
    try {
      final key = dotenv.maybeGet('ANTHROPIC_API_KEY')?.trim();
      return (key == null || key.isEmpty) ? null : key;
    } catch (_) {
      // dotenv not initialised (e.g. widget tests) — treat as unconfigured.
      return null;
    }
  }

  /// Whether an API key is present — the wizard hides the AI button when not.
  bool get isConfigured => _apiKey != null;

  /// Returns null on any failure (no key, network error, unparseable reply) —
  /// the caller falls back to manual entry.
  Future<AssetAiSuggestion?> analysePhotos(List<XFile> photos) async {
    final key = _apiKey;
    if (key == null || photos.isEmpty) return null;

    try {
      final imageBlocks = <Map<String, dynamic>>[];
      for (final photo in photos.take(_maxPhotos)) {
        final bytes = await photo.readAsBytes();
        imageBlocks.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': _mediaType(photo),
            'data': base64Encode(bytes),
          },
        });
      }

      final requestBody = jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        // Forced tool use requires thinking off (and guarantees a structured
        // tool_use block back, which is all this call reads).
        'thinking': {'type': 'disabled'},
        'tools': [_tool],
        'tool_choice': {'type': 'tool', 'name': 'report_asset_loss'},
        'system': _systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': [
              ...imageBlocks,
              {
                'type': 'text',
                'text': 'Identify this flood-damaged item and fill in the '
                    'asset-loss report.',
              },
            ],
          },
        ],
      });

      final response = await _http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        debugPrint('AssetAiService HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>? ?? const [];
      Map<String, dynamic>? toolInput;
      for (final block in content) {
        if (block is Map<String, dynamic> && block['type'] == 'tool_use') {
          toolInput = block['input'] as Map<String, dynamic>?;
          break;
        }
      }
      if (toolInput == null) return null;

      return _parse(toolInput);
    } catch (error) {
      debugPrint('AssetAiService.analysePhotos error: $error');
      return null;
    }
  }

  AssetAiSuggestion _parse(Map<String, dynamic> input) {
    final rawQty = input['quantity'];
    final rawValue = input['estimated_value_per_item'];
    final note = (input['confidence_note'] as String?)?.trim();

    return AssetAiSuggestion(
      category: _matchCategory(input['asset_category'] as String?),
      assetName: (input['asset_name'] as String?)?.trim(),
      condition: _matchCondition(input['condition'] as String?),
      quantity: rawQty is num ? rawQty.toInt() : int.tryParse('$rawQty'),
      estimatedValuePerItem:
          rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue'),
      description: (input['description'] as String?)?.trim(),
      note: (note == null || note.isEmpty) ? null : note,
    );
  }

  static String? _matchCategory(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    for (final category in assetCategories) {
      if (category.toLowerCase() == lower) return category;
    }
    return null;
  }

  static String? _matchCondition(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    // Accept either the internal key or the display label.
    if (assetConditions.contains(lower)) return lower;
    for (final entry in assetConditionLabels.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    return null;
  }

  static String _mediaType(XFile photo) {
    final name = photo.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  static final Map<String, dynamic> _tool = {
    'name': 'report_asset_loss',
    'description': 'Record the household asset shown in the flood-damage '
        'photo(s), with a best-effort replacement-value estimate in '
        'Malaysian Ringgit.',
    'input_schema': {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'asset_category': {
          'type': 'string',
          'enum': assetCategories,
          'description': 'The closest category for this item.',
        },
        'asset_name': {
          'type': 'string',
          'description': 'Short name of the item, e.g. "Refrigerator", "Sofa".',
        },
        'condition': {
          'type': 'string',
          'enum': [...assetConditionLabels.values],
          'description': 'Flood-damage severity visible in the photo.',
        },
        'quantity': {
          'type': 'integer',
          'minimum': 1,
          'description': 'How many of this item are visibly damaged '
              '(default 1 if only one is shown).',
        },
        'estimated_value_per_item': {
          'type': 'number',
          'minimum': 0,
          'description': 'Approximate cost in RM to replace ONE unit with an '
              'equivalent new item bought in Malaysia.',
        },
        'description': {
          'type': 'string',
          'description': 'One or two sentences describing the item and the '
              'damage seen in the photo.',
        },
        'confidence_note': {
          'type': 'string',
          'description': 'Short note on anything uncertain (blurry photo, '
              'value is a rough guess, etc.). Empty string if confident.',
        },
      },
      'required': [
        'asset_category',
        'asset_name',
        'condition',
        'quantity',
        'estimated_value_per_item',
        'description',
      ],
    },
  };

  static const _systemPrompt =
      'You help Malaysian flood victims file asset-loss claims. From the '
      'evidence photo(s) of a flood-damaged household item, identify the '
      'item, judge how badly the flood damaged it, and estimate a fair '
      'replacement cost in Malaysian Ringgit (RM) for a new equivalent '
      'bought locally. Base every field on what the photo shows plus general '
      'knowledge of Malaysian retail prices. If the photo is unclear, still '
      'give your best estimate and say so in confidence_note. Always call the '
      'report_asset_loss tool.';
}
