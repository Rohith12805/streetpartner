package com.example.streetpartner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

class SosRestartReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_RESTART_SOS = "com.example.streetpartner.RESTART_SOS_SERVICE"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val serviceIntent = Intent(context, SosForegroundService::class.java).apply {
                action = SosForegroundService.ACTION_START_FOREGROUND_SERVICE
                intent?.getStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS)?.let {
                    putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, it)
                }
                intent?.getStringExtra("EXTRA_USER_ID")?.let { putExtra("EXTRA_USER_ID", it) }
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { putExtra("EXTRA_EMERGENCY_ID", it) }
                intent?.getStringExtra(SosForegroundService.EXTRA_MESSAGE)?.let { putExtra(SosForegroundService.EXTRA_MESSAGE, it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
