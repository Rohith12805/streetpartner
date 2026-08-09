package com.example.streetpartner

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private final val METHOD_CHANNEL = "com.example.streetpartner/sos_channel"
    private final val EVENT_CHANNEL = "com.example.streetpartner/sos_timer_events"
    private final val PERMISSION_REQUEST_CODE = 1001

    private var timerEventSink: EventChannel.EventSink? = null
    
    private val timerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == SosForegroundService.ACTION_TIMER_TICK) {
                val secondsLeft = intent.getIntExtra("secondsLeft", -1)
                timerEventSink?.success(secondsLeft)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle wake up intent from service
        if (intent.getBooleanExtra("SOS_ACTIVE", false)) {
            turnScreenOnAndKeyguardOff()
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("SOS_ACTIVE", false)) {
            turnScreenOnAndKeyguardOff()
        }
    }
    
    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        or WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register receiver for timer ticks
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(timerReceiver, IntentFilter(SosForegroundService.ACTION_TIMER_TICK), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(timerReceiver, IntentFilter(SosForegroundService.ACTION_TIMER_TICK))
        }

        // Setup EventChannel for streaming ticks
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    timerEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    timerEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: arrayListOf()
                    val message = call.argument<String>("message") ?: "EMERGENCY SOS: I need immediate help!"
                    
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_START_FOREGROUND_SERVICE
                        putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                        putExtra(SosForegroundService.EXTRA_MESSAGE, message)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }

                "triggerSosCountdown" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_TRIGGER_SOS
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "stopSosCountdown" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_STOP_SOS
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                


                "triggerSosAlert" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_EXECUTE_SOS_NOW
                    }
                    startService(serviceIntent)
                    
                    // Return mock success because the service handles the actual execution now
                    val response = hashMapOf<String, Any>(
                        "success" to true,
                        "smsStatus" to "Dispatched via background service",
                        "callStatus" to "Dispatched via background service",
                        "latitude" to 0.0,
                        "longitude" to 0.0,
                        "timestamp" to System.currentTimeMillis()
                    )
                    result.success(response)
                }

                "checkPermissions" -> {
                    val hasSms = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasCall = ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
                    val hasLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    
                    // Also check POST_NOTIFICATIONS for Android 13+
                    val hasNotification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }

                    val permissionMap = hashMapOf<String, Boolean>(
                        "sms" to hasSms,
                        "call" to hasCall,
                        "location" to hasLocation,
                        "notification" to hasNotification,
                        "allGranted" to (hasSms && hasCall && hasLocation && hasNotification)
                    )
                    result.success(permissionMap)
                }

                "requestPermissions" -> {
                    val permissions = mutableListOf(
                        Manifest.permission.SEND_SMS,
                        Manifest.permission.CALL_PHONE,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    
                    ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(timerReceiver)
    }
}
