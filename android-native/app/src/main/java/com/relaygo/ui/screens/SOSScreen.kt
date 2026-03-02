package com.relaygo.ui.screens

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.relaygo.RelayViewModel
import com.relaygo.ui.theme.EmergencyRed
import com.relaygo.ui.theme.Green

@Composable
fun SOSScreen(
    viewModel: RelayViewModel,
    modifier: Modifier = Modifier
) {
    val isConnected by viewModel.isConnected.collectAsState()
    val isConnecting by viewModel.isConnecting.collectAsState()
    val sosActive by viewModel.sosActive.collectAsState()
    val peerCount by viewModel.peerCount.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Title
        Text(
            text = "RelayGo",
            fontSize = 32.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 3.sp,
            color = MaterialTheme.colorScheme.onBackground
        )
        Text(
            text = "Emergency Mesh Network",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
        )

        Spacer(modifier = Modifier.height(48.dp))

        // SOS Button
        SOSButton(
            isActive = sosActive,
            isConnecting = isConnecting,
            onClick = { viewModel.triggerSOS() }
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Status
        StatusIndicator(
            isConnected = isConnected,
            isConnecting = isConnecting,
            sosActive = sosActive,
            peerCount = peerCount
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Cancel button when SOS active
        if (sosActive) {
            OutlinedButton(
                onClick = { viewModel.cancelSOS() },
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = EmergencyRed
                )
            ) {
                Text("Cancel SOS")
            }
        }
    }
}

@Composable
private fun SOSButton(
    isActive: Boolean,
    isConnecting: Boolean,
    onClick: () -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isActive) 1.1f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Box(contentAlignment = Alignment.Center) {
        // Pulsing background when active
        if (isActive) {
            Box(
                modifier = Modifier
                    .size(260.dp)
                    .scale(scale)
                    .clip(CircleShape)
                    .background(EmergencyRed.copy(alpha = 0.2f))
            )
        }

        // Main button
        Button(
            onClick = onClick,
            enabled = !isConnecting,
            modifier = Modifier
                .size(200.dp)
                .shadow(
                    elevation = if (isActive) 30.dp else 15.dp,
                    shape = CircleShape,
                    ambientColor = EmergencyRed,
                    spotColor = EmergencyRed
                ),
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(
                containerColor = EmergencyRed,
                contentColor = Color.White
            )
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "SOS",
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold
                )
                if (isActive) {
                    Text(
                        text = "ACTIVE",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusIndicator(
    isConnected: Boolean,
    isConnecting: Boolean,
    sosActive: Boolean,
    peerCount: Int
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Status dot
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(
                    when {
                        isConnecting -> Color(0xFFFFA500) // Orange
                        isConnected -> Green
                        else -> Color.Gray
                    }
                )
        )

        // Status text
        Text(
            text = when {
                isConnecting -> "Connecting..."
                sosActive -> "SOS Broadcast Active"
                isConnected -> "Connected to Mesh"
                else -> "Not Connected"
            },
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
        )

        // Peer count
        if (peerCount > 0) {
            Text(
                text = "($peerCount nearby)",
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f)
            )
        }
    }
}
