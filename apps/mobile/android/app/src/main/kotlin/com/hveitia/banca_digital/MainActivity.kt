package com.hveitia.banca_digital

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// The biometric prompt is a fragment, so the activity must be able to host one.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Answers the app when the customer asks to turn notifications on
        // after having refused the system prompt: only Settings can do it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == OPEN_NOTIFICATION_SETTINGS) {
                    openNotificationSettings()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    // Android 8 and later show a notification only through a channel. Without
    // one of its own, the messaging service files every push under a generic
    // "Miscellaneous" channel the customer cannot make sense of in Settings.
    // The id must match default_notification_channel_id in the manifest.
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Avisos de tu banco",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Movimientos, seguridad y beneficios."
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(android.net.Uri.fromParts("package", packageName, null))
        }
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private companion object {
        const val CHANNEL_ID = "customer_notifications"
        const val SETTINGS_CHANNEL = "banca_digital/system_settings"
        const val OPEN_NOTIFICATION_SETTINGS = "openNotificationSettings"
    }
}
