package com.mymoneydiary.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        const val CHANNEL_NAME = "com.mymoneydiary.app/auto_tracker"
        const val SMS_PERMISSION_REQ_CODE = 2001
        var methodChannel: MethodChannel? = null

        fun sendLiveTransaction(sender: String, body: String, timestamp: Long, source: String) {
            Handler(Looper.getMainLooper()).post {
                try {
                    val map = HashMap<String, Any>()
                    map["sender"] = sender
                    map["body"] = body
                    map["timestamp"] = timestamp
                    map["source"] = source
                    methodChannel?.invokeMethod("onLiveTransactionDetected", map)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    val readGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(readGranted && receiveGranted)
                }
                "requestSmsPermission" -> {
                    val readGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    if (readGranted && receiveGranted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                            SMS_PERMISSION_REQ_CODE
                        )
                    }
                }
                "isNotificationListenerEnabled" -> {
                    val packages = NotificationManagerCompat.getEnabledListenerPackages(this)
                    result.success(packages.contains(packageName))
                }
                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "readRecentSms" -> {
                    val limit = call.argument<Int>("limit") ?: 200
                    val list = readSmsMessages(limit)
                    result.success(list)
                }
                "sendSms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val uri = if (phone.isNotBlank()) {
                            Uri.parse("smsto:${Uri.encode(phone.trim())}")
                        } else {
                            Uri.parse("smsto:")
                        }
                        val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                            putExtra("sms_body", message)
                            putExtra(Intent.EXTRA_TEXT, message)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun readSmsMessages(limit: Int): List<Map<String, Any>> {
        val resultList = ArrayList<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return resultList
        }

        var cursor: Cursor? = null
        try {
            val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
            val projection = arrayOf(
                Telephony.Sms.Inbox._ID,
                Telephony.Sms.Inbox.ADDRESS,
                Telephony.Sms.Inbox.BODY,
                Telephony.Sms.Inbox.DATE
            )
            val sortOrder = "${Telephony.Sms.Inbox.DATE} DESC LIMIT $limit"

            cursor = contentResolver.query(uri, projection, null, null, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val idIdx = cursor.getColumnIndex(Telephony.Sms.Inbox._ID)
                val addressIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.ADDRESS)
                val bodyIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.BODY)
                val dateIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.DATE)

                do {
                    val id = if (idIdx >= 0) cursor.getString(idIdx) else ""
                    val address = if (addressIdx >= 0) cursor.getString(addressIdx) else ""
                    val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) else ""
                    val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                    val map = HashMap<String, Any>()
                    map["id"] = id
                    map["address"] = address ?: ""
                    map["body"] = body ?: ""
                    map["date"] = date
                    resultList.add(map)
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        return resultList
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQ_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }
}
