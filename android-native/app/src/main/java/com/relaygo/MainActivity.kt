package com.relaygo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.lifecycle.viewmodel.compose.viewModel
import com.relaygo.ui.screens.ChatScreen
import com.relaygo.ui.screens.NearbyScreen
import com.relaygo.ui.screens.SOSScreen
import com.relaygo.ui.screens.SettingsScreen
import com.relaygo.ui.theme.RelayGoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            RelayGoTheme(darkTheme = true) {
                RelayGoApp()
            }
        }
    }
}

@Composable
fun RelayGoApp(
    viewModel: RelayViewModel = viewModel()
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val unreadCount by viewModel.unreadCount.collectAsState()

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(painterResource(R.drawable.ic_sos), contentDescription = null) },
                    label = { Text("SOS") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(painterResource(R.drawable.ic_chat), contentDescription = null) },
                    label = { Text("Assistant") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = {
                        selectedTab = 2
                        viewModel.markAsRead()
                    },
                    icon = {
                        BadgedBox(
                            badge = {
                                if (unreadCount > 0) {
                                    Badge { Text(unreadCount.toString()) }
                                }
                            }
                        ) {
                            Icon(painterResource(R.drawable.ic_nearby), contentDescription = null)
                        }
                    },
                    label = { Text("Nearby") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(painterResource(R.drawable.ic_settings), contentDescription = null) },
                    label = { Text("Settings") }
                )
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> SOSScreen(viewModel, Modifier.padding(padding))
            1 -> ChatScreen(viewModel, Modifier.padding(padding))
            2 -> NearbyScreen(viewModel, Modifier.padding(padding))
            3 -> SettingsScreen(viewModel, Modifier.padding(padding))
        }
    }
}
