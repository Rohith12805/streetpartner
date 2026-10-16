package com.example.streetpartner

import android.Manifest
import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.provider.Telephony

class MainActivity : FlutterActivity() {

    companion object {
        var staticRingtonePlayer: Ringtone? = null

        fun playRingtoneFromReceiver(context: Context) {
            try {
                stopRingtoneStatic()
                var ringtoneUri: Uri? = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                if (ringtoneUri == null) {
                    ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                }
                if (ringtoneUri == null) {
                    ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
                if (ringtoneUri != null) {
                    staticRingtonePlayer = RingtoneManager.getRingtone(context, ringtoneUri)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        staticRingtonePlayer?.isLooping = true
                    }
                    staticRingtonePlayer?.play()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun stopRingtoneStatic() {
            try {
                if (staticRingtonePlayer?.isPlaying == true) {
                    staticRingtonePlayer?.stop()
                }
                staticRingtonePlayer = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private final val METHOD_CHANNEL = "com.example.streetpartner/sos_channel"
    private final val EVENT_CHANNEL = "com.example.streetpartner/sos_timer_events"
    private final val SMS_EVENT_CHANNEL = "com.streetpartner.sms/events"
    private final val PERMISSION_REQUEST_CODE = 1001

    private var timerEventSink: EventChannel.EventSink? = null
    private var smsEventSink: EventChannel.EventSink? = null
    private var ringtonePlayer: Ringtone? = null
    private var methodChannel: MethodChannel? = null
    private var pendingFakeCallData: HashMap<String, Any>? = null
    
    private val timerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == SosForegroundService.ACTION_TIMER_TICK) {
                val secondsLeft = intent.getIntExtra("secondsLeft", -1)
                val isRouteDeviation = intent.getBooleanExtra("isRouteDeviation", false)
                val triggerSource = intent.getStringExtra("triggerSource") ?: "SOS Button"
                val map = hashMapOf<String, Any>(
                    "secondsLeft" to secondsLeft,
                    "isRouteDeviation" to isRouteDeviation,
                    "triggerSource" to triggerSource
                )
                timerEventSink?.success(map)
            }
        }
    }

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages != null && messages.isNotEmpty()) {
                    val sender = messages[0]?.displayOriginatingAddress ?: ""
                    val fullBody = StringBuilder()
                    for (sms in messages) {
                        if (sms != null) {
                            fullBody.append(sms.displayMessageBody ?: "")
                        }
                    }
                    val map = hashMapOf("address" to sender, "body" to fullBody.toString())
                    smsEventSink?.success(map)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleFakeCallIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleFakeCallIntent(intent)
    }

    private fun handleFakeCallIntent(intent: Intent?) {
        if (intent != null && intent.getBooleanExtra("SHOW_FAKE_CALL", false)) {
            turnScreenOnAndKeyguardOff()
            val callId = intent.getStringExtra("CALL_ID") ?: ""
            val callerName = intent.getStringExtra("CALLER_NAME") ?: "Incoming Call"
            val phoneNumber = intent.getStringExtra("PHONE_NUMBER") ?: ""
            val callData = hashMapOf<String, Any>(
                "id" to callId,
                "callerName" to callerName,
                "phoneNumber" to phoneNumber
            )
            pendingFakeCallData = callData
            methodChannel?.invokeMethod("onNativeFakeCallTriggered", callData)
        } else {
            disableShowWhenLocked()
        }
    }
    
    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            try {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    private fun disableShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
        @Suppress("DEPRECATION")
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    private fun scheduleNativeAlarm(callId: String, callerName: String, phoneNumber: String, triggerAtMillis: Long) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, FakeCallAlarmReceiver::class.java).apply {
                action = FakeCallAlarmReceiver.ACTION_FAKE_CALL_ALARM
                putExtra(FakeCallAlarmReceiver.EXTRA_CALL_ID, callId)
                putExtra(FakeCallAlarmReceiver.EXTRA_CALLER_NAME, callerName)
                putExtra(FakeCallAlarmReceiver.EXTRA_PHONE_NUMBER, phoneNumber)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                callId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val showIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("SHOW_FAKE_CALL", true)
                putExtra("CALL_ID", callId)
                putExtra("CALLER_NAME", callerName)
                putExtra("PHONE_NUMBER", phoneNumber)
            }
            val showPendingIntent = PendingIntent.getActivity(
                this,
                callId.hashCode() + 1,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun cancelNativeAlarm(callId: String) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, FakeCallAlarmReceiver::class.java).apply {
                action = FakeCallAlarmReceiver.ACTION_FAKE_CALL_ALARM
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                callId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                }
            }
        )


        // Register receiver for timer ticks
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(timerReceiver, IntentFilter(SosForegroundService.ACTION_TIMER_TICK), Context.RECEIVER_NOT_EXPORTED)
            registerReceiver(smsReceiver, IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION), Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(timerReceiver, IntentFilter(SosForegroundService.ACTION_TIMER_TICK))
            registerReceiver(smsReceiver, IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION))
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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel = channel

        pendingFakeCallData?.let {
            channel.invokeMethod("onNativeFakeCallTriggered", it)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNativeFakeCall" -> {
                    val id = call.argument<String>("id") ?: ""
                    val callerName = call.argument<String>("callerName") ?: "Incoming Call"
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val delayMs = call.argument<Number>("delayMs")?.toLong() ?: 10000L
                    val triggerAtMillis = System.currentTimeMillis() + delayMs

                    scheduleNativeAlarm(id, callerName, phoneNumber, triggerAtMillis)
                    result.success(true)
                }

                "cancelNativeFakeCall" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelNativeAlarm(id)
                    result.success(true)
                }

                "getInitialFakeCall" -> {
                    result.success(pendingFakeCallData)
                    pendingFakeCallData = null
                }

                "startForegroundService" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: arrayListOf()
                    val message = call.argument<String>("message") ?: "EMERGENCY SOS: I need immediate help!"
                    val userId = call.argument<String>("userId") ?: "unknown"
                    val emergencyId = call.argument<String>("emergencyId") ?: ""
                    
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_START_FOREGROUND_SERVICE
                        putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                        putExtra(SosForegroundService.EXTRA_MESSAGE, message)
                        putExtra("EXTRA_USER_ID", userId)
                        putExtra("EXTRA_EMERGENCY_ID", emergencyId)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }

                "stopForegroundService" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java)
                    stopService(serviceIntent)
                    result.success(true)
                }

                "triggerSosCountdown" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: arrayListOf()
                    val message = call.argument<String>("message") ?: "EMERGENCY SOS: I need immediate help!"
                    val userId = call.argument<String>("userId") ?: "unknown"
                    val emergencyId = call.argument<String>("emergencyId") ?: ""
                    val triggerSource = call.argument<String>("triggerSource") ?: "SOS Button"

                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_TRIGGER_SOS
                        putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                        putExtra(SosForegroundService.EXTRA_MESSAGE, message)
                        putExtra("EXTRA_USER_ID", userId)
                        putExtra("EXTRA_EMERGENCY_ID", emergencyId)
                        putExtra("EXTRA_TRIGGER_SOURCE", triggerSource)
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

                "stopLiveLocation" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = "ACTION_STOP_LIVE_LOCATION"
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "getServiceStatus" -> {
                    val status = SosForegroundService.readServiceStatus(this)
                    result.success(status)
                }

                "startGeofenceMonitoring" -> {
                    val lat = call.argument<Double>("lat") ?: 0.0
                    val lng = call.argument<Double>("lng") ?: 0.0
                    val radius = call.argument<Double>("radius")?.toFloat() ?: 500f
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: arrayListOf()
                    val userId = call.argument<String>("userId") ?: ""
                    
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_START_GEOFENCE
                        putExtra("lat", lat)
                        putExtra("lng", lng)
                        putExtra("radius", radius)
                        putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                        putExtra("EXTRA_USER_ID", userId)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }

                "startRouteMonitoring" -> {
                    val polyline = call.argument<List<Map<String, Double>>>("polyline") ?: arrayListOf()
                    val lats = polyline.map { it["lat"] ?: 0.0 }.toDoubleArray()
                    val lngs = polyline.map { it["lng"] ?: 0.0 }.toDoubleArray()
                    
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_START_ROUTE
                        putExtra("polyLats", lats)
                        putExtra("polyLngs", lngs)
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "updateRouteMonitoring" -> {
                    val polyline = call.argument<List<Map<String, Double>>>("polyline") ?: arrayListOf()
                    val lats = polyline.map { it["lat"] ?: 0.0 }.toDoubleArray()
                    val lngs = polyline.map { it["lng"] ?: 0.0 }.toDoubleArray()
                    
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_UPDATE_ROUTE
                        putExtra("polyLats", lats)
                        putExtra("polyLngs", lngs)
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "stopMonitoring" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_STOP_MONITORING
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "triggerSosAlert" -> {
                    val userId = call.argument<String>("userId") ?: "unknown"
                    val emergencyId = call.argument<String>("emergencyId") ?: ""
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: arrayListOf()
                    val message = call.argument<String>("message") ?: "EMERGENCY SOS: I need immediate help!"

                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_EXECUTE_SOS_NOW
                        putExtra("EXTRA_USER_ID", userId)
                        putExtra("EXTRA_EMERGENCY_ID", emergencyId)
                        putStringArrayListExtra(SosForegroundService.EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                        putExtra(SosForegroundService.EXTRA_MESSAGE, message)
                    }
                    startService(serviceIntent)
                    
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
                    
                    val hasNotification = true

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
                    
                    ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
                    result.success(true)
                }

                "playRingtone" -> {
                    playRingtoneFromReceiver(applicationContext)
                    result.success(true)
                }

                "stopRingtone" -> {
                    stopRingtoneStatic()
                    stopRingtone()
                    result.success(true)
                }

                "playAlarmSound" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_PLAY_ALARM
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "stopAlarmSound" -> {
                    val serviceIntent = Intent(this, SosForegroundService::class.java).apply {
                        action = SosForegroundService.ACTION_STOP_ALARM
                    }
                    startService(serviceIntent)
                    result.success(true)
                }

                "wakeUpScreen" -> {
                    try {
                        turnScreenOnAndKeyguardOff()
                        val wakeIntent = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            putExtra("FAKE_CALL_ACTIVE", true)
                        }
                        startActivity(wakeIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKE_ERROR", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun stopRingtone() {
        try {
            if (ringtonePlayer?.isPlaying == true) {
                ringtonePlayer?.stop()
            }
            ringtonePlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRingtoneStatic()
        stopRingtone()
        unregisterReceiver(timerReceiver)
        unregisterReceiver(smsReceiver)
    }
}
