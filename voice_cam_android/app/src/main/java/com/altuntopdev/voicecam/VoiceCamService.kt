package com.altuntopdev.voicecam

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.view.OrientationEventListener
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Does the actual work, as a foreground service, so listening and recording
 * survive the screen going off and the app being swiped away.
 *
 * The camera and the microphone are "while-in-use" permissions: a service that
 * is started while the app is on screen keeps them afterwards, which is why the
 * activity starts this and then gets out of the way. There is no preview — the
 * point is that the phone can be in a pocket.
 *
 * Battery: the camera is only opened for the length of a recording, and in
 * power-saving mode the listener runs in duty cycles once the screen is off.
 */
class VoiceCamService : LifecycleService() {

    /** What the activity shows while it happens to be open. */
    interface Listener {
        fun onStateChanged(listening: Boolean, recording: Boolean)
        fun onHeard(text: String)
        fun onError(message: String)
    }

    private lateinit var voice: VoiceCommander
    private lateinit var orientationListener: OrientationEventListener

    private val main = Handler(Looper.getMainLooper())

    private var cameraProvider: ProcessCameraProvider? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null
    private var stopping = false
    private var openingCamera = false

    /** Recording with sound; the listener has to stand down while it runs. */
    private var withAudio = false
    private var powerSaving = true
    private var screenOn = true

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            screenOn = intent?.action != Intent.ACTION_SCREEN_OFF
            applyListenPolicy()
        }
    }

    /** Flips the listener on and off while the screen is off, to save power. */
    private val dutyCycle = object : Runnable {
        override fun run() {
            if (voice.isActive) {
                voice.stop()
                main.postDelayed(this, SAVER_PAUSE_MS)
            } else {
                voice.start()
                main.postDelayed(this, SAVER_LISTEN_MS)
            }
            refreshNotification()
        }
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        voice = VoiceCommander(
            context = this,
            onCommand = ::onVoiceCommand,
            onStatus = ::onVoiceStatus,
        )
        screenOn = getSystemService(PowerManager::class.java).isInteractive
        ContextCompat.registerReceiver(
            this,
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        orientationListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                videoCapture?.targetRotation = when (orientation) {
                    in 45..134 -> Surface.ROTATION_270
                    in 135..224 -> Surface.ROTATION_180
                    in 225..314 -> Surface.ROTATION_90
                    else -> Surface.ROTATION_0
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)

        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_TOGGLE_RECORDING -> {
                if (recording == null) startRecording() else stopRecording()
                return START_STICKY
            }
        }

        withAudio = intent?.getBooleanExtra(EXTRA_WITH_AUDIO, withAudio) ?: withAudio
        powerSaving = intent?.getBooleanExtra(EXTRA_POWER_SAVING, powerSaving) ?: powerSaving
        try {
            startInForeground()
        } catch (e: Exception) {
            // A system-initiated restart can land while the app is in the
            // background, where starting a camera/mic service is not allowed.
            stopSelf()
            return START_NOT_STICKY
        }
        applyListenPolicy()
        publishState()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        main.removeCallbacks(dutyCycle)
        orientationListener.disable()
        runCatching { unregisterReceiver(screenReceiver) }
        voice.destroy()
        recording?.stop()
        recording = null
        releaseCamera()
        publishState()
        super.onDestroy()
    }

    // --- Listening policy -----------------------------------------------------

    /**
     * Continuous while the screen is on, while recording, or with power saving
     * off; otherwise a listen/pause cycle that costs roughly a third less.
     */
    private fun applyListenPolicy() {
        main.removeCallbacks(dutyCycle)
        if (withAudio && recording != null) return // the recorder owns the mic

        if (!powerSaving || screenOn || recording != null) {
            voice.start()
        } else {
            voice.start()
            main.postDelayed(dutyCycle, SAVER_LISTEN_MS)
        }
        refreshNotification()
    }

    // --- Foreground notification ---------------------------------------------

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.channel_name),
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                0
            },
        )
    }

    private fun buildNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_notification)
        .setContentTitle(
            getString(
                when {
                    recording != null -> R.string.notif_recording
                    voice.isActive -> R.string.notif_listening
                    else -> R.string.notif_paused
                },
            ),
        )
        .setContentText(getString(R.string.notif_hint))
        .setOngoing(true)
        .setSilent(true)
        .setContentIntent(
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        .addAction(
            0,
            getString(
                if (recording != null) R.string.stop_recording else R.string.start_recording,
            ),
            servicePendingIntent(ACTION_TOGGLE_RECORDING, 1),
        )
        .addAction(0, getString(R.string.quit), servicePendingIntent(ACTION_STOP, 2))
        .build()

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, VoiceCamService::class.java).setAction(action),
            PendingIntent.FLAG_IMMUTABLE,
        )

    private fun refreshNotification() {
        if (!running) return
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    // --- Camera ---------------------------------------------------------------

    /**
     * Opens the camera on demand. Keeping it bound between recordings is what
     * drains a battery fastest, so it is released again as soon as a recording
     * finishes — at the cost of about a second before recording starts.
     */
    private fun withCamera(action: (VideoCapture<Recorder>) -> Unit) {
        videoCapture?.let {
            action(it)
            return
        }
        if (openingCamera) return
        openingCamera = true
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            openingCamera = false
            try {
                val provider = future.get()
                cameraProvider = provider
                val recorder = Recorder.Builder()
                    .setQualitySelector(
                        QualitySelector.from(
                            Quality.HD,
                            FallbackStrategy.lowerQualityOrHigherThan(Quality.SD),
                        ),
                    )
                    .build()
                val capture = VideoCapture.withOutput(recorder)
                provider.unbindAll()
                // No preview use case: nothing is on screen to show it on.
                provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, capture)
                videoCapture = capture
                orientationListener.enable()
                action(capture)
            } catch (e: Exception) {
                listener?.onError(getString(R.string.error_camera, e.message.orEmpty()))
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun releaseCamera() {
        orientationListener.disable()
        cameraProvider?.unbindAll()
        videoCapture = null
    }

    // Camera and microphone permissions are checked by the activity before it
    // ever starts this service.
    @SuppressLint("MissingPermission")
    private fun startRecording() {
        if (recording != null || stopping) return
        withCamera { capture ->
            if (recording != null || stopping) return@withCamera

            val name = "VoiceCam_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
                .format(System.currentTimeMillis())
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/VoiceCam")
                }
            }
            val options = MediaStoreOutputOptions
                .Builder(contentResolver, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                .setContentValues(values)
                .build()

            var pending = capture.output.prepareRecording(this, options)
            if (withAudio) {
                // One mic: recording sound means the listener has to stand down,
                // so the recording can only be stopped from the notification.
                main.removeCallbacks(dutyCycle)
                voice.stop()
                pending = pending.withAudioEnabled()
            }

            recording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        refreshNotification()
                        applyListenPolicy()
                        publishState()
                    }

                    is VideoRecordEvent.Finalize -> onRecordingFinalized(event)
                    else -> Unit
                }
            }
        }
    }

    private fun stopRecording() {
        val active = recording ?: return
        if (stopping) return
        stopping = true
        active.stop()
    }

    private fun onRecordingFinalized(event: VideoRecordEvent.Finalize) {
        recording = null
        stopping = false
        releaseCamera()
        if (event.hasError()) {
            listener?.onError(getString(R.string.recording_failed, event.error))
        }
        applyListenPolicy()
        publishState()
    }

    // --- Voice ----------------------------------------------------------------

    private fun onVoiceCommand(command: VoiceCommand) {
        when (command) {
            VoiceCommand.START -> startRecording()
            VoiceCommand.STOP -> stopRecording()
        }
    }

    private fun onVoiceStatus(status: VoiceCommander.Status) {
        when (status) {
            is VoiceCommander.Status.Heard -> listener?.onHeard(status.text)
            is VoiceCommander.Status.Error -> listener?.onError(status.message)
            else -> publishState()
        }
    }

    private fun publishState() {
        listener?.onStateChanged(voice.isActive, recording != null)
    }

    companion object {
        private const val CHANNEL_ID = "voicecam"
        private const val NOTIFICATION_ID = 1

        /** Power-saving duty cycle: listen this long, then pause this long. */
        private const val SAVER_LISTEN_MS = 12_000L
        private const val SAVER_PAUSE_MS = 6_000L

        const val ACTION_STOP = "com.altuntopdev.voicecam.STOP"
        const val ACTION_TOGGLE_RECORDING = "com.altuntopdev.voicecam.TOGGLE_RECORDING"
        const val EXTRA_WITH_AUDIO = "with_audio"
        const val EXTRA_POWER_SAVING = "power_saving"

        /** Set while the service is alive, so the activity can show its state. */
        var running = false
            private set

        /**
         * The open activity, if any. Same process, single activity, so a plain
         * reference beats wiring up a broadcast — it is cleared in onStop().
         */
        var listener: Listener? = null

        fun start(context: Context, withAudio: Boolean, powerSaving: Boolean) {
            val intent = Intent(context, VoiceCamService::class.java)
                .putExtra(EXTRA_WITH_AUDIO, withAudio)
                .putExtra(EXTRA_POWER_SAVING, powerSaving)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, VoiceCamService::class.java).setAction(ACTION_STOP),
            )
        }
    }
}
