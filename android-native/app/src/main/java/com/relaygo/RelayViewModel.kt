package com.relaygo

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.Date
import java.util.UUID

data class Broadcast(
    val id: String,
    val sender: String,
    val message: String,
    val timestamp: Date,
    val hops: Int,
    val isEmergency: Boolean
) {
    val timeAgo: String
        get() {
            val seconds = ((Date().time - timestamp.time) / 1000).toInt()
            return when {
                seconds < 60 -> "now"
                seconds < 3600 -> "${seconds / 60}m"
                else -> "${seconds / 3600}h"
            }
        }
}

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val isUser: Boolean,
    val text: String,
    val timestamp: Date = Date()
)

class RelayViewModel(application: Application) : AndroidViewModel(application) {

    // Connection state
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isConnecting = MutableStateFlow(false)
    val isConnecting: StateFlow<Boolean> = _isConnecting

    private val _peerCount = MutableStateFlow(0)
    val peerCount: StateFlow<Int> = _peerCount

    // SOS state
    private val _sosActive = MutableStateFlow(false)
    val sosActive: StateFlow<Boolean> = _sosActive

    // Broadcasts
    private val _broadcasts = MutableStateFlow<List<Broadcast>>(emptyList())
    val broadcasts: StateFlow<List<Broadcast>> = _broadcasts

    private val _unreadCount = MutableStateFlow(0)
    val unreadCount: StateFlow<Int> = _unreadCount

    // Chat
    private val _chatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val chatMessages: StateFlow<List<ChatMessage>> = _chatMessages

    private val _isThinking = MutableStateFlow(false)
    val isThinking: StateFlow<Boolean> = _isThinking

    // Settings
    private val _relayEnabled = MutableStateFlow(false)
    val relayEnabled: StateFlow<Boolean> = _relayEnabled

    // Device name
    val deviceName: String = android.os.Build.MODEL

    // ============================================================
    // SOS
    // ============================================================

    fun triggerSOS() {
        if (_sosActive.value) return

        viewModelScope.launch {
            // Auto-connect if not connected
            if (!_isConnected.value) {
                connect()
            }

            _sosActive.value = true

            // Add SOS to broadcasts
            val sos = Broadcast(
                id = UUID.randomUUID().toString(),
                sender = deviceName,
                message = "SOS - Emergency assistance needed",
                timestamp = Date(),
                hops = 0,
                isEmergency = true
            )
            _broadcasts.value = listOf(sos) + _broadcasts.value
        }
    }

    fun cancelSOS() {
        _sosActive.value = false
    }

    // ============================================================
    // CONNECTION
    // ============================================================

    fun connect() {
        if (_isConnected.value || _isConnecting.value) return

        viewModelScope.launch {
            _isConnecting.value = true

            // Simulate connection delay
            delay(1500)

            _isConnected.value = true
            _isConnecting.value = false
            _peerCount.value = (2..5).random()

            // Load demo data
            loadDemoBroadcasts()
        }
    }

    fun disconnect() {
        _isConnected.value = false
        _peerCount.value = 0
        _sosActive.value = false
    }

    // ============================================================
    // BROADCASTS
    // ============================================================

    fun sendBroadcast(message: String) {
        val broadcast = Broadcast(
            id = UUID.randomUUID().toString(),
            sender = deviceName,
            message = message,
            timestamp = Date(),
            hops = 0,
            isEmergency = false
        )
        _broadcasts.value = listOf(broadcast) + _broadcasts.value
    }

    fun markAsRead() {
        _unreadCount.value = 0
    }

    private fun loadDemoBroadcasts() {
        _broadcasts.value = listOf(
            Broadcast("1", "Sarah", "Road clear on Oak Street, heading to shelter",
                Date(System.currentTimeMillis() - 120000), 1, false),
            Broadcast("2", "Emergency Services", "Evacuation center open at Central High School",
                Date(System.currentTimeMillis() - 300000), 2, false),
            Broadcast("3", "Mike", "SOS - Need medical help at 123 Main St",
                Date(System.currentTimeMillis() - 60000), 1, true),
        )
        _unreadCount.value = 3
    }

    // ============================================================
    // AI CHAT
    // ============================================================

    fun sendToAI(text: String) {
        viewModelScope.launch {
            // Add user message
            val userMessage = ChatMessage(isUser = true, text = text)
            _chatMessages.value = _chatMessages.value + userMessage

            _isThinking.value = true

            // Simulate AI response delay
            delay(1000)

            // Generate response
            val response = generateAIResponse(text)
            val aiMessage = ChatMessage(isUser = false, text = response)
            _chatMessages.value = _chatMessages.value + aiMessage

            _isThinking.value = false
        }
    }

    private fun generateAIResponse(text: String): String {
        val lower = text.lowercase()

        return when {
            lower.contains("fire") || lower.contains("smoke") ->
                "Stay calm. Get low and evacuate immediately. Don't use elevators. Once outside, move away from the building and call 911."

            lower.contains("hurt") || lower.contains("bleeding") || lower.contains("injured") ->
                "Apply direct pressure to any bleeding with a clean cloth. Keep the person still and warm. Don't move them unless in immediate danger."

            lower.contains("earthquake") ->
                "Drop, Cover, and Hold On. Stay away from windows. After shaking stops, check for injuries and hazards before moving."

            lower.contains("flood") || lower.contains("water") ->
                "Move to higher ground immediately. Never walk or drive through flood water. 6 inches can knock you down, 2 feet can float a car."

            else ->
                "I'm here to help with emergency guidance. Tell me what's happening - fire, medical emergency, natural disaster, or other situation?"
        }
    }

    // ============================================================
    // SETTINGS
    // ============================================================

    fun setRelayEnabled(enabled: Boolean) {
        _relayEnabled.value = enabled
        if (enabled && !_isConnected.value) {
            connect()
        } else if (!enabled) {
            disconnect()
        }
    }
}
