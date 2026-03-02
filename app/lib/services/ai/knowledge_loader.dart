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

  static Future<void> loadIntoRag(CactusRAG rag, CactusLM lm) async {
    await rag.initialize();

    rag.setEmbeddingGenerator((text) async {
      final result = await lm.generateEmbedding(text: text);
      return result.embeddings;
    });

    rag.setChunking(chunkSize: 512, chunkOverlap: 64);

    for (final path in _knowledgeFiles) {
      final fileName = path.split('/').last;

      // Skip if already loaded
      final existing = await rag.getDocumentByFileName(fileName);
      if (existing != null) continue;

      final content = await rootBundle.loadString(path);
      await rag.storeDocument(
        fileName: fileName,
        filePath: path,
        content: content,
        fileSize: content.length,
        fileHash: content.hashCode.toString(),
      );
    }
  }

  static Future<String> searchKnowledge(CactusRAG rag, String query) async {
    final results = await rag.search(text: query, limit: 3);
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('[VERIFIED EMERGENCY PROCEDURES]');
    for (final result in results) {
      buffer.writeln(result.chunk.content);
      buffer.writeln('---');
    }
    return buffer.toString();
  }
}
