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
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.sqrt

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
                
                startForeground(NOTIFICATION_ID, buildNotification(-1))
            }
            ACTION_TRIGGER_SOS -> {
                startForeground(NOTIFICATION_ID, buildNotification(-1))
                startSosCountdown()
            }
            ACTION_STOP_SOS -> {
                startForeground(NOTIFICATION_ID, buildNotification(-1))
                stopSosCountdown()
            }
            ACTION_EXECUTE_SOS_NOW -> {
                startForeground(NOTIFICATION_ID, buildNotification(-1))
                stopSosCountdown()
                executeSosPayload()
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
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SOS Foreground Service Channel",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Ongoing SOS service for quick emergency trigger"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun buildNotification(secondsLeft: Int): Notification {
        // Intent to open MainActivity
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            notificationIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (secondsLeft >= 0) {
                notificationIntent.putExtra("SOS_ACTIVE", true)
            }
            PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert) // Replace with your own app icon later
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (secondsLeft >= 0) {
            builder.setContentTitle("SOS Alert Triggered!")
            builder.setContentText("SOS Dispatched in ${secondsLeft}s...")
            builder.color = ContextCompat.getColor(this, android.R.color.holo_red_dark)
        } else {
            builder.setContentTitle("StreetPartner SOS Service Active")
            builder.setContentText("Shake 3 times or tap TRIGGER to dispatch SOS")
            
            // Add Trigger button if not counting down
            val triggerIntent = Intent(this, SosForegroundService::class.java).apply {
                action = ACTION_TRIGGER_SOS
            }
            val triggerPendingIntent = PendingIntent.getService(this, 1, triggerIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            builder.addAction(android.R.drawable.ic_menu_send, "TRIGGER SOS", triggerPendingIntent)
        }

        return builder.build()
    }

    private fun updateNotification(secondsLeft: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildNotification(secondsLeft))
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
        sendBroadcast(intent)
    }

    private fun executeSosPayload() {
        val locationMap = fetchLocationData()

        val fullMessage = if (locationMap != null) {
            "$sosMessage Location: https://maps.google.com/?q=${locationMap["latitude"]},${locationMap["longitude"]}"
        } else {
            "$sosMessage Location: GPS coordinates unavailable"
        }

        // SMS
        for (number in phoneNumbers) {
            if (number.isNotBlank()) {
                sendSmsToContact(number, fullMessage)
            }
        }

        // Call
        if (callEmergency && phoneNumbers.isNotEmpty()) {
            initiateDirectPhoneCall(phoneNumbers.first())
        }
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
                startSosCountdown()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun playAlarmSound() {
        try {
            stopAlarmSound()
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.play()
        } catch (e: Exception) {
            try {
                toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                toneGenerator?.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, 10000)
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }

    private fun stopAlarmSound() {
        try {
            ringtone?.stop()
            ringtone = null
            toneGenerator?.stopTone()
            toneGenerator?.release()
            toneGenerator = null
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
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

            var location: Location? = null
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {

                if (isGpsEnabled) {
                    location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                }
                if (location == null && isNetworkEnabled) {
                    location = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
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
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
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
                val callIntent = Intent(Intent.ACTION_CALL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(callIntent)
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
}
