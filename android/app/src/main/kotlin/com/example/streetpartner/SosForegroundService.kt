package com.example.streetpartner

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationManager
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.app.AlarmManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telecom.TelecomManager
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.sqrt
import com.google.firebase.firestore.FirebaseFirestore
import android.os.Handler
import android.os.Looper
import android.location.LocationListener

class SosForegroundService : Service(), SensorEventListener {

    companion object {
        const val NOTIFICATION_ID = 101
        const val CHANNEL_ID = "SosServiceChannel_v3"
        const val ACTION_START_FOREGROUND_SERVICE = "ACTION_START_FOREGROUND_SERVICE"
        const val ACTION_STOP_FOREGROUND_SERVICE = "ACTION_STOP_FOREGROUND_SERVICE"
        const val ACTION_TRIGGER_SOS = "ACTION_TRIGGER_SOS"
        const val ACTION_STOP_SOS = "ACTION_STOP_SOS"
        const val ACTION_EXECUTE_SOS_NOW = "ACTION_EXECUTE_SOS_NOW"
        const val ACTION_TIMER_TICK = "com.example.streetpartner.TIMER_TICK"
        
        const val EXTRA_PHONE_NUMBERS = "EXTRA_PHONE_NUMBERS"
        const val EXTRA_MESSAGE = "EXTRA_MESSAGE"
        const val EXTRA_CALL_EMERGENCY = "EXTRA_CALL_EMERGENCY"
        const val ACTION_STOP_LIVE_LOCATION = "ACTION_STOP_LIVE_LOCATION"
        
        const val ACTION_START_GEOFENCE = "ACTION_START_GEOFENCE"
        const val ACTION_START_ROUTE = "ACTION_START_ROUTE"
        const val ACTION_UPDATE_ROUTE = "ACTION_UPDATE_ROUTE"
        const val ACTION_STOP_MONITORING = "ACTION_STOP_MONITORING"
        const val ACTION_PLAY_ALARM = "ACTION_PLAY_ALARM"
        const val ACTION_STOP_ALARM = "ACTION_STOP_ALARM"

        var isLiveLocationActive = false
        var isCountingDown = false
        var currentSecondsLeft = -1
        var isRouteDeviation = false
        var currentTriggerSource = "SOS Button"

        fun updateServiceStateFile(
            context: Context,
            liveActive: Boolean = isLiveLocationActive,
            countingDown: Boolean = isCountingDown,
            seconds: Int = currentSecondsLeft,
            deviation: Boolean = isRouteDeviation,
            triggerSource: String = currentTriggerSource
        ) {
            try {
                isLiveLocationActive = liveActive
                isCountingDown = countingDown
                currentSecondsLeft = seconds
                isRouteDeviation = deviation
                currentTriggerSource = triggerSource

                val deadlineMs = if (countingDown && seconds > 0) {
                    System.currentTimeMillis() + (seconds * 1000L)
                } else 0L

                val json = org.json.JSONObject().apply {
                    put("isLiveLocationActive", liveActive)
                    put("isCountingDown", countingDown)
                    put("secondsLeft", seconds)
                    put("countdownDeadlineMs", deadlineMs)
                    put("isRouteDeviation", deviation)
                    put("triggerSource", triggerSource)
                    put("lastUpdatedMs", System.currentTimeMillis())
                }

                val file = java.io.File(context.filesDir, "shield_service_status.json")
                file.writeText(json.toString())
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun readServiceStatus(context: Context): Map<String, Any> {
            var liveActive = isLiveLocationActive
            var countingDown = isCountingDown
            var secondsLeft = currentSecondsLeft
            var routeDeviation = isRouteDeviation
            var triggerSource = currentTriggerSource

            try {
                // 1. Check SharedPreferences first for authoritative state
                val guardPrefs = context.getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
                val countPrefs = context.getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)

                if (guardPrefs.getBoolean("is_live_location", false)) {
                    liveActive = true
                    isLiveLocationActive = true
                }

                if (countPrefs.getBoolean("is_counting_down", false)) {
                    val deadlineMs = countPrefs.getLong("countdown_deadline_ms", 0L)
                    val remainingMs = deadlineMs - System.currentTimeMillis()
                    if (remainingMs > 500) {
                        countingDown = true
                        secondsLeft = ((remainingMs + 999) / 1000).toInt()
                        routeDeviation = countPrefs.getBoolean("is_route_deviation", false)
                        triggerSource = countPrefs.getString("trigger_source", triggerSource) ?: triggerSource
                    } else {
                        // Countdown completed while app was closed!
                        countingDown = false
                        secondsLeft = 0
                        liveActive = true
                        isLiveLocationActive = true
                    }
                }

                // 2. Also check file if available
                val file = java.io.File(context.filesDir, "shield_service_status.json")
                if (file.exists()) {
                    val content = file.readText()
                    if (content.isNotBlank()) {
                        val json = org.json.JSONObject(content)
                        if (json.optBoolean("isLiveLocationActive", false)) {
                            liveActive = true
                            isLiveLocationActive = true
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            return mapOf(
                "isLiveLocationActive" to liveActive,
                "isCountingDown" to (countingDown && secondsLeft > 0),
                "secondsLeft" to secondsLeft,
                "isRouteDeviation" to routeDeviation,
                "triggerSource" to triggerSource
            )
        }

        fun getServiceStatus(): Map<String, Any> {
            return mapOf(
                "isLiveLocationActive" to isLiveLocationActive,
                "isCountingDown" to isCountingDown,
                "secondsLeft" to currentSecondsLeft,
                "isRouteDeviation" to isRouteDeviation,
                "triggerSource" to currentTriggerSource
            )
        }
    }

    private fun getFirestore(): FirebaseFirestore {
        return FirebaseFirestore.getInstance()
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var ringtone: Ringtone? = null
    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null
    private var alarmWakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    // Shake detection tracking parameters
    private var shakeCount = 0
    private var lastShakeTime: Long = 0
    private val SHAKE_THRESHOLD = 2.5f
    private val SHAKE_SLOP_TIME_MS = 500
    private val SHAKE_COUNT_RESET_TIME_MS = 2500

    private var countDownTimer: CountDownTimer? = null
    private var phoneNumbers: List<String> = emptyList()
    private var sosMessage: String = "EMERGENCY SOS: I need immediate help!"
    private var callEmergency: Boolean = true
    private var userId: String = "unknown"
    private var emergencyId: String = ""

    private var monitoringMode: String = "NONE"
    private var geofenceCenter: Location? = null
    private var geofenceRadius: Float = 0f
    private var routePolyline: List<Location> = emptyList()
    private val liveLocationHandler = Handler(Looper.getMainLooper())
    private var liveLocationRunnable: Runnable? = null
    private val LIVE_LOCATION_INTERVAL_MS: Long = 10000 // 10 seconds
    private var liveLocationStartTime: Long = 0

    private var latestLocation: Location? = null
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            // Ignore inaccurate location fixes (> 100m accuracy) to prevent false SOS alerts
            if (location.hasAccuracy() && location.accuracy > 100f) {
                return
            }
            latestLocation = location
            checkSafetyRules(location)
        }
        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    private fun getEmergencyServiceNumbers(): Set<String> {
        return setOf("112", "911", "100", "101", "108")
    }

    private fun resolveUserId(): String {
        if (userId.isNotBlank() && userId != "unknown") return userId

        // 1. Try FirebaseAuth directly
        try {
            val authUid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid
            if (!authUid.isNullOrBlank()) {
                userId = authUid
                persistGuardState()
                return userId
            }
        } catch (_: Exception) {}

        // 2. Try sheild_guard_prefs
        try {
            val guardPrefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
            val savedGuardUid = guardPrefs.getString("user_id", null)
            if (!savedGuardUid.isNullOrBlank() && savedGuardUid != "unknown") {
                userId = savedGuardUid
                return userId
            }
        } catch (_: Exception) {}

        // 3. Try sheild_countdown_prefs
        try {
            val countPrefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
            val savedCountUid = countPrefs.getString("user_id", null)
            if (!savedCountUid.isNullOrBlank() && savedCountUid != "unknown") {
                userId = savedCountUid
                return userId
            }
        } catch (_: Exception) {}

        // 4. Try FlutterSharedPreferences
        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val flutterUid = flutterPrefs.getString("flutter.user_id", null)
            if (!flutterUid.isNullOrBlank() && flutterUid != "unknown") {
                userId = flutterUid
                return userId
            }
        } catch (_: Exception) {}

        return userId
    }

    private fun resolvePhoneNumbers(): List<String> {
        val blocked = getEmergencyServiceNumbers()
        if (phoneNumbers.isNotEmpty()) {
            val clean = phoneNumbers.map { it.trim() }.filter { it.isNotBlank() && !blocked.contains(it) }
            if (clean.isNotEmpty()) {
                phoneNumbers = clean
                return phoneNumbers
            }
        }

        // 1. Try sheild_guard_prefs
        try {
            val guardPrefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
            val savedGuard = guardPrefs.getString("phone_numbers", null)
            if (!savedGuard.isNullOrBlank()) {
                val list = savedGuard.split(",").map { it.trim() }.filter { it.isNotBlank() && !blocked.contains(it) }
                if (list.isNotEmpty()) {
                    phoneNumbers = list
                    return phoneNumbers
                }
            }
        } catch (_: Exception) {}

        // 2. Try sheild_countdown_prefs
        try {
            val countPrefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
            val savedCount = countPrefs.getString("phone_numbers", null)
            if (!savedCount.isNullOrBlank()) {
                val list = savedCount.split(",").map { it.trim() }.filter { it.isNotBlank() && !blocked.contains(it) }
                if (list.isNotEmpty()) {
                    phoneNumbers = list
                    return phoneNumbers
                }
            }
        } catch (_: Exception) {}

        // 3. Try FlutterSharedPreferences (flutter.cached_emergency_contacts)
        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonString = flutterPrefs.getString("flutter.cached_emergency_contacts", null)
            if (!jsonString.isNullOrBlank()) {
                try {
                    val jsonArray = org.json.JSONArray(jsonString)
                    val list = mutableListOf<String>()
                    for (i in 0 until jsonArray.length()) {
                        val num = jsonArray.optString(i, "").trim()
                        if (num.isNotBlank() && !blocked.contains(num)) {
                            list.add(num)
                        }
                    }
                    if (list.isNotEmpty()) {
                        phoneNumbers = list
                        persistGuardState()
                        return phoneNumbers
                    }
                } catch (_: Exception) {}
            }
            val stringSet = flutterPrefs.getStringSet("flutter.cached_emergency_contacts", null)
            if (!stringSet.isNullOrEmpty()) {
                val list = stringSet.map { it.trim() }.filter { it.isNotBlank() && !blocked.contains(it) }
                if (list.isNotEmpty()) {
                    phoneNumbers = list
                    persistGuardState()
                    return phoneNumbers
                }
            }
        } catch (_: Exception) {}

        return phoneNumbers
    }

    private fun persistGuardState() {
        try {
            val guardPrefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
            val editor = guardPrefs.edit()
            if (phoneNumbers.isNotEmpty()) {
                editor.putString("phone_numbers", phoneNumbers.joinToString(","))
            }
            if (userId.isNotBlank() && userId != "unknown") {
                editor.putString("user_id", userId)
            }
            if (sosMessage.isNotBlank()) {
                editor.putString("sos_message", sosMessage)
            }
            editor.putBoolean("is_live_location", isLiveLocationActive)
            if (emergencyId.isNotBlank()) {
                editor.putString("emergency_id", emergencyId)
            }
            editor.commit()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initSensorManager()
        resolveUserId()
        resolvePhoneNumbers()
        restorePersistedMonitoring()
        checkAndRestoreActiveCountdown()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)

        resolveUserId()
        resolvePhoneNumbers()
        persistGuardState()

        if (isCountingDown) {
            val countPrefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
            val deadlineMs = System.currentTimeMillis() + (currentSecondsLeft * 1000L)
            countPrefs.edit()
                .putBoolean("is_counting_down", true)
                .putLong("countdown_deadline_ms", deadlineMs)
                .putBoolean("is_route_deviation", isRouteDeviation)
                .putString("trigger_source", currentTriggerSource)
                .putString("user_id", userId)
                .putString("phone_numbers", phoneNumbers.joinToString(","))
                .putString("sos_message", sosMessage)
                .commit()
        }

        try {
            val restartIntent = Intent(applicationContext, SosRestartReceiver::class.java).apply {
                action = SosRestartReceiver.ACTION_RESTART_SOS
                putStringArrayListExtra(EXTRA_PHONE_NUMBERS, ArrayList(phoneNumbers))
                putExtra("EXTRA_USER_ID", userId)
                putExtra("EXTRA_EMERGENCY_ID", emergencyId)
                putExtra(EXTRA_MESSAGE, sosMessage)
            }
            val restartPendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                1003,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager?.setAlarmClock(
                    AlarmManager.AlarmClockInfo(System.currentTimeMillis() + 100, restartPendingIntent),
                    restartPendingIntent
                )
            } else {
                alarmManager?.setExact(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + 100,
                    restartPendingIntent
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        var action = intent?.action
        
        if (action == null) {
            // Service restarted by OS - restore persisted monitoring
            resolveUserId()
            resolvePhoneNumbers()
            restorePersistedMonitoring()
            if (!checkAndRestoreActiveCountdown()) {
                startOrUpdateForeground(-1)
            }
            updateServiceStateFile(this, liveActive = isLiveLocationActive, countingDown = isCountingDown, seconds = currentSecondsLeft)
            return START_STICKY
        }

        when (action) {
            ACTION_START_FOREGROUND_SERVICE -> {
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { list ->
                    val clean = list.filter { it.isNotBlank() && !getEmergencyServiceNumbers().contains(it.trim()) }
                    if (clean.isNotEmpty()) {
                        phoneNumbers = clean
                    }
                }
                intent?.getStringExtra("EXTRA_USER_ID")?.let { if (it.isNotBlank() && it != "unknown") userId = it }
                intent?.getStringExtra(EXTRA_MESSAGE)?.let { if (it.isNotBlank()) sosMessage = it }
                callEmergency = intent?.getBooleanExtra(EXTRA_CALL_EMERGENCY, true) ?: callEmergency
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }

                resolveUserId()
                resolvePhoneNumbers()
                persistGuardState()

                if (!checkAndRestoreActiveCountdown()) {
                    startOrUpdateForeground(-1)
                }
                updateServiceStateFile(this, liveActive = isLiveLocationActive, countingDown = isCountingDown, seconds = currentSecondsLeft)
            }
            ACTION_TRIGGER_SOS -> {
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { list ->
                    val clean = list.filter { it.isNotBlank() && !getEmergencyServiceNumbers().contains(it.trim()) }
                    if (clean.isNotEmpty()) {
                        phoneNumbers = clean
                    }
                }
                intent?.getStringExtra("EXTRA_USER_ID")?.let { if (it.isNotBlank() && it != "unknown") userId = it }
                intent?.getStringExtra(EXTRA_MESSAGE)?.let { if (it.isNotBlank()) sosMessage = it }
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }

                resolveUserId()
                resolvePhoneNumbers()
                persistGuardState()

                currentTriggerSource = intent?.getStringExtra("EXTRA_TRIGGER_SOURCE") ?: "SOS Button"
                startOrUpdateForeground(-1)
                startSosCountdown()
            }
            ACTION_STOP_SOS -> {
                startOrUpdateForeground(-1)
                stopSosCountdown()
            }
            ACTION_EXECUTE_SOS_NOW -> {
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { list ->
                    val clean = list.filter { it.isNotBlank() && it != "112" && it != "911" }
                    if (clean.isNotEmpty()) {
                        phoneNumbers = clean
                    }
                }
                intent?.getStringExtra(EXTRA_MESSAGE)?.let { sosMessage = it }
                userId = intent?.getStringExtra("EXTRA_USER_ID") ?: userId
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }
                startOrUpdateForeground(-1)
                stopSosCountdown()
                executeSosPayload()
            }
            ACTION_STOP_LIVE_LOCATION -> {
                stopLiveLocationLoop()
            }
            ACTION_START_GEOFENCE -> {
                monitoringMode = "GEOFENCE"
                val lat = intent?.getDoubleExtra("lat", 0.0) ?: 0.0
                val lng = intent?.getDoubleExtra("lng", 0.0) ?: 0.0
                geofenceRadius = intent?.getFloatExtra("radius", 500f) ?: 500f
                geofenceCenter = Location("").apply {
                    latitude = lat
                    longitude = lng
                }
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { list ->
                    val clean = list.filter { it.isNotBlank() && it != "112" && it != "911" }
                    if (clean.isNotEmpty()) phoneNumbers = clean
                }
                intent?.getStringExtra("EXTRA_USER_ID")?.let { if (it.isNotBlank()) userId = it }

                // Persist geofence to SharedPreferences
                val prefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putBoolean("geofence_active", true)
                    .putFloat("geofence_lat", lat.toFloat())
                    .putFloat("geofence_lng", lng.toFloat())
                    .putFloat("geofence_radius", geofenceRadius)
                    .putString("user_id", userId)
                    .putString("phone_numbers", phoneNumbers.joinToString(","))
                    .apply()

                startOrUpdateForeground(-1)
                startPassiveLocationMonitoring()
            }
            ACTION_START_ROUTE -> {
                monitoringMode = "ROUTE"
                parsePolylineIntent(intent)
                startOrUpdateForeground(-1)
                startPassiveLocationMonitoring()
            }
            ACTION_UPDATE_ROUTE -> {
                if (monitoringMode == "ROUTE") {
                    parsePolylineIntent(intent)
                }
            }
            ACTION_STOP_MONITORING -> {
                val prefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("geofence_active", false).apply()
                stopPassiveMonitoring()
                startOrUpdateForeground(-1)
            }
            ACTION_STOP_FOREGROUND_SERVICE -> {
                stopForeground(true)
                stopSelf()
            }
            ACTION_PLAY_ALARM -> {
                playAlarmSound()
            }
            ACTION_STOP_ALARM -> {
                stopAlarmSound()
            }
        }
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopShakeListener()
        stopAlarmSound()
        // Do NOT resolve in Firestore on service destruction (only when user stops)
        if (!isLiveLocationActive) {
            stopLiveLocationLoop(resolveInFirestore = false)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SHEild Safety Service",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Background safety and emergency monitoring service"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun buildNotification(secondsLeft: Int, isDeviation: Boolean = false): Notification {
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            notificationIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (secondsLeft >= 0 || isLiveLocationActive) {
                notificationIntent.putExtra("SOS_ACTIVE", true)
            }
            PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        val title: String
        val content: String
        val priority: Int

        if (secondsLeft >= 0) {
            title = if (isDeviation) "⚠️ ROUTE DEVIATION DETECTED" else "⚠️ EMERGENCY SOS TRIGGERED"
            content = "Dispatching alert in $secondsLeft seconds... Tap to open & cancel."
            priority = NotificationCompat.PRIORITY_HIGH
        } else if (isLiveLocationActive) {
            title = "🚨 Emergency Alert Active"
            content = "Live location tracking active. Tap to open and mark safe."
            priority = NotificationCompat.PRIORITY_HIGH
        } else {
            title = "SHEild Active Protection"
            content = "SHEild is running and monitoring your safety"
            priority = NotificationCompat.PRIORITY_DEFAULT
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // Un-swipable ongoing notification
            .setAutoCancel(false)
            .setOnlyAlertOnce(secondsLeft < 0)
            .setPriority(priority)
            .setCategory(if (secondsLeft >= 0 || isLiveLocationActive) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentTitle(title)
            .setContentText(content)

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT or Notification.FLAG_NO_CLEAR
        return notification
    }

    private fun startOrUpdateForeground(secondsLeft: Int = if (isCountingDown) currentSecondsLeft else -1, isDeviation: Boolean = isRouteDeviation) {
        val notification = buildNotification(secondsLeft, isDeviation)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(secondsLeft: Int, isDeviation: Boolean = false) {
        startOrUpdateForeground(secondsLeft, isDeviation)
    }

    private fun persistCountdownState(seconds: Int, deviation: Boolean, source: String) {
        val prefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
        val deadlineMs = System.currentTimeMillis() + (seconds * 1000L)
        prefs.edit()
            .putBoolean("is_counting_down", true)
            .putLong("countdown_deadline_ms", deadlineMs)
            .putBoolean("is_route_deviation", deviation)
            .putString("trigger_source", source)
            .putString("user_id", userId)
            .putString("phone_numbers", phoneNumbers.joinToString(","))
            .putString("sos_message", sosMessage)
            .commit()
    }

    private fun clearPersistedCountdown() {
        val prefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("is_counting_down", false).commit()
    }

    private fun checkAndRestoreActiveCountdown(): Boolean {
        val prefs = getSharedPreferences("sheild_countdown_prefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean("is_counting_down", false)) {
            val deadlineMs = prefs.getLong("countdown_deadline_ms", 0L)
            val isDeviation = prefs.getBoolean("is_route_deviation", false)
            val source = prefs.getString("trigger_source", "SOS Button") ?: "SOS Button"
            prefs.getString("user_id", null)?.let { if (it.isNotBlank() && it != "unknown") userId = it }
            prefs.getString("phone_numbers", null)?.let { saved ->
                val list = saved.split(",").map { it.trim() }.filter { it.isNotBlank() && !getEmergencyServiceNumbers().contains(it) }
                if (list.isNotEmpty()) phoneNumbers = list
            }
            prefs.getString("sos_message", null)?.let { if (it.isNotBlank()) sosMessage = it }

            resolveUserId()
            resolvePhoneNumbers()

            currentTriggerSource = source
            isRouteDeviation = isDeviation

            val remainingMs = deadlineMs - System.currentTimeMillis()
            if (remainingMs > 500) {
                val remainingSeconds = ((remainingMs + 999) / 1000).toInt()
                if (isDeviation) {
                    startRouteDeviationCountdown(remainingSeconds)
                } else {
                    startSosCountdown(remainingSeconds)
                }
                return true
            } else {
                // Deadline passed while service was restarted or task swiped!
                clearPersistedCountdown()
                isCountingDown = false
                currentSecondsLeft = 0
                stopAlarmSound()

                // Emergency is NOW ACTIVE!
                isLiveLocationActive = true
                persistGuardState()
                updateServiceStateFile(this, liveActive = true, countingDown = false, seconds = -1, deviation = isDeviation, triggerSource = currentTriggerSource)
                startOrUpdateForeground(-1)

                executeSosPayload()
                return true
            }
        }
        return false
    }

    private fun startSosCountdown(seconds: Int = 10) {
        if (isCountingDown && currentSecondsLeft == seconds && countDownTimer != null) return
        countDownTimer?.cancel()
        isCountingDown = true
        currentSecondsLeft = seconds
        isRouteDeviation = false

        resolveUserId()
        resolvePhoneNumbers()
        persistGuardState()

        updateServiceStateFile(this, liveActive = false, countingDown = true, seconds = seconds, deviation = false, triggerSource = currentTriggerSource)
        persistCountdownState(seconds, false, currentTriggerSource)

        triggerVibration()
        playAlarmSound()
        updateNotification(seconds, false)

        countDownTimer = object : CountDownTimer(seconds * 1000L, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsLeft = (millisUntilFinished / 1000).toInt()
                currentSecondsLeft = secondsLeft
                updateServiceStateFile(applicationContext, liveActive = false, countingDown = true, seconds = secondsLeft, deviation = false, triggerSource = currentTriggerSource)
                updateNotification(secondsLeft, false)
                
                // Broadcast to Flutter
                val intent = Intent(ACTION_TIMER_TICK).apply {
                    setPackage(packageName)
                }
                intent.putExtra("secondsLeft", secondsLeft)
                intent.putExtra("isRouteDeviation", false)
                intent.putExtra("triggerSource", currentTriggerSource)
                sendBroadcast(intent)
            }

            override fun onFinish() {
                isCountingDown = false
                currentSecondsLeft = 0
                clearPersistedCountdown()
                stopAlarmSound()

                // Emergency is NOW ACTIVE!
                isLiveLocationActive = true
                persistGuardState()
                updateServiceStateFile(applicationContext, liveActive = true, countingDown = false, seconds = -1, deviation = false, triggerSource = currentTriggerSource)
                startOrUpdateForeground(-1)

                // Broadcast finish to Flutter
                val intent = Intent(ACTION_TIMER_TICK).apply {
                    setPackage(packageName)
                }
                intent.putExtra("secondsLeft", 0)
                intent.putExtra("isRouteDeviation", false)
                sendBroadcast(intent)
                
                executeSosPayload()
            }
        }.start()
    }

    private fun stopSosCountdown() {
        if (!isCountingDown) return
        isCountingDown = false
        currentSecondsLeft = -1
        clearPersistedCountdown()
        updateServiceStateFile(this, liveActive = false, countingDown = false, seconds = -1, deviation = false, triggerSource = currentTriggerSource)
        countDownTimer?.cancel()
        countDownTimer = null
        stopAlarmSound()
        updateNotification(-1)
        
        // Broadcast cancel to Flutter
        val intent = Intent(ACTION_TIMER_TICK).apply {
            setPackage(packageName)
        }
        intent.putExtra("secondsLeft", -1)
        intent.putExtra("isRouteDeviation", false)
        sendBroadcast(intent)
    }

    private fun startRouteDeviationCountdown(seconds: Int = 20) {
        if (isCountingDown && currentSecondsLeft == seconds && countDownTimer != null) return
        countDownTimer?.cancel()
        isCountingDown = true
        currentSecondsLeft = seconds
        isRouteDeviation = true
        currentTriggerSource = "Route Deviation"

        resolveUserId()
        resolvePhoneNumbers()
        persistGuardState()

        updateServiceStateFile(this, liveActive = false, countingDown = true, seconds = seconds, deviation = true, triggerSource = currentTriggerSource)
        persistCountdownState(seconds, true, currentTriggerSource)

        triggerVibration()
        playAlarmSound()
        updateNotification(seconds, true)

        countDownTimer = object : CountDownTimer(seconds * 1000L, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsLeft = (millisUntilFinished / 1000).toInt()
                currentSecondsLeft = secondsLeft
                updateServiceStateFile(applicationContext, liveActive = false, countingDown = true, seconds = secondsLeft, deviation = true, triggerSource = currentTriggerSource)
                updateNotification(secondsLeft, true)
                
                val intent = Intent(ACTION_TIMER_TICK).apply { setPackage(packageName) }
                intent.putExtra("secondsLeft", secondsLeft)
                intent.putExtra("isRouteDeviation", true)
                sendBroadcast(intent)
            }

            override fun onFinish() {
                isCountingDown = false
                currentSecondsLeft = 0
                clearPersistedCountdown()
                stopAlarmSound()

                // Emergency is NOW ACTIVE!
                isLiveLocationActive = true
                persistGuardState()
                updateServiceStateFile(applicationContext, liveActive = true, countingDown = false, seconds = -1, deviation = true, triggerSource = currentTriggerSource)
                startOrUpdateForeground(-1)
                
                val intent = Intent(ACTION_TIMER_TICK).apply { setPackage(packageName) }
                intent.putExtra("secondsLeft", 0)
                intent.putExtra("isRouteDeviation", true)
                sendBroadcast(intent)
                
                executeSosPayload()
            }
        }.start()
    }

    private fun executeSosPayload() {
        resolveUserId()
        resolvePhoneNumbers()
        isLiveLocationActive = true
        persistGuardState()
        updateServiceStateFile(this, liveActive = true, countingDown = false, seconds = -1)

        // 1. Send SMS to emergency contacts IMMEDIATELY (never wait for network or Firestore!)
        dispatchSmsAlerts()

        // 2. Start background live location tracking loop IMMEDIATELY
        startLiveLocationLoop()

        // 3. Update or create Firestore emergency document in background
        val db = getFirestore()
        val locationMap = fetchLocationData()

        if (emergencyId.isNotBlank()) {
            try {
                val updates = hashMapOf<String, Any>(
                    "lastLocationUpdate" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                    "isActive" to true,
                    "active" to true
                )
                if (locationMap != null) {
                    updates["lat"] = locationMap["latitude"]!!
                    updates["lng"] = locationMap["longitude"]!!
                    updates["latitude"] = locationMap["latitude"]!!
                    updates["longitude"] = locationMap["longitude"]!!
                    updates["accuracy"] = locationMap["accuracy"]!!
                }
                db.collection("emergencies").document(emergencyId).update(updates)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else if (userId.isNotBlank() && userId != "unknown") {
            try {
                db.collection("emergencies")
                    .whereEqualTo("userId", userId)
                    .whereEqualTo("isActive", true)
                    .limit(1)
                    .get()
                    .addOnSuccessListener { query ->
                        if (!query.isEmpty) {
                            emergencyId = query.documents[0].id
                            persistGuardState()
                        } else {
                            val newDoc = db.collection("emergencies").document()
                            emergencyId = newDoc.id
                            persistGuardState()
                            val data = hashMapOf<String, Any>(
                                "userId" to userId,
                                "userName" to "SOS Alert",
                                "bloodGroup" to "Unknown",
                                "mobileNumber" to (if (phoneNumbers.isNotEmpty()) phoneNumbers[0] else ""),
                                "liveLocationLink" to "https://streetpartner.web.app/?session=$emergencyId",
                                "triggerSource" to currentTriggerSource,
                                "timestamp" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                                "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                                "triggeredAt" to com.google.firebase.Timestamp.now(),
                                "isActive" to true,
                                "active" to true
                            )
                            if (locationMap != null) {
                                data["lat"] = locationMap["latitude"]!!
                                data["lng"] = locationMap["longitude"]!!
                                data["latitude"] = locationMap["latitude"]!!
                                data["longitude"] = locationMap["longitude"]!!
                                data["accuracy"] = locationMap["accuracy"]!!
                            }
                            newDoc.set(data)
                        }
                    }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun dispatchSmsAlerts() {
        val validContacts = resolvePhoneNumbers()

        if (validContacts.isNotEmpty()) {
            sendSmsBatch(validContacts)
        } else {
            // As a final fallback if contacts weren't cached locally yet, fetch from Firestore
            val uid = resolveUserId()
            if (uid.isNotBlank() && uid != "unknown") {
                try {
                    getFirestore().collection("users").document(uid).get()
                        .addOnSuccessListener { doc ->
                            if (doc.exists()) {
                                @Suppress("UNCHECKED_CAST")
                                val list = doc.get("emergencyContacts") as? List<String>
                                val blocked = getEmergencyServiceNumbers()
                                val contacts = list?.map { it.trim() }?.filter { it.isNotBlank() && !blocked.contains(it) } ?: emptyList()
                                if (contacts.isNotEmpty()) {
                                    phoneNumbers = contacts
                                    persistGuardState()
                                    sendSmsBatch(contacts)
                                }
                            }
                        }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun sendSmsBatch(contacts: List<String>) {
        val sessionParam = if (emergencyId.isNotBlank()) emergencyId else userId
        val fullMessage = if (sosMessage.contains("?session=")) {
            sosMessage.replace(Regex("\\?session=[^\\s]+"), "?session=$sessionParam")
        } else {
            "$sosMessage Live Location: https://streetpartner.web.app/?session=$sessionParam"
        }

        for (number in contacts) {
            sendSmsToContact(number, fullMessage)
        }
    }

    private fun startLiveLocationLoop() {
        if (isLiveLocationActive && liveLocationRunnable != null) return
        isLiveLocationActive = true
        persistGuardState()
        liveLocationStartTime = System.currentTimeMillis()
        updateServiceStateFile(this, liveActive = true, countingDown = false, seconds = -1)
        
        startPassiveLocationMonitoring()
        
        liveLocationRunnable = object : Runnable {
            override fun run() {
                if (!isLiveLocationActive) {
                    stopLiveLocationLoop()
                    return
                }
                
                val locationMap = fetchLocationData()
                val db = getFirestore()
                
                if (emergencyId.isNotBlank()) {
                    try {
                        val updates = hashMapOf<String, Any>(
                            "lastLocationUpdate" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                            "isActive" to true,
                            "active" to true
                        )
                        if (locationMap != null) {
                            updates["lat"] = locationMap["latitude"]!!
                            updates["lng"] = locationMap["longitude"]!!
                            updates["latitude"] = locationMap["latitude"]!!
                            updates["longitude"] = locationMap["longitude"]!!
                            updates["accuracy"] = locationMap["accuracy"]!!
                        }
                        db.collection("emergencies").document(emergencyId).update(updates)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                } else if (userId != "unknown") {
                    try {
                        db.collection("emergencies")
                            .whereEqualTo("userId", userId)
                            .whereEqualTo("isActive", true)
                            .limit(1)
                            .get()
                            .addOnSuccessListener { q ->
                                if (!q.isEmpty) {
                                    emergencyId = q.documents[0].id
                                    persistGuardState()
                                    val updates = hashMapOf<String, Any>(
                                        "lastLocationUpdate" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                                        "isActive" to true,
                                        "active" to true
                                    )
                                    if (locationMap != null) {
                                        updates["lat"] = locationMap["latitude"]!!
                                        updates["lng"] = locationMap["longitude"]!!
                                        updates["latitude"] = locationMap["latitude"]!!
                                        updates["longitude"] = locationMap["longitude"]!!
                                        updates["accuracy"] = locationMap["accuracy"]!!
                                    }
                                    q.documents[0].reference.update(updates)
                                }
                            }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                
                liveLocationHandler.postDelayed(this, LIVE_LOCATION_INTERVAL_MS)
            }
        }
        liveLocationHandler.post(liveLocationRunnable!!)
        updateNotification(-1)
    }

    private fun stopLiveLocationLoop(resolveInFirestore: Boolean = true) {
        isLiveLocationActive = false
        persistGuardState()
        liveLocationRunnable?.let { liveLocationHandler.removeCallbacks(it) }
        liveLocationRunnable = null
        updateServiceStateFile(this, liveActive = false, countingDown = false, seconds = -1)
        
        if (resolveInFirestore) {
            val db = getFirestore()
            val updates = mapOf<String, Any>(
                "isActive" to false,
                "active" to false,
                "resolvedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
            )

            if (emergencyId.isNotBlank()) {
                try {
                    db.collection("emergencies").document(emergencyId).update(updates)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            if (userId != "unknown") {
                try {
                    db.collection("emergencies")
                        .whereEqualTo("userId", userId)
                        .whereEqualTo("isActive", true)
                        .get()
                        .addOnSuccessListener { query ->
                            for (doc in query.documents) {
                                doc.reference.update(updates)
                            }
                        }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            emergencyId = ""
        }
        
        startOrUpdateForeground(-1)
    }

    // --- Sensor & Media logic (copied from MainActivity) ---
    private fun initSensorManager() {
        try {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            startShakeListener()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startShakeListener() {
        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun stopShakeListener() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val gX = x / SensorManager.GRAVITY_EARTH
        val gY = y / SensorManager.GRAVITY_EARTH
        val gZ = z / SensorManager.GRAVITY_EARTH

        val gForce = sqrt(gX * gX + gY * gY + gZ * gZ)

        if (gForce > SHAKE_THRESHOLD) {
            val now = System.currentTimeMillis()
            if (lastShakeTime + SHAKE_SLOP_TIME_MS > now) return
            if (lastShakeTime + SHAKE_COUNT_RESET_TIME_MS < now) shakeCount = 0
            
            lastShakeTime = now
            shakeCount++

            if (shakeCount >= 3) {
                shakeCount = 0
                currentTriggerSource = "Shake to Trigger"
                startSosCountdown()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun playAlarmSound() {
        try {
            stopAlarmSound()

            // 1. Acquire WakeLock so CPU doesn't sleep while siren plays
            try {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                alarmWakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "sheild:AlarmWakeLock")?.apply {
                    setReferenceCounted(false)
                    acquire(10 * 60 * 1000L) // 10 minutes max safe timeout
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 2. Maximize alarm volume and request transient audio focus
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                audioManager?.let { am ->
                    val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val playbackAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                            .setAudioAttributes(playbackAttributes)
                            .setAcceptsDelayedFocusGain(true)
                            .build()
                        audioFocusRequest = req
                        am.requestAudioFocus(req)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 3. Play R.raw.siren with proper AssetFileDescriptor and AudioAttributes
            try {
                resources.openRawResourceFd(R.raw.siren)?.use { afd ->
                    mediaPlayer = MediaPlayer().apply {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .build()
                        )
                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                        isLooping = true
                        setVolume(1.0f, 1.0f)
                        prepare()
                        start()
                    }
                    return
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 4. Fallback: Identifier lookup
            val resId = resources.getIdentifier("siren", "raw", packageName)
            if (resId != 0) {
                try {
                    resources.openRawResourceFd(resId)?.use { afd ->
                        mediaPlayer = MediaPlayer().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .build()
                            )
                            setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                            isLooping = true
                            setVolume(1.0f, 1.0f)
                            prepare()
                            start()
                        }
                        return
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            // 5. Fallback: System Alarm Ringtone
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarmSound() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            if (ringtone?.isPlaying == true) {
                ringtone?.stop()
            }
            ringtone = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            if (alarmWakeLock?.isHeld == true) {
                alarmWakeLock?.release()
            }
            alarmWakeLock = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun triggerVibration() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                @Suppress("DEPRECATION")
                vibrator.vibrate(1000)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun fetchLocationData(): HashMap<String, Any>? {
        try {
            var location = latestLocation

            if (location == null) {
                val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

                if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    if (isGpsEnabled) {
                        location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    }
                    if (location == null && isNetworkEnabled) {
                        location = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    }
                }
            }

            if (location != null) {
                return hashMapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                    "provider" to (location.provider ?: "unknown")
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun sendSmsToContact(phoneNumber: String, message: String) {
        val cleanNumber = phoneNumber.trim()
        if (cleanNumber.isBlank() || getEmergencyServiceNumbers().contains(cleanNumber)) return

        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                var sent = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val smsManager = getSystemService(SmsManager::class.java)
                        if (smsManager != null) {
                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(cleanNumber, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(cleanNumber, null, message, null, null)
                            }
                            sent = true
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                if (!sent) {
                    @Suppress("DEPRECATION")
                    val legacyManager = SmsManager.getDefault()
                    val parts = legacyManager.divideMessage(message)
                    if (parts.size > 1) {
                        legacyManager.sendMultipartTextMessage(cleanNumber, null, parts, null, null)
                    } else {
                        legacyManager.sendTextMessage(cleanNumber, null, message, null, null)
                    }
                }
            } else {
                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = Uri.parse("sms:$cleanNumber")
                        putExtra("sms_body", message)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun initiateDirectPhoneCall(phoneNumber: String) {
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                // Background activity starts are blocked on Android 10+. TelecomManager bypasses this restriction.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                    telecomManager.placeCall(Uri.parse("tel:$phoneNumber"), null)
                } else {
                    val callIntent = Intent(Intent.ACTION_CALL).apply {
                        data = Uri.parse("tel:$phoneNumber")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(callIntent)
                }
            } else {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
            }
        } catch (e: Exception) {
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }

    private fun checkSafetyRules(currentLocation: Location) {
        if (isCountingDown) return
        
        when (monitoringMode) {
            "GEOFENCE" -> {
                val center = geofenceCenter ?: return
                if (center.latitude == 0.0 && center.longitude == 0.0) return
                if (currentLocation.distanceTo(center) > geofenceRadius) {
                    currentTriggerSource = "Geo-fencing"
                    startSosCountdown()
                }
            }
            "ROUTE" -> {
                if (routePolyline.isEmpty()) return
                val dist = distanceToRoute(currentLocation, routePolyline)
                if (dist > 100) {
                    currentTriggerSource = "Route Deviation"
                    startRouteDeviationCountdown()
                }
            }
        }
    }

    private fun distanceToRoute(loc: Location, polyline: List<Location>): Float {
        var minDistance = Float.MAX_VALUE
        for (i in 0 until polyline.size - 1) {
            val dist = crossTrackDistance(loc, polyline[i], polyline[i+1])
            if (dist < minDistance) minDistance = dist
        }
        return minDistance
    }
    
    private fun crossTrackDistance(p: Location, a: Location, b: Location): Float {
        val latMid = Math.toRadians((a.latitude + b.latitude) / 2.0)
        val rEarth = 6371000f
        
        val pX = (Math.toRadians(p.longitude - a.longitude) * Math.cos(latMid) * rEarth).toFloat()
        val pY = (Math.toRadians(p.latitude - a.latitude) * rEarth).toFloat()
        val bX = (Math.toRadians(b.longitude - a.longitude) * Math.cos(latMid) * rEarth).toFloat()
        val bY = (Math.toRadians(b.latitude - a.latitude) * rEarth).toFloat()
        
        val lineLen2 = bX*bX + bY*bY
        if (lineLen2 == 0f) return p.distanceTo(a)
        
        val t = Math.max(0f, Math.min(1f, (pX * bX + pY * bY) / lineLen2))
        val projX = t * bX
        val projY = t * bY
        val dx = pX - projX
        val dy = pY - projY
        return sqrt(dx*dx + dy*dy)
    }

    private fun startPassiveLocationMonitoring() {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 5000L, 2f, locationListener, Looper.getMainLooper())
                locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 5000L, 2f, locationListener, Looper.getMainLooper())
            }
        } catch (e: Exception) {}
    }

    private fun stopPassiveMonitoring() {
        monitoringMode = "NONE"
        geofenceCenter = null
        routePolyline = emptyList()
        if (!isLiveLocationActive) {
            try {
                val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                locationManager.removeUpdates(locationListener)
            } catch (e: Exception) {}
        }
    }

    private fun parsePolylineIntent(intent: Intent?) {
        val lats = intent?.getDoubleArrayExtra("polyLats")
        val lngs = intent?.getDoubleArrayExtra("polyLngs")
        if (lats != null && lngs != null && lats.size == lngs.size) {
            val list = mutableListOf<Location>()
            for (i in lats.indices) {
                list.add(Location("").apply {
                    latitude = lats[i]
                    longitude = lngs[i]
                })
            }
            routePolyline = list
        }
    }

    private fun restorePersistedMonitoring() {
        resolveUserId()
        resolvePhoneNumbers()

        val prefs = getSharedPreferences("sheild_guard_prefs", Context.MODE_PRIVATE)
        prefs.getString("user_id", null)?.let { if (it.isNotBlank() && it != "unknown") userId = it }
        prefs.getString("phone_numbers", null)?.let { saved ->
            val list = saved.split(",").map { it.trim() }.filter { it.isNotBlank() && !getEmergencyServiceNumbers().contains(it) }
            if (list.isNotEmpty()) phoneNumbers = list
        }
        prefs.getString("sos_message", null)?.let { if (it.isNotBlank()) sosMessage = it }

        if (prefs.getBoolean("is_live_location", false)) {
            val savedEmergId = prefs.getString("emergency_id", "") ?: ""
            if (savedEmergId.isNotBlank()) emergencyId = savedEmergId
            startLiveLocationLoop()
        }

        if (prefs.getBoolean("geofence_active", false)) {
            monitoringMode = "GEOFENCE"
            val lat = prefs.getFloat("geofence_lat", 0f).toDouble()
            val lng = prefs.getFloat("geofence_lng", 0f).toDouble()
            geofenceRadius = prefs.getFloat("geofence_radius", 500f)
            geofenceCenter = Location("").apply {
                latitude = lat
                longitude = lng
            }
            startPassiveLocationMonitoring()
        }
    }
}
