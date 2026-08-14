package com.example.streetpartner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class FakeCallAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FAKE_CALL_ALARM = "com.example.streetpartner.ACTION_FAKE_CALL_ALARM"
        const val EXTRA_CALL_ID = "EXTRA_CALL_ID"
        const val EXTRA_CALLER_NAME = "EXTRA_CALLER_NAME"
        const val EXTRA_PHONE_NUMBER = "EXTRA_PHONE_NUMBER"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Incoming Call"
        val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: ""
        val callId = intent.getStringExtra(EXTRA_CALL_ID) ?: ""

        // 1. Force wake up display using PowerManager WakeLock
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "Sheild:FakeCallWakeLock"
            )
            wakeLock.acquire(15000) // Acquire lock for 15s to ensure display turns on
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Play system default ringtone natively
        MainActivity.playRingtoneFromReceiver(context)

        // 3. Launch MainActivity over lock screen
        val activityIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("SHOW_FAKE_CALL", true)
            putExtra("CALL_ID", callId)
            putExtra("CALLER_NAME", callerName)
            putExtra("PHONE_NUMBER", phoneNumber)
        }

        try {
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
