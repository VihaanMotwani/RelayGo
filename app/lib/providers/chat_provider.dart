import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/emergency_report.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/intent_filter.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/mesh/mesh_service.dart';

class ChatProvider extends ChangeNotifier {
  final AiService _aiService;
  final MeshService _meshService;
  final AudioService _audioService = AudioService();
  final String _deviceId;

  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isRecording = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  bool get isRecording => _isRecording;

  ChatProvider(this._aiService, this._meshService, this._deviceId);

  Future<void> sendTextMessage(String text) async {
    _addMessage(ChatMessage(text: text, role: ChatRole.user));
    await _processInput(text);
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    _isRecording = true;
    notifyListeners();
    await _audioService.startRecording();
  }

  Future<void> _stopRecording() async {
    _isRecording = false;
    notifyListeners();

    final path = await _audioService.stopRecording();
    if (path == null) return;

    _addMessage(ChatMessage(
      text: 'Transcribing voice...',
      role: ChatRole.system,
    ));

    try {
      final transcription = await _aiService.transcribe(path);
      // Replace the "transcribing" message
      _messages.removeLast();
      _addMessage(ChatMessage(
        text: transcription,
        role: ChatRole.user,
        isVoice: true,
      ));
      await _processInput(transcription);
    } catch (e) {
      _messages.removeLast();
      _addMessage(ChatMessage(
        text: 'Could not transcribe audio. Please type your message.',
        role: ChatRole.system,
        confidence: ConfidenceLevel.unverified,
      ));
    }
  }

  Future<void> _processInput(String text) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // Get AI response. Pass extractReport only when the intent filter
      // detects an emergency signal — avoids false alarms on casual messages.
      final response = await _aiService.chat(
        text,
        extractReport: IntentFilter.isLikelyEmergency(text),
      );

      _addMessage(ChatMessage(
        text: response.text,
        role: ChatRole.assistant,
        confidence: response.confidence,
      ));

      // If a report was extracted, create and broadcast it
      if (response.extraction != null) {
        await _createAndBroadcastReport(response.extraction!);
      }
    } catch (e) {
      _addMessage(ChatMessage(
        text: 'I\'m having trouble processing that. Please try again.',
        role: ChatRole.assistant,
        confidence: ConfidenceLevel.unverified,
      ));
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _createAndBroadcastReport(AiExtraction extraction) async {
    final position = await LocationService.getCurrentLocation();

    final report = EmergencyReport(
      id: const Uuid().v4(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lat: position?.latitude ?? 0,
      lng: position?.longitude ?? 0,
      acc: position?.accuracy ?? 0,
      type: extraction.type,
      urg: extraction.urgency,
      haz: extraction.hazards,
      desc: extraction.description,
      src: _deviceId,
    );

    await _meshService.broadcastReport(report);

    _addMessage(ChatMessage(
      text: 'Emergency report created and broadcast to mesh network.\n'
          'Type: ${extraction.type.toUpperCase()} | Urgency: ${extraction.urgency}/5\n'
          '${extraction.description}',
      role: ChatRole.system,
      confidence: ConfidenceLevel.meshReport,
    ));
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  Future<void> triggerSOS() async {
    _addMessage(ChatMessage(
      text: 'SOS ACTIVATED - Describe your emergency. You can speak or type.',
      role: ChatRole.system,
      confidence: ConfidenceLevel.verified,
    ));
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
