package com.mymoneydiary.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class SmsNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        try {
            val packageName = sbn.packageName ?: ""
            val extras = sbn.notification?.extras ?: return

            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

            val combinedBody = when {
                bigText.isNotEmpty() -> "$title $bigText".trim()
                text.isNotEmpty() -> "$title $text".trim()
                else -> title.trim()
            }

            if (combinedBody.isEmpty()) return

            val lower = combinedBody.toLowerCase()
            val hasMoneyIndicator = lower.contains("rs") ||
                    lower.contains("inr") ||
                    lower.contains("₹") ||
                    lower.contains("debited") ||
                    lower.contains("credited") ||
                    lower.contains("paid") ||
                    lower.contains("received") ||
                    lower.contains("sent")

            if (hasMoneyIndicator) {
                val appLabel = packageToAppName(packageName)
                MainActivity.sendLiveTransaction(
                    sender = appLabel,
                    body = combinedBody,
                    timestamp = sbn.postTime,
                    source = "notification"
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun packageToAppName(pkg: String): String {
        return when {
            pkg.contains("paisa") || pkg.contains("nbu") -> "Google Pay"
            pkg.contains("phonepe") -> "PhonePe"
            pkg.contains("paytm") -> "Paytm"
            pkg.contains("dreamplug") -> "CRED"
            pkg.contains("npci.upiapp") -> "BHIM UPI"
            pkg.contains("hdfc") -> "HDFC Bank"
            pkg.contains("sbi") -> "SBI"
            pkg.contains("icici") -> "ICICI Bank"
            pkg.contains("axis") -> "Axis Bank"
            pkg.contains("kotak") -> "Kotak Bank"
            else -> "Bank / UPI App"
        }
    }
}
