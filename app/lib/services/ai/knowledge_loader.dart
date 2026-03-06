import 'package:cactus/cactus.dart';
import 'package:flutter/services.dart';

class KnowledgeLoader {
  static const _knowledgeFiles = [
    'assets/knowledge/first_aid_basics.txt',
    'assets/knowledge/cpr_instructions.txt',
    'assets/knowledge/fire_evacuation.txt',
    'assets/knowledge/flood_response.txt',
    'assets/knowledge/hazmat_safety.txt',
    'assets/knowledge/earthquake_response.txt',
    'assets/knowledge/general_emergency.txt',
  ];

  static int _documentsLoaded = 0;
  static int get documentsLoaded => _documentsLoaded;

  /// In-memory cache of file contents, keyed by filename (without path).
  /// Populated during [loadIntoRag] so keyword fallback can use them.
  static final Map<String, String> _cache = {};

  static Future<void> loadIntoRag(CactusRAG rag, CactusLM lm) async {
    print('[KnowledgeLoader] Initializing RAG...');
    await rag.initialize();

    rag.setEmbeddingGenerator((text) async {
      final result = await lm.generateEmbedding(text: text);
      return result.embeddings;
    });

    // Each file is small (~400 chars) so use larger chunks to keep intact
    rag.setChunking(chunkSize: 512, chunkOverlap: 64);

    _documentsLoaded = 0;
    for (final path in _knowledgeFiles) {
      final fileName = path.split('/').last;

      try {
        final content = await rootBundle.loadString(path);
        _cache[fileName] = content; // Cache regardless of RAG status

        // Skip RAG insert if already stored
        final existing = await rag.getDocumentByFileName(fileName);
        if (existing != null) {
          _documentsLoaded++;
          continue;
        }

        await rag.storeDocument(
          fileName: fileName,
          filePath: path,
          content: content,
          fileSize: content.length,
          fileHash: content.hashCode.toString(),
        );
        _documentsLoaded++;
        print('[KnowledgeLoader] Loaded $fileName (${content.length} chars)');
      } catch (e) {
        print('[KnowledgeLoader] Failed to load $fileName: $e');
      }
    }
    print('[KnowledgeLoader] Loaded $_documentsLoaded/${_knowledgeFiles.length} knowledge files');
  }

  /// Searches for relevant knowledge using vector search with a keyword
  /// fallback. The fallback is critical because smollm2-360M embeddings
  /// may not produce high enough similarity scores to trigger vector results.
  ///
  /// Strategy:
  ///   1. Try CactusRAG vector search (top-3 results)
  ///   2. If empty, select the best-matching file by keyword scoring
  ///   3. Return formatted context string, or '' if nothing matches
  static Future<String> searchKnowledge(CactusRAG rag, String query) async {
    try {
      // 1. Vector search
      final results = await rag.search(text: query, limit: 3);
      if (results.isNotEmpty) {
        final buffer = StringBuffer('[EMERGENCY PROCEDURES]\n');
        for (final result in results) {
          buffer.writeln(result.chunk.content);
          buffer.writeln('---');
        }
        return buffer.toString();
      }
    } catch (e) {
      print('[KnowledgeLoader] RAG search failed: $e');
    }

    // 2. Keyword fallback — select the most relevant knowledge file
    final matched = _keywordFallback(query);
    if (matched == null) return '';

    return '[EMERGENCY PROCEDURES]\n$matched';
  }

  /// Selects the most relevant knowledge file by keyword scoring.
  /// Returns the file content, or null if nothing is a clear match.
  static String? _keywordFallback(String query) {
    final lower = query.toLowerCase();

    // Score each file based on keyword matches in the query
    final scores = <String, int>{};

    // Fire
    scores['fire_evacuation.txt'] = _count(lower, [
      'fire', 'burning', 'flames', 'smoke', 'wildfire', 'evacuate', 'blaze',
      'trapped in room', 'smoke alarm', 'exit', 'building fire',
    ]);

    // CPR / cardiac
    scores['cpr_instructions.txt'] = _count(lower, [
      'cpr', 'cardiac', 'heart', 'not breathing', 'stopped breathing',
      'no pulse', 'resuscitat', 'unconscious', 'chest compression',
      'rescue breath',
    ]);

    // First aid
    scores['first_aid_basics.txt'] = _count(lower, [
      'bleed', 'wound', 'fracture', 'broken bone', 'burn', 'choke', 'choking',
      'shock', 'first aid', 'injured', 'injury', 'cut', 'blood', 'bandage',
      'tourniquet',
    ]);

    // Flood
    scores['flood_response.txt'] = _count(lower, [
      'flood', 'flooding', 'water rising', 'flash flood', 'submerged',
      'river', 'drown', 'swept away', 'water level',
    ]);

    // Hazmat
    scores['hazmat_safety.txt'] = _count(lower, [
      'gas', 'gas leak', 'chemical', 'hazmat', 'spill', 'toxic', 'fumes',
      'inhale', 'vapour', 'vapor', 'propane', 'natural gas', 'hissing',
      'rotten egg', 'power line', 'downed line',
    ]);

    // Earthquake
    scores['earthquake_response.txt'] = _count(lower, [
      'earthquake', 'aftershock', 'rubble', 'tremor', 'seismic', 'shaking',
      'quake', 'debris', 'structural collapse', 'tsunami',
    ]);

    // General
    scores['general_emergency.txt'] = _count(lower, [
      'emergency kit', 'survival', 'missing person', 'communication',
      'shelter', 'help', 'lost', 'stranded', 'triage',
    ]);

    // Pick the highest-scoring file
    String? bestFile;
    int bestScore = 0;
    scores.forEach((file, score) {
      if (score > bestScore) {
        bestScore = score;
        bestFile = file;
      }
    });

    // Require at least one keyword match to avoid returning irrelevant content
    if (bestScore == 0 || bestFile == null) {
      // Default to general emergency for any unmatched query
      return _cache['general_emergency.txt'];
    }

    return _cache[bestFile];
  }

  /// Counts how many keywords from [terms] appear in [text].
  static int _count(String text, List<String> terms) {
    return terms.where((t) => text.contains(t)).length;
  }
}
