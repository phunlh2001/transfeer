package com.transfeer.transfeer

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Small native bridge for the in-app updater:
 *  - updatesDir: folder (inside app storage) where the zip/APK are written
 *  - installApk: hands the extracted APK to the Android package installer
 */
class MainActivity : FlutterActivity() {
    private val channelName = "transfeer/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updatesDir" -> {
                        val dir = File(filesDir, "updates")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !File(path).exists()) {
                            result.error("NO_FILE", "APK not found", null)
                            return@setMethodCallHandler
                        }
                        result.success(installApk(File(path)))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Returns "started", or "needs_permission" after opening the settings page. */
    private fun installApk(apk: File): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            return "needs_permission"
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.update_provider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return "started"
    }
}
