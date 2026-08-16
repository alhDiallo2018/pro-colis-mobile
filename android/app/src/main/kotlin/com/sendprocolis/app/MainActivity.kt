package com.sendprocolis.app

// `local_auth` s'appuie sur BiometricPrompt, qui exige une FragmentActivity :
// avec FlutterActivity la demande d'empreinte echoue sans message.
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val badgeChannelName = "sendprocolis/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, badgeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBadgeCount" -> {
                        val count = (call.arguments as? Number)?.toInt() ?: 0
                        AppBadgeHelper.setBadge(this, count)
                        result.success(null)
                    }
                    "removeBadge" -> {
                        AppBadgeHelper.setBadge(this, 0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
