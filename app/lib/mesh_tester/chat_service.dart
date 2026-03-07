import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'chat_cache_store.dart';
import 'chat_models.dart';
import 'gemma_service.dart';
import 'knowledge_repository.dart';
import 'location_finder.dart';
import 'log_service.dart';
import 'prompt_builder.dart';
import 'retriever.dart';

/// Orchestrates per-turn RAG + caching on top of [GemmaService].
///
/// Flow for each [streamAnswer] call:
///   1. Normalize query
///   2. Check response cache → hit: stream cached answer immediately
///   3. Retrieve relevant passages (deterministic lexical scoring)
///   4. Assemble prompt with retrieved context
///   5. Stream from LLM via GemmaService.streamPrompt() (fresh session)
///   6. Save answer to response cache
///   7. Expose [lastMeta] for UI provenance display
///
/// GemmaService.streamChat() and the persistent chat session are NOT
/// used here — each turn gets a fresh inference session so retrieved
/// context never leaks between turns.
class ChatService {
  final GemmaService _gemma;
  final KnowledgeRepository _knowledge;
  final Retriever _retriever;
  final ChatCacheStore _cache;
  final LocationFinder _locationFinder;
  final LogService _log;

  double? _lat;
  double? _lng;

  /// Metadata about the most recently completed answer.
  /// Read by the UI after the stream closes.
  ChatMeta _lastMeta = const ChatMeta();
  ChatMeta get lastMeta => _lastMeta;

  ChatService({required GemmaService gemma, LogService? log})
      : _gemma = gemma,
        _knowledge = KnowledgeRepository(),
        _retriever = Retriever(),
        _cache = ChatCacheStore(),
        _locationFinder = LocationFinder(),
        _log = log ?? LogService.instance;

  /// Update the device GPS position used for nearby-resource injection.
  /// Call this whenever a fresh location fix is obtained.
  void updateLocation(double? lat, double? lng) {
    _lat = lat;
    _lng = lng;
    if (lat != null && lng != null) {
      _log.log('AI-RAG', 'Location updated: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
    }
  }

  Future<void> initialize() async {
    await _knowledge.initialize();
    await _cache.initialize();
    await _locationFinder.initialize();
    _log.log(
      'AI-RAG',
      'Knowledge loaded: ${_knowledge.passages.length} passages '
          '(hash ${_knowledge.contentHash})',
    );
  }

  // ── Main entry point ────────────────────────────────────────────

  Stream<String> streamAnswer(String query) async* {
    final normalized = _normalize(query);
    final cacheKey = _buildCacheKey(normalized);

    // ── 1. Cache hit ──────────────────────────────────────────────
    final cached = await _cache.lookupResponse(cacheKey);
    if (cached != null) {
      _log.log('AI-CACHE', 'hit: "${_trunc(normalized)}"');
      _lastMeta = const ChatMeta(fromCache: true, usedRag: true);
      yield cached;
      return;
    }

    // ── 2. Retrieval ──────────────────────────────────────────────
    final scored = _retriever.retrieve(normalized, _knowledge.passages);
    final sourceLabels =
        scored.map((s) => s.passage.sourceLabel).toSet().toList();

    if (scored.isNotEmpty) {
      _log.log('AI-RAG',
          'query="${_trunc(normalized)}" → [${sourceLabels.join(", ")}]');
    } else {
      _log.log('AI-RAG', 'no passages matched for "${_trunc(normalized)}"');
    }

    // ── 3. Nearby resource injection ──────────────────────────────
    // Only inject location data when the user is explicitly asking WHERE
    // something is. For procedure queries ("gas leak", "chemical on skin")
    // we inject knowledge only — the small model gets confused and ignores
    // procedures when location data is also present.
    final nearby = <NearbyResource>[];
    final lat = _lat;
    final lng = _lng;
    if (lat != null && lng != null && _isLocationQuery(normalized)) {
      final queryType = _locationFinder.detectQueryType(normalized);
      final topic =
          scored.isNotEmpty ? scored.first.passage.topic : 'other';
      final found = _locationFinder.findNearest(
        topic,
        lat,
        lng,
        queryType: queryType,
      );
      nearby.addAll(found);
      if (found.isNotEmpty) {
        final names =
            found.map((r) => '${r.name} (${r.distanceStr})').join(', ');
        _log.log('AI-RAG', 'nearby [${queryType ?? topic}]: $names');
      }
    }

    // ── 4. Prompt assembly ────────────────────────────────────────
    // When we have real nearby results for a location query, suppress
    // knowledge passages — low-score passages (e.g. fire evacuation
    // matching "now") mislead the model into ignoring the location data.
    final passagesForPrompt =
        (nearby.isNotEmpty && _isLocationQuery(normalized)) ? <ScoredPassage>[] : scored;
    final prompt = PromptBuilder.build(
      query,
      passagesForPrompt,
      nearby: nearby,
      locationAvailable: lat != null && lng != null,
    );

    // ── 4. Generation ─────────────────────────────────────────────
    final buf = StringBuffer();
    var generationFailed = false;

    try {
      await for (final token in _gemma.streamPrompt(prompt)) {
        if (token.contains('[Error:')) {
          generationFailed = true;
          break;
        }
        buf.write(token);
        yield token;
      }
    } catch (e) {
      debugPrint('[ChatService] generation error: $e');
      generationFailed = true;
    }

    // ── 5. Fallback from retrieved passage ────────────────────────
    if (generationFailed && scored.isNotEmpty) {
      final fallbackText = PromptBuilder.buildFallback(scored.first.passage);
      _log.log('AI-RAG', 'fallback from ${scored.first.passage.sourceLabel}');
      _lastMeta = ChatMeta(
        usedRag: true,
        sourceLabels: sourceLabels,
        fallback: true,
        nearbyCount: nearby.length,
      );
      yield '\n$fallbackText';
      return;
    }

    // ── 6. Cache write ────────────────────────────────────────────
    final answer = buf.toString().trim();
    if (answer.isNotEmpty && !generationFailed) {
      await _cache.saveResponse(
          cacheKey, answer, sourceLabels, scored.isNotEmpty);
      _log.log('AI-CACHE', 'saved: "${_trunc(normalized)}"');
    }

    _lastMeta = ChatMeta(
      usedRag: scored.isNotEmpty,
      sourceLabels: sourceLabels,
      nearbyCount: nearby.length,
    );
  }

  // ── Settings / debug actions ────────────────────────────────────

  Future<void> clearCache() async {
    await _cache.clearAll();
    _log.log('AI-CACHE', 'cache cleared');
  }

  Future<void> rebuildIndex() async {
    await _knowledge.initialize();
    await _cache.clearAll();
    _log.log(
      'AI-RAG',
      'index rebuilt: ${_knowledge.passages.length} passages '
          '(hash ${_knowledge.contentHash})',
    );
  }

  Future<void> dispose() async {
    await _cache.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────

  /// Returns true when the query is asking about WHERE something is,
  /// so we know to inject nearby facility data into the prompt.
  static bool _isLocationQuery(String q) {
    const locationWords = [
      'where', 'nearest', 'near me', 'near here', 'nearby',
      'closest', 'close to me', 'around me', 'around here',
      'find me', 'directions', 'how far', 'location',
    ];
    return locationWords.any((w) => q.contains(w));
  }

  String _normalize(String q) =>
      q.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  String _buildCacheKey(String normalized) {
    final input =
        '${normalized}_${_knowledge.contentHash}_v1_qwen2.5-0.5b';
    return sha256.convert(utf8.encode(input)).toString();
  }

  String _trunc(String s, [int max = 50]) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
