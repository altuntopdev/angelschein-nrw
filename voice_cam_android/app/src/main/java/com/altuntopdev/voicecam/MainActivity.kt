package com.altuntopdev.voicecam

import android.Manifest
import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.OrientationEventListener
import android.view.View
import android.view.Surface
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import com.altuntopdev.voicecam.databinding.ActivityMainBinding
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * One screen: a camera preview that starts and stops recording on a spoken
 * command ("kayıt başlat" / "kaydı durdur"), with buttons for the same thing.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var voice: VoiceCommander

    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    /**
     * Set between [stopRecording] and the Finalize event. The recording object
     * has to stay around until then — starting a new one while the recorder is
     * still finalizing throws.
     */
    private var stopping = false
    private var recordingStartedAt = 0L

    private val ticker = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            val seconds = (System.currentTimeMillis() - recordingStartedAt) / 1000
            binding.timerText.text = getString(
                R.string.recording_timer,
                seconds / 60,
                seconds % 60,
            )
            ticker.postDelayed(this, 500)
        }
    }

    /**
     * The mic can only serve one client at a time. "Hands-free" keeps the
     * recognizer running so "durdur" works, at the cost of a silent video;
     * turning it off records sound and pauses the listener until you stop.
     */
    private val handsFree: Boolean
        get() = binding.handsFreeSwitch.isChecked

    private lateinit var orientationListener: OrientationEventListener

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
        if (granted.all { it.value }) {
            onPermissionsGranted()
        } else {
            binding.statusText.text = getString(R.string.error_permission)
            binding.recordButton.isEnabled = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        voice = VoiceCommander(
            context = this,
            onCommand = ::onVoiceCommand,
            onStatus = ::onVoiceStatus,
        )

        binding.recordButton.setOnClickListener {
            if (recording == null) startRecording() else stopRecording()
        }
        binding.micButton.setOnClickListener {
            if (voice.isActive) voice.stop() else voice.start()
            updateMicButton()
        }
        binding.handsFreeSwitch.setOnCheckedChangeListener { _, _ ->
            if (recording == null) binding.hintText.text = hintText()
        }
        binding.hintText.text = hintText()

        orientationListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                // The activity is locked to portrait, so the video's rotation
                // has to be derived from the sensor instead of the display.
                videoCapture?.targetRotation = when (orientation) {
                    in 45..134 -> Surface.ROTATION_270
                    in 135..224 -> Surface.ROTATION_180
                    in 225..314 -> Surface.ROTATION_90
                    else -> Surface.ROTATION_0
                }
            }
        }

        if (hasPermissions()) {
            onPermissionsGranted()
        } else {
            permissionLauncher.launch(REQUIRED_PERMISSIONS)
        }
    }

    override fun onStart() {
        super.onStart()
        orientationListener.enable()
        // Never hold the mic while the app is in the background.
        if (hasPermissions() && recording == null) voice.start()
        updateMicButton()
    }

    override fun onStop() {
        orientationListener.disable()
        voice.stop()
        updateMicButton()
        super.onStop()
    }

    override fun onDestroy() {
        voice.destroy()
        ticker.removeCallbacks(tick)
        super.onDestroy()
    }

    private fun hasPermissions() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun onPermissionsGranted() {
        binding.recordButton.isEnabled = true
        startCamera()
        voice.start()
        updateMicButton()
    }

    // --- Camera --------------------------------------------------------------

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            val provider = future.get()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(binding.previewView.surfaceProvider)
            }
            val recorder = Recorder.Builder()
                .setQualitySelector(
                    QualitySelector.from(
                        Quality.FHD,
                        FallbackStrategy.lowerQualityOrHigherThan(Quality.SD),
                    ),
                )
                .build()
            val capture = VideoCapture.withOutput(recorder)

            try {
                provider.unbindAll()
                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    capture,
                )
                videoCapture = capture
            } catch (e: Exception) {
                binding.statusText.text = getString(R.string.error_camera, e.message.orEmpty())
            }
        }, ContextCompat.getMainExecutor(this))
    }

    // Both permissions are granted before the camera is ever started, and the
    // mic one is re-checked by hasPermissions() on every onStart.
    @SuppressLint("MissingPermission")
    private fun startRecording() {
        val capture = videoCapture ?: return
        if (recording != null || stopping) return

        val name = "VoiceCam_" + SimpleDateFormat(
            "yyyyMMdd_HHmmss",
            Locale.US,
        ).format(System.currentTimeMillis())
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
        if (!handsFree) {
            // Sound is only recorded when the listener is about to be paused —
            // otherwise the recognizer and the recorder fight over the mic.
            voice.stop()
            pending = pending.withAudioEnabled()
        }

        recording = pending.start(ContextCompat.getMainExecutor(this)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> onRecordingStarted()
                is VideoRecordEvent.Finalize -> onRecordingFinalized(event)
                else -> Unit
            }
        }
    }

    private fun stopRecording() {
        val active = recording ?: return
        if (stopping) return
        stopping = true
        active.stop()
    }

    private fun onRecordingStarted() {
        recordingStartedAt = System.currentTimeMillis()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        binding.recordButton.setText(R.string.stop_recording)
        binding.handsFreeSwitch.isEnabled = false
        // With audio in the video, the mic is taken — no point offering it.
        binding.micButton.isEnabled = handsFree
        binding.timerText.visibility = View.VISIBLE
        binding.hintText.setText(
            if (handsFree) R.string.hint_recording_hands_free else R.string.hint_recording_audio,
        )
        ticker.post(tick)
    }

    private fun onRecordingFinalized(event: VideoRecordEvent.Finalize) {
        ticker.removeCallbacks(tick)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        recording = null
        stopping = false
        binding.recordButton.setText(R.string.start_recording)
        binding.handsFreeSwitch.isEnabled = true
        binding.micButton.isEnabled = true
        binding.timerText.visibility = View.GONE
        binding.hintText.text = hintText()

        if (event.hasError()) {
            toast(getString(R.string.recording_failed, event.error))
        } else {
            toast(getString(R.string.recording_saved))
        }
        // The listener was paused for an audio recording; bring it back — but
        // not if this finalize came from the activity stopping, because then the
        // app is in the background and has no business holding the mic.
        if (!voice.isActive && lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            voice.start()
        }
        updateMicButton()
    }

    // --- Voice ---------------------------------------------------------------

    private fun onVoiceCommand(command: VoiceCommand) {
        when (command) {
            VoiceCommand.START -> if (recording == null) startRecording()
            VoiceCommand.STOP -> if (recording != null) stopRecording()
        }
    }

    private fun onVoiceStatus(status: VoiceCommander.Status) {
        when (status) {
            is VoiceCommander.Status.Listening ->
                binding.statusText.setText(R.string.status_listening)
            is VoiceCommander.Status.Stopped ->
                binding.statusText.setText(R.string.status_mic_off)
            is VoiceCommander.Status.Heard ->
                binding.heardText.text = getString(R.string.heard, status.text)
            is VoiceCommander.Status.Error ->
                binding.statusText.text = status.message
        }
    }

    private fun updateMicButton() {
        binding.micButton.setText(
            if (voice.isActive) R.string.mic_on else R.string.mic_off,
        )
    }

    private fun hintText(): String = getString(
        if (handsFree) R.string.hint_hands_free else R.string.hint_audio,
    )

    private fun toast(message: String) =
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()

    companion object {
        private val REQUIRED_PERMISSIONS = buildList {
            add(Manifest.permission.CAMERA)
            add(Manifest.permission.RECORD_AUDIO)
            // Before scoped storage, MediaStore writes still need the file
            // permission at runtime.
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }.toTypedArray()
    }
}
