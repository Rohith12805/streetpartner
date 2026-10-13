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
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationManager
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
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
        const val CHANNEL_ID = "SosServiceChannel_v2"
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
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var ringtone: Ringtone? = null
    private var toneGenerator: ToneGenerator? = null

    // Shake detection tracking parameters
    private var shakeCount = 0
    private var lastShakeTime: Long = 0
    private val SHAKE_THRESHOLD = 2.5f
    private val SHAKE_SLOP_TIME_MS = 500
    private val SHAKE_COUNT_RESET_TIME_MS = 2500

    private var countDownTimer: CountDownTimer? = null
    private var isCountingDown = false
    private var phoneNumbers: List<String> = listOf("112")
    private var sosMessage: String = "EMERGENCY SOS: I need immediate help!"
    private var callEmergency: Boolean = true
    private var userId: String = "unknown"
    private var emergencyId: String = ""
    private var currentTriggerSource: String = "SOS Button"

    private var monitoringMode: String = "NONE"
    private var geofenceCenter: Location? = null
    private var geofenceRadius: Float = 0f
    private var routePolyline: List<Location> = emptyList()

    private var isLiveLocationActive = false
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

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initSensorManager()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        var action = intent?.action
        
        if (action == null) {
            // Service restarted by OS
            startForeground(NOTIFICATION_ID, buildNotification(-1))
            return START_STICKY
        }

        when (action) {
            ACTION_START_FOREGROUND_SERVICE -> {
                phoneNumbers = intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS) ?: phoneNumbers
                sosMessage = intent?.getStringExtra(EXTRA_MESSAGE) ?: sosMessage
                callEmergency = intent?.getBooleanExtra(EXTRA_CALL_EMERGENCY, true) ?: callEmergency
                userId = intent?.getStringExtra("EXTRA_USER_ID") ?: userId
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }
                startForeground(NOTIFICATION_ID, buildNotification(-1))
            }
            ACTION_TRIGGER_SOS -> {
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { if (it.isNotEmpty()) phoneNumbers = it }
                intent?.getStringExtra(EXTRA_MESSAGE)?.let { sosMessage = it }
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }
                currentTriggerSource = intent?.getStringExtra("EXTRA_TRIGGER_SOURCE") ?: "SOS Button"
                startForeground(NOTIFICATION_ID, buildNotification(-1))
                startSosCountdown()
            }
            ACTION_STOP_SOS -> {
                startForeground(NOTIFICATION_ID, buildNotification(-1))
                stopSosCountdown()
            }
            ACTION_EXECUTE_SOS_NOW -> {
                intent?.getStringArrayListExtra(EXTRA_PHONE_NUMBERS)?.let { if (it.isNotEmpty()) phoneNumbers = it }
                intent?.getStringExtra(EXTRA_MESSAGE)?.let { sosMessage = it }
                userId = intent?.getStringExtra("EXTRA_USER_ID") ?: userId
                intent?.getStringExtra("EXTRA_EMERGENCY_ID")?.let { if (it.isNotBlank()) emergencyId = it }
                startForeground(NOTIFICATION_ID, buildNotification(-1))
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
                startPassiveLocationMonitoring()
            }
            ACTION_START_ROUTE -> {
                monitoringMode = "ROUTE"
                parsePolylineIntent(intent)
                startPassiveLocationMonitoring()
            }
            ACTION_UPDATE_ROUTE -> {
                if (monitoringMode == "ROUTE") {
                    parsePolylineIntent(intent)
                }
            }
            ACTION_STOP_MONITORING -> {
                stopPassiveMonitoring()
            }
            ACTION_STOP_FOREGROUND_SERVICE -> {
                stopForeground(true)
                stopSelf()
            }
        }
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSosCountdown()
        stopShakeListener()
        stopLiveLocationLoop()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SOS Background Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Silent background safety service"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun buildNotification(secondsLeft: Int, isDeviation: Boolean = false): Notification {
        // Intent to open MainActivity
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            notificationIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (secondsLeft >= 0) {
                notificationIntent.putExtra("SOS_ACTIVE", true)
            }
            PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setContentTitle("")
            .setContentText("")

        if (secondsLeft >= 0) {
            // Wake the screen from sleep/background to present the in-app countdown dialog
            builder.setFullScreenIntent(pendingIntent, true)
        }

        return builder.build()
    }

    private fun updateNotification(secondsLeft: Int, isDeviation: Boolean = false) {
        startForeground(NOTIFICATION_ID, buildNotification(secondsLeft, isDeviation))
    }

    private fun startSosCountdown() {
        if (isCountingDown) return
        isCountingDown = true

        triggerVibration()
        playAlarmSound()
        
        // Wake up screen and launch MainActivity
        val wakeIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("SOS_ACTIVE", true)
        }
        try {
            startActivity(wakeIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        countDownTimer = object : CountDownTimer(10000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsLeft = (millisUntilFinished / 1000).toInt()
                updateNotification(secondsLeft)
                
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
                stopAlarmSound()
                updateNotification(-1)
                
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

    private fun startRouteDeviationCountdown() {
        if (isCountingDown) return
        isCountingDown = true

        triggerVibration()
        playAlarmSound()
        
        val wakeIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("SOS_ACTIVE", true)
        }
        try { startActivity(wakeIntent) } catch (e: Exception) {}

        countDownTimer = object : CountDownTimer(20000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsLeft = (millisUntilFinished / 1000).toInt()
                updateNotification(secondsLeft, true)
                
                val intent = Intent(ACTION_TIMER_TICK).apply { setPackage(packageName) }
                intent.putExtra("secondsLeft", secondsLeft)
                intent.putExtra("isRouteDeviation", true)
                sendBroadcast(intent)
            }

            override fun onFinish() {
                isCountingDown = false
                stopAlarmSound()
                updateNotification(-1)
                
                val intent = Intent(ACTION_TIMER_TICK).apply { setPackage(packageName) }
                intent.putExtra("secondsLeft", 0)
                intent.putExtra("isRouteDeviation", true)
                sendBroadcast(intent)
                
                executeSosPayload()
            }
        }.start()
    }

    private fun executeSosPayload() {
        val db = FirebaseFirestore.getInstance()
        val locationMap = fetchLocationData()

        if (emergencyId.isNotBlank()) {
            startLiveLocationLoop()
            dispatchSmsAlerts()
        } else if (userId != "unknown") {
            try {
                db.collection("emergencies")
                    .whereEqualTo("userId", userId)
                    .whereEqualTo("isActive", true)
                    .limit(1)
                    .get()
                    .addOnSuccessListener { query ->
                        if (!query.isEmpty) {
                            emergencyId = query.documents[0].id
                        } else {
                            val newDoc = db.collection("emergencies").document()
                            emergencyId = newDoc.id
                            val data = hashMapOf<String, Any>(
                                "userId" to userId,
                                "userName" to "SOS Alert",
                                "bloodGroup" to "Unknown",
                                "mobileNumber" to (if (phoneNumbers.isNotEmpty()) phoneNumbers[0] else ""),
                                "liveLocationLink" to "https://streetpartner.web.app/?session=$emergencyId",
                                "timestamp" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                                "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                                "triggeredAt" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
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
                        startLiveLocationLoop()
                        dispatchSmsAlerts()
                    }
                    .addOnFailureListener {
                        startLiveLocationLoop()
                        dispatchSmsAlerts()
                    }
            } catch (e: Exception) {
                e.printStackTrace()
                startLiveLocationLoop()
                dispatchSmsAlerts()
            }
        } else {
            startLiveLocationLoop()
            dispatchSmsAlerts()
        }
    }

    private fun dispatchSmsAlerts() {
        val sessionParam = if (emergencyId.isNotBlank()) emergencyId else userId
        val fullMessage = if (sosMessage.contains("?session=")) {
            sosMessage.replace(Regex("\\?session=[^\\s]+"), "?session=$sessionParam")
        } else {
            "$sosMessage Live Location: https://streetpartner.web.app/?session=$sessionParam"
        }

        for (number in phoneNumbers) {
            if (number.isNotBlank()) {
                sendSmsToContact(number, fullMessage)
            }
        }
    }

    private fun startLiveLocationLoop() {
        if (isLiveLocationActive) return
        isLiveLocationActive = true
        liveLocationStartTime = System.currentTimeMillis()
        
        startPassiveLocationMonitoring()
        
        liveLocationRunnable = object : Runnable {
            override fun run() {
                if (!isLiveLocationActive) {
                    stopLiveLocationLoop()
                    return
                }
                
                val locationMap = fetchLocationData()
                val db = FirebaseFirestore.getInstance()
                
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
    }

    private fun stopLiveLocationLoop() {
        isLiveLocationActive = false
        liveLocationRunnable?.let { liveLocationHandler.removeCallbacks(it) }
        liveLocationRunnable = null
        stopPassiveMonitoring()
        
        val db = FirebaseFirestore.getInstance()
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
                    .addOnSuccessListener { q ->
                        for (doc in q.documents) {
                            doc.reference.update(updates)
                        }
                    }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        emergencyId = ""
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
        // Disabled native alarm sound. Audio is now handled by the Flutter audioplayers package.
    }

    private fun stopAlarmSound() {
        // Disabled native alarm sound. Audio is now handled by the Flutter audioplayers package.
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
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            @Suppress("DEPRECATION")
            val smsManager: SmsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
        } else {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("sms:$phoneNumber")
                putExtra("sms_body", message)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
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
}
