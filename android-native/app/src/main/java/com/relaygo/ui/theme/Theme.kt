package com.relaygo.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Colors matching iOS design
val EmergencyRed = Color(0xFFFF4444)
val Cyan = Color(0xFF00D9FF)
val Green = Color(0xFF00CC66)
val Orange = Color(0xFFFF8800)

private val DarkColorScheme = darkColorScheme(
    primary = EmergencyRed,
    secondary = Cyan,
    tertiary = Green,
    background = Color(0xFF0F0F1A),
    surface = Color(0xFF1A1A2E),
    onPrimary = Color.White,
    onSecondary = Color.Black,
    onBackground = Color(0xFFE4E4E7),
    onSurface = Color(0xFFE4E4E7),
)

private val LightColorScheme = lightColorScheme(
    primary = EmergencyRed,
    secondary = Cyan,
    tertiary = Green,
)

@Composable
fun RelayGoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
