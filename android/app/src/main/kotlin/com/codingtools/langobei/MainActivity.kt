package com.codingtools.langobei

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val exportChannel = "langobei/export"
    private val bankChannel = "langobei/bank"

    private var frameRateAttempts = 0

    /** 文件选择器是异步的，结果回来之前先把 Dart 侧的回调存着 */
    private var pendingPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 等 FlutterView 挂上去以后再请求，太早的话 Surface 还没建好
        window.decorView.postDelayed({ requestPeakRefreshRate() }, 400L)
    }

    /**
     * 让系统按屏幕峰值刷新率出帧。
     *
     * Android 默认会把普通 App 的渲染率压在 60Hz（哪怕屏幕是 120Hz），
     * 这里显式请求：Android 15+ 用 View.setRequestedFrameRate，
     * Android 11-14 直接给窗口里那个 SurfaceView 的 Surface 设帧率。
     * 60Hz 屏上直接返回，不改任何东西。
     */
    private fun requestPeakRefreshRate() {
        val peak = peakRefreshRate()
        if (peak < 90f) return

        if (Build.VERSION.SDK_INT >= 35) {
            window.decorView.setRequestedFrameRate(peak)
        }
        if (Build.VERSION.SDK_INT >= 30) {
            val surface = findSurfaceView(window.decorView)?.holder?.surface
            if (surface != null && surface.isValid) {
                surface.setFrameRate(peak, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
            } else if (frameRateAttempts < 4) {
                // Surface 还没就绪，稍后再试
                frameRateAttempts++
                window.decorView.postDelayed({ requestPeakRefreshRate() }, 400L)
            }
        }
    }

    private fun peakRefreshRate(): Float {
        if (Build.VERSION.SDK_INT < 30) {
            @Suppress("DEPRECATION")
            return windowManager.defaultDisplay?.refreshRate ?: 0f
        }
        val dsp = display ?: return 0f
        return dsp.supportedModes.map { it.refreshRate }.maxOrNull() ?: dsp.refreshRate
    }

    private fun findSurfaceView(v: View): SurfaceView? {
        if (v is SurfaceView) return v
        if (v is ViewGroup) {
            for (i in 0 until v.childCount) {
                findSurfaceView(v.getChildAt(i))?.let { return it }
            }
        }
        return null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bankChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "listBanks" -> result.success(listBankIds())
                        "readBank" -> result.success(readBank(call.argument<String>("id") ?: ""))
                        "writeBank" -> {
                            writeBank(
                                call.argument<String>("id") ?: "",
                                call.argument<String>("content") ?: "",
                            )
                            result.success(null)
                        }
                        "deleteBank" -> {
                            deleteBank(call.argument<String>("id") ?: "")
                            result.success(null)
                        }
                        "readIndex" -> result.success(readIndex())
                        "writeIndex" -> {
                            writeIndex(call.argument<String>("content") ?: "")
                            result.success(null)
                        }
                        "pickBankFile" -> pickBankFile(result)
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("bank_io", e.message ?: "词库读写失败", null)
                }
            }
    }

    // ---------------- 词库文件 ----------------
    // 放在 App 私有目录 files/banks/ 下：不需要任何存储权限，卸载即清除。

    private fun bankDir(): File {
        val dir = File(filesDir, "banks")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun bankFile(id: String): File? {
        val safe = id.replace(Regex("[^A-Za-z0-9_-]"), "_").take(64)
        if (safe.isEmpty()) return null
        return File(bankDir(), "$safe.json")
    }

    private fun listBankIds(): List<String> =
        bankDir().listFiles()
            ?.filter { it.isFile && it.name.endsWith(".json") && it.name != INDEX_FILE }
            ?.map { it.name.removeSuffix(".json") }
            ?.sorted()
            ?: emptyList()

    private fun readBank(id: String): String? =
        bankFile(id)?.takeIf { it.isFile }?.readText(Charsets.UTF_8)

    private fun writeBank(id: String, content: String) {
        val file = bankFile(id) ?: throw IllegalArgumentException("词库 id 不合法")
        file.writeText(content, Charsets.UTF_8)
    }

    private fun deleteBank(id: String) {
        bankFile(id)?.takeIf { it.isFile }?.delete()
    }

    private fun readIndex(): String? =
        File(bankDir(), INDEX_FILE).takeIf { it.isFile }?.readText(Charsets.UTF_8)

    private fun writeIndex(content: String) {
        File(bankDir(), INDEX_FILE).writeText(content, Charsets.UTF_8)
    }

    /** 拉起系统文件管理器选一个词库文件，读成文本回给 Dart；取消返回 null */
    private fun pickBankFile(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "已经有一个文件选择在进行中", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/plain", "text/*", "application/octet-stream"),
            )
        }
        pendingPick = result
        try {
            startActivityForResult(intent, PICK_REQUEST)
        } catch (e: Exception) {
            pendingPick = null
            result.error("no_picker", e.message ?: "这台设备没有可用的文件选择器", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }
        try {
            val text = contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: throw IllegalStateException("文件是空的或者打不开")
            // 文件名要一起回去：Dart 侧没写 id/name 的词库会用文件名兜底取名
            pending.success(mapOf("name" to displayNameOf(uri), "content" to text))
        } catch (e: Exception) {
            pending.error("read_failed", e.message ?: "读不了这个文件", null)
        }
    }

    /** 从 content Uri 里问出用户在文件管理器里看到的文件名 */
    private fun displayNameOf(uri: android.net.Uri): String {
        val projection = arrayOf(android.provider.OpenableColumns.DISPLAY_NAME)
        runCatching {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val name = cursor.getString(0)
                    if (!name.isNullOrBlank()) return name
                }
            }
        }
        return uri.lastPathSegment ?: "imported.json"
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

    private companion object {
        const val PICK_REQUEST = 4201
        const val INDEX_FILE = "_index.json"
    }
}
