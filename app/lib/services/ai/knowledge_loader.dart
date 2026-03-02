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

      // Skip if already loaded
      final existing = await rag.getDocumentByFileName(fileName);
      if (existing != null) {
        print('[KnowledgeLoader] $fileName already loaded, skipping');
        _documentsLoaded++;
        continue;
      }

      try {
        final content = await rootBundle.loadString(path);
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

  static Future<String> searchKnowledge(CactusRAG rag, String query) async {
    try {
      final results = await rag.search(text: query, limit: 3);
      if (results.isEmpty) {
        print('[KnowledgeLoader] No RAG results for: $query');
        return '';
      }

      print('[KnowledgeLoader] Found ${results.length} results for: $query');
      final buffer = StringBuffer();
      for (final result in results) {
        buffer.writeln(result.chunk.content);
        buffer.writeln('---');
      }
      return buffer.toString();
    } catch (e) {
      print('[KnowledgeLoader] RAG search failed: $e');
      return '';
    }
  }
}
