package com.example.streetpartner

import android.Manifest
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
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {

    private final val CHANNEL = "com.example.streetpartner/sos_channel"
    private final val PERMISSION_REQUEST_CODE = 1001

    private var methodChannel: MethodChannel? = null
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null

    private var ringtone: Ringtone? = null
    private var toneGenerator: ToneGenerator? = null

    // Shake detection tracking parameters
    private var shakeCount = 0
    private var lastShakeTime: Long = 0
    private val SHAKE_THRESHOLD = 2.5f // acceleration threshold in G-force
    private val SHAKE_SLOP_TIME_MS = 500 // minimum time between shakes
    private val SHAKE_COUNT_RESET_TIME_MS = 2500 // reset shake count after 2.5s

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarmSound" -> {
                    playAlarmSound()
                    result.success(true)
                }

                "stopAlarmSound" -> {
                    stopAlarmSound()
                    result.success(true)
                }

                "startShakeDetection" -> {
                    startShakeListener()
                    result.success(true)
                }

                "stopShakeDetection" -> {
                    stopShakeListener()
                    result.success(true)
                }

                "triggerSosAlert" -> {
                    stopAlarmSound()
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: listOf("112")
                    val message = call.argument<String>("message") ?: "EMERGENCY SOS: I need immediate help!"
                    val callEmergency = call.argument<Boolean>("callEmergency") ?: true

                    // 1. Haptic / Vibration Feedback
                    triggerVibration()

                    // 2. Fetch Current GPS Location
                    val locationMap = fetchLocationData()

                    val fullMessage = if (locationMap != null) {
                        "$message Location: https://maps.google.com/?q=${locationMap["latitude"]},${locationMap["longitude"]}"
                    } else {
                        "$message Location: GPS coordinates unavailable"
                    }

                    // 3. Dispatch SMS to ALL Emergency Contacts
                    var smsStatus = "SMS dispatched"
                    var smsSuccessCount = 0
                    try {
                        for (number in phoneNumbers) {
                            if (number.isNotBlank()) {
                                sendSmsToContact(number, fullMessage)
                                smsSuccessCount++
                            }
                        }
                        smsStatus = "SMS dispatched to $smsSuccessCount contacts"
                    } catch (e: Exception) {
                        smsStatus = "SMS error: ${e.localizedMessage}"
                    }

                    // 4. Directly Connect Emergency Phone Call
                    var callStatus = "Call not attempted"
                    if (callEmergency && phoneNumbers.isNotEmpty()) {
                        callStatus = initiateDirectPhoneCall(phoneNumbers.first())
                    }

                    val response = hashMapOf<String, Any>(
                        "success" to true,
                        "smsStatus" to smsStatus,
                        "callStatus" to callStatus,
                        "latitude" to (locationMap?.get("latitude") ?: 0.0),
                        "longitude" to (locationMap?.get("longitude") ?: 0.0),
                        "timestamp" to System.currentTimeMillis()
                    )
                    result.success(response)
                }

                "getDeviceLocation" -> {
                    val locationMap = fetchLocationData()
                    if (locationMap != null) {
                        result.success(locationMap)
                    } else {
                        result.error("UNAVAILABLE", "Location not available", null)
                    }
                }

                "checkPermissions" -> {
                    val hasSms = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasCall = ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
                    val hasLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

                    val permissionMap = hashMapOf<String, Boolean>(
                        "sms" to hasSms,
                        "call" to hasCall,
                        "location" to hasLocation,
                        "allGranted" to (hasSms && hasCall && hasLocation)
                    )
                    result.success(permissionMap)
                }

                "requestPermissions" -> {
                    val permissions = arrayOf(
                        Manifest.permission.SEND_SMS,
                        Manifest.permission.CALL_PHONE,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // Auto-start accelerometer shake listener
        initSensorManager()
    }

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

            if (lastShakeTime + SHAKE_SLOP_TIME_MS > now) {
                return
            }

            if (lastShakeTime + SHAKE_COUNT_RESET_TIME_MS < now) {
                shakeCount = 0
            }

            lastShakeTime = now
            shakeCount++

            // Trigger when 3 shakes occur within 2.5s
            if (shakeCount >= 3) {
                shakeCount = 0
                triggerVibration()
                playAlarmSound() // Play loud emergency alarm siren sound immediately!

                // Notify Flutter to trigger 10s countdown dialog / STOP SOS option
                runOnUiThread {
                    methodChannel?.invokeMethod("onShakeDetected", null)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onResume() {
        super.onResume()
        startShakeListener()
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
        stopShakeListener()
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

    private fun initiateDirectPhoneCall(phoneNumber: String): String {
        return try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                val callIntent = Intent(Intent.ACTION_CALL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(callIntent)
                "Direct Call Connected"
            } else {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
                "Dialer Connected"
            }
        } catch (e: Exception) {
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
                "Fallback Dialer Connected"
            } catch (ex: Exception) {
                "Call Failed: ${ex.localizedMessage}"
            }
        }
    }
}
