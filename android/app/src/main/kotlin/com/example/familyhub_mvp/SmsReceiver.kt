package com.example.familyhub_mvp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    private var channel: MethodChannel? = null
    
    fun setMethodChannel(channel: MethodChannel) {
        this.channel = channel
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (smsMessage in messages) {
                val phoneNumber = smsMessage.originatingAddress ?: ""
                val messageBody = smsMessage.messageBody ?: ""
                val timestamp = smsMessage.timestampMillis
                
                // Send to Flutter via MethodChannel
                channel?.invokeMethod("onSmsReceived", mapOf(
                    "phoneNumber" to phoneNumber,
                    "message" to messageBody,
                    "timestamp" to timestamp
                ))
            }
        }
    }
}

