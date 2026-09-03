package com.yunxin.sendit

import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sendit/clipboard").setMethodCallHandler { call, result ->
            if (call.method == "readAll") {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = cm.primaryClip
                val parts = mutableListOf<String>()
                if (clip != null) {
                    for (i in 0 until clip.itemCount) {
                        val t = clip.getItemAt(i).coerceToText(this)?.toString()?.trim('\n', '\r')
                        if (!t.isNullOrEmpty()) parts.add(t)
                    }
                }
                result.success(parts.joinToString("\n\n"))
            } else {
                result.notImplemented()
            }
        }
    }
}
