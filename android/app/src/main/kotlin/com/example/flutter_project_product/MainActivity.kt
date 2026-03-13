package com.example.flutter_project_product

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.whatsapp_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendToWhatsApp") {
                    val phone = call.argument<String>("phone")
                    val filePath = call.argument<String>("filePath")
                    val message = call.argument<String>("message")

                    if (phone.isNullOrEmpty() || filePath.isNullOrEmpty()) {
                        result.error("ERROR", "Faltan datos: teléfono o archivo.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val pm = packageManager

                        // Detectar qué WhatsApp está instalado
                        val hasWhatsApp = isAppInstalled(pm, "com.whatsapp")
                        val hasBusiness = isAppInstalled(pm, "com.whatsapp.w4b")

                        if (!hasWhatsApp && !hasBusiness) {
                            result.error("ERROR", "No se encontró ninguna versión de WhatsApp instalada.", null)
                            return@setMethodCallHandler
                        }

                        val packageName = if (hasBusiness) "com.whatsapp.w4b" else "com.whatsapp"

                        // 1️⃣ Abrir chat directo con el mensaje
                        val uri = Uri.parse("https://wa.me/$phone?text=${Uri.encode(message)}")
                        val intentChat = Intent(Intent.ACTION_VIEW, uri)
                        intentChat.setPackage(packageName)
                        startActivity(intentChat)

                        // 2️⃣ Compartir el archivo PDF (desde la app)
                        val file = File(filePath)
                        val fileUri = FileProvider.getUriForFile(
                            this,
                            applicationContext.packageName + ".provider",
                            file
                        )

                        val shareIntent = Intent(Intent.ACTION_SEND)
                        shareIntent.type = "application/pdf"
                        shareIntent.putExtra(Intent.EXTRA_STREAM, fileUri)
                        shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        shareIntent.setPackage(packageName)

                        // Enviar el intent de compartir (no forzamos contacto porque WhatsApp no lo permite con PDF)
                        startActivity(Intent.createChooser(shareIntent, "Compartir PDF con WhatsApp"))

                        result.success(true)

                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isAppInstalled(pm: PackageManager, packageName: String): Boolean {
        return try {
            pm.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }
}
