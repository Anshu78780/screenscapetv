package com.example.screenscapetv

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.screenscapetv/vlc"
    private val DEVICE_INFO_CHANNEL = "com.example.screenscapetv/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // VLC Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchVLC") {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title")
                
                if (url != null) {
                    val success = launchVLC(url, title)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getTotalMemory") {
                val memoryMB = getTotalMemoryInMB()
                result.success(memoryMB)
            } else {
                result.notImplemented()
            }
        }
    }
    
    private fun getTotalMemoryInMB(): Int {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            
            // Convert bytes to MB
            val totalMemoryMB = (memInfo.totalMem / (1024 * 1024)).toInt()
            totalMemoryMB
        } catch (e: Exception) {
            e.printStackTrace()
            // Return high value on error to avoid false positive
            2048
        }
    }

    private fun launchVLC(url: String, title: String?): Boolean {
        return try {
            // Create intent to launch VLC
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(url), "video/*")
                setPackage("org.videolan.vlc")
                
                // Add extras for VLC
                if (title != null) {
                    putExtra("title", title)
                }
                
                // Add flags
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            
            // Check if VLC is installed
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                true
            } else {
                // VLC not installed, try without package specification
                val genericIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.parse(url), "video/*")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(genericIntent)
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
