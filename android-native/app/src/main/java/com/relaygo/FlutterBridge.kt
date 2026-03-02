package com.relaygo

import android.content.Context
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * FlutterBridge manages communication between Kotlin/Compose UI and headless Flutter module.
 * Flutter handles: AI (Cactus), BLE mesh, backend sync
 * Kotlin handles: UI
 */
class FlutterBridge private constructor(context: Context) {

    companion object {
        private const val CHANNEL_NAME = "com.relaygo/bridge"

        @Volatile
        private var instance: FlutterBridge? = null

        fun getInstance(context: Context): FlutterBridge {
            return instance ?: synchronized(this) {
                instance ?: FlutterBridge(context.applicationContext).also { instance = it }
            }
        }
    }

    private val methodChannel: MethodChannel

    // State flows for Compose UI
    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized

    private val _isAiReady = MutableStateFlow(false)
    val isAiReady: StateFlow<Boolean> = _isAiReady

    private val _isMeshConnected = MutableStateFlow(false)
    val isMeshConnected: StateFlow<Boolean> = _isMeshConnected

    private val _peerCount = MutableStateFlow(0)
    val peerCount: StateFlow<Int> = _peerCount

    private val _initProgress = MutableStateFlow("")
    val initProgress: StateFlow<String> = _initProgress

    // Callbacks
    var onMeshPacket: ((Map<String, Any?>) -> Unit)? = null
    var onPeerCountChanged: ((Int) -> Unit)? = null

    init {
        val engine = FlutterEngineCache.getInstance().get(RelayGoApp.FLUTTER_ENGINE_ID)
            ?: throw IllegalStateException("Flutter engine not initialized")

        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        // Handle calls FROM Flutter
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "onInitProgress" -> {
                    val progress = call.argument<String>("progress") ?: ""
                    _initProgress.value = progress
                    result.success(null)
                }
                "onMeshPacket" -> {
                    @Suppress("UNCHECKED_CAST")
                    val packet = call.arguments as? Map<String, Any?>
                    packet?.let { onMeshPacket?.invoke(it) }
                    result.success(null)
                }
                "onPeerCountChanged" -> {
                    val count = call.argument<Int>("count") ?: 0
                    _peerCount.value = count
                    onPeerCountChanged?.invoke(count)
                    result.success(null)
                }
                "onConnectionStatus" -> {
                    val status = call.argument<String>("status") ?: ""
                    _isMeshConnected.value = (status == "connected")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ============================================================
    // INITIALIZATION
    // ============================================================

    suspend fun initialize(): Boolean = invokeMethod("initialize").let {
        val success = it["success"] as? Boolean ?: false
        if (success) {
            _isInitialized.value = true
            refreshState()
        }
        success
    }

    // ============================================================
    // AI METHODS
    // ============================================================

    suspend fun transcribe(audioPath: String): String {
        val result = invokeMethod("transcribe", mapOf("audioPath" to audioPath))
        return result["text"] as? String ?: ""
    }

    suspend fun chat(text: String, extractReport: Boolean = false): ChatResponse {
        val result = invokeMethod("chat", mapOf(
            "text" to text,
            "extractReport" to extractReport
        ))
        return ChatResponse(
            text = result["text"] as? String ?: "",
            confidence = result["confidence"] as? String ?: "unverified",
            extraction = (result["extraction"] as? Map<*, *>)?.let { ExtractionData.fromMap(it) }
        )
    }

    suspend fun generateAwarenessSummary(): String {
        val result = invokeMethod("generateAwarenessSummary")
        return result["summary"] as? String ?: ""
    }

    // ============================================================
    // MESH METHODS
    // ============================================================

    suspend fun startMesh() {
        invokeMethod("startMesh")
        _isMeshConnected.value = true
    }

    suspend fun stopMesh() {
        invokeMethod("stopMesh")
        _isMeshConnected.value = false
    }

    suspend fun sendSOS(description: String? = null) {
        val args = mutableMapOf<String, Any>()
        description?.let { args["description"] = it }
        invokeMethod("sendSOS", args)
    }

    suspend fun sendBroadcast(message: String) {
        invokeMethod("sendBroadcast", mapOf("message" to message))
    }

    suspend fun sendDirectMessage(peerId: String, message: String) {
        invokeMethod("sendDirectMessage", mapOf(
            "peerId" to peerId,
            "message" to message
        ))
    }

    @Suppress("UNCHECKED_CAST")
    suspend fun getReports(): List<Map<String, Any?>> {
        val result = invokeMethod("getReports")
        return result["reports"] as? List<Map<String, Any?>> ?: emptyList()
    }

    @Suppress("UNCHECKED_CAST")
    suspend fun getBroadcasts(): List<Map<String, Any?>> {
        val result = invokeMethod("getBroadcasts")
        return result["broadcasts"] as? List<Map<String, Any?>> ?: emptyList()
    }

    @Suppress("UNCHECKED_CAST")
    suspend fun getPeers(): List<Map<String, Any?>> {
        val result = invokeMethod("getPeers")
        return result["peers"] as? List<Map<String, Any?>> ?: emptyList()
    }

    // ============================================================
    // SETTINGS
    // ============================================================

    suspend fun setRelayEnabled(enabled: Boolean) {
        invokeMethod("setRelayEnabled", mapOf("enabled" to enabled))
    }

    suspend fun setDisplayName(name: String) {
        invokeMethod("setDisplayName", mapOf("name" to name))
    }

    private suspend fun refreshState() {
        val state = invokeMethod("getState")
        _isInitialized.value = state["isInitialized"] as? Boolean ?: false
        _isAiReady.value = state["isAiReady"] as? Boolean ?: false
        _isMeshConnected.value = state["isMeshConnected"] as? Boolean ?: false
        _peerCount.value = state["peerCount"] as? Int ?: 0
    }

    // ============================================================
    // PRIVATE HELPERS
    // ============================================================

    @Suppress("UNCHECKED_CAST")
    private suspend fun invokeMethod(
        method: String,
        arguments: Map<String, Any?> = emptyMap()
    ): Map<String, Any?> = suspendCancellableCoroutine { continuation ->
        methodChannel.invokeMethod(method, arguments, object : MethodChannel.Result {
            override fun success(result: Any?) {
                continuation.resume(result as? Map<String, Any?> ?: emptyMap())
            }

            override fun error(code: String, message: String?, details: Any?) {
                continuation.resumeWithException(BridgeException("$code: $message"))
            }

            override fun notImplemented() {
                continuation.resumeWithException(BridgeException("Method $method not implemented"))
            }
        })
    }
}

class BridgeException(message: String) : Exception(message)

data class ChatResponse(
    val text: String,
    val confidence: String,
    val extraction: ExtractionData?
)

data class ExtractionData(
    val type: String,
    val urgency: Int,
    val hazards: List<String>,
    val description: String
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<*, *>): ExtractionData {
            return ExtractionData(
                type = map["type"] as? String ?: "other",
                urgency = (map["urgency"] as? Number)?.toInt() ?: 3,
                hazards = map["hazards"] as? List<String> ?: emptyList(),
                description = map["description"] as? String ?: ""
            )
        }
    }
}
