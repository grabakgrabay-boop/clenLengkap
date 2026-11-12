package com.example.cleanerpro

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private fun availRam(): Long {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }.availMem
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cleaner").setMethodCallHandler { call, result ->
            when (call.method) {
                "availRam" -> result.success(availRam())

                "freeRam" -> Thread {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val before = availRam()
                    packageManager.getInstalledApplications(0)
                        .filter { it.packageName != packageName && (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
                        .forEach { am.killBackgroundProcesses(it.packageName) }
                    Thread.sleep(800)
                    val freed = (availRam() - before).coerceAtLeast(0)
                    runOnUiThread { result.success(freed) }
                }.start()

                // Semua aplikasi: pengguna, sistem, nonaktif, dan tanpa ikon launcher (tersembunyi)
                "listApps" -> Thread {
                    try {
                        val pm = packageManager
                        @Suppress("DEPRECATION")
                        val pkgs = pm.getInstalledPackages(PackageManager.MATCH_UNINSTALLED_PACKAGES)
                        val list = pkgs.mapNotNull { p ->
                            val ai = p.applicationInfo ?: return@mapNotNull null
                            if ((ai.flags and ApplicationInfo.FLAG_INSTALLED) == 0) return@mapNotNull null
                            mapOf(
                                "name" to ai.loadLabel(pm).toString(),
                                "package" to p.packageName,
                                "version" to (p.versionName ?: ""),
                                "system" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                                "enabled" to ai.enabled,
                                "launcher" to (pm.getLaunchIntentForPackage(p.packageName) != null),
                                "size" to File(ai.sourceDir).length()
                            )
                        }
                        runOnUiThread { result.success(list) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("ERR", e.message, null) }
                    }
                }.start()

                "openAppInfo" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${call.arguments}")))
                    result.success(null)
                }
                "uninstall" -> {
                    startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:${call.arguments}")))
                    result.success(null)
                }
                "openStorageSettings" -> {
                    startActivity(Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
