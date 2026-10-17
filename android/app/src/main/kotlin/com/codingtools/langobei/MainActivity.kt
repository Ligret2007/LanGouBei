package com.codingtools.langobei

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "langobei/export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val name = call.argument<String>("filename") ?: "langobei-export.json"
                        val content = call.argument<String>("content") ?: ""
                        try {
                            result.success(saveToDownloads(name, content))
                        } catch (e: Exception) {
                            result.error("save_failed", e.message ?: "写入失败", null)
                        }
                    }
                    "shareText" -> {
                        val subject = call.argument<String>("subject") ?: "LangoBei 学习数据"
                        val text = call.argument<String>("text") ?: ""
                        try {
                            shareText(subject, text)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message ?: "分享失败", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 优先落进系统「下载」目录；老系统没权限时退回应用自己的外部目录 */
    private fun saveToDownloads(name: String, content: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("无法在下载目录创建文件")
            contentResolver.openOutputStream(uri)?.use { out ->
                out.write(content.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("无法写入下载目录")
            return "下载/$name"
        }

        return try {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, name)
            file.writeText(content, Charsets.UTF_8)
            "下载/$name"
        } catch (_: Exception) {
            val dir = File(getExternalFilesDir(null), "exports")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, name)
            file.writeText(content, Charsets.UTF_8)
            file.absolutePath
        }
    }

    private fun shareText(subject: String, text: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(send, subject))
    }
}
