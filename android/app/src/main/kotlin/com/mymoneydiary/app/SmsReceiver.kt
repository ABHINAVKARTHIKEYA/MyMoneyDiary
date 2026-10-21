package com.mymoneydiary.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) return

                val sender = messages[0].displayOriginatingAddress ?: ""
                val bodyBuilder = StringBuilder()
                var timestamp = System.currentTimeMillis()

                for (msg in messages) {
                    bodyBuilder.append(msg.displayMessageBody)
                    timestamp = msg.timestampMillis
                }

                val fullBody = bodyBuilder.toString()
                if (fullBody.isNotEmpty()) {
                    MainActivity.sendLiveTransaction(
                        sender = sender,
                        body = fullBody,
                        timestamp = timestamp,
                        source = "sms"
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
