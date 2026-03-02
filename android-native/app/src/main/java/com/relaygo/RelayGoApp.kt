package com.relaygo

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class RelayGoApp : Application() {

    companion object {
        const val FLUTTER_ENGINE_ID = "relaygo_engine"
    }

    lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()

        // Initialize Flutter engine at app startup
        flutterEngine = FlutterEngine(this)

        // Start executing Dart code
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Cache the engine for later use
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)
    }
}
