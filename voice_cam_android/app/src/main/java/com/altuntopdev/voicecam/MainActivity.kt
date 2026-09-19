package com.altuntopdev.voicecam

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.altuntopdev.voicecam.databinding.ActivityMainBinding

/**
 * A control panel, nothing more: it asks for the permissions and starts or
 * stops [VoiceCamService], which is what actually listens and records. Closing
 * this screen — or locking the phone — does not stop anything.
 */
class MainActivity : AppCompatActivity(), VoiceCamService.Listener {

    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: SharedPreferences

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
        // A denied notification permission costs us the status notification,
        // not the feature, so it does not block the start.
        if (granted.filterKeys { it != Manifest.permission.POST_NOTIFICATIONS }
                .all { it.value }
        ) {
            startService()
        } else {
            binding.statusText.setText(R.string.error_permission)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        binding.audioSwitch.isChecked = prefs.getBoolean(KEY_AUDIO, false)
        binding.saverSwitch.isChecked = prefs.getBoolean(KEY_SAVER, true)

        binding.audioSwitch.setOnCheckedChangeListener { _, checked ->
            prefs.edit().putBoolean(KEY_AUDIO, checked).apply()
        }
        binding.saverSwitch.setOnCheckedChangeListener { _, checked ->
            prefs.edit().putBoolean(KEY_SAVER, checked).apply()
        }

        binding.toggleButton.setOnClickListener {
            if (VoiceCamService.running) {
                VoiceCamService.stop(this)
                // The service publishes its own state, but not after it is gone.
                binding.root.postDelayed(::render, 300)
            } else if (hasPermissions()) {
                startService()
            } else {
                permissionLauncher.launch(requiredPermissions())
            }
        }

        binding.batteryButton.setOnClickListener {
            runCatching {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }.onFailure {
                Toast.makeText(this, R.string.battery_settings_missing, Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        VoiceCamService.listener = this
        render()
    }

    override fun onStop() {
        VoiceCamService.listener = null
        super.onStop()
    }

    private fun startService() {
        VoiceCamService.start(
            context = this,
            withAudio = binding.audioSwitch.isChecked,
            powerSaving = binding.saverSwitch.isChecked,
        )
        binding.root.postDelayed(::render, 300)
    }

    private fun hasPermissions() = requiredPermissions()
        .filter { it != Manifest.permission.POST_NOTIFICATIONS }
        .all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }

    private fun render() = showState(
        running = VoiceCamService.running,
        listening = VoiceCamService.running,
        recording = false,
    )

    private fun showState(running: Boolean, listening: Boolean, recording: Boolean) {
        binding.toggleButton.setText(
            if (running) R.string.stop_listening else R.string.start_listening,
        )
        binding.statusText.setText(
            when {
                !running -> R.string.status_off
                recording -> R.string.status_recording
                listening -> R.string.status_listening
                else -> R.string.status_paused
            },
        )
        val state = when {
            !running -> R.color.state_idle
            recording -> R.color.state_recording
            listening -> R.color.state_listening
            else -> R.color.state_idle
        }
        binding.statusIcon.backgroundTintList =
            ContextCompat.getColorStateList(this, state)
        // The switches describe how the service was started, so they are frozen
        // while it runs.
        binding.audioSwitch.isEnabled = !running
        binding.saverSwitch.isEnabled = !running
        if (!running) binding.heardText.text = ""
    }

    // --- VoiceCamService.Listener --------------------------------------------

    override fun onStateChanged(listening: Boolean, recording: Boolean) = runOnUiThread {
        showState(VoiceCamService.running, listening, recording)
    }

    override fun onHeard(text: String) = runOnUiThread {
        binding.heardText.text = getString(R.string.heard, text)
    }

    override fun onError(message: String) = runOnUiThread {
        binding.statusText.text = message
    }

    private fun requiredPermissions(): Array<String> = buildList {
        add(Manifest.permission.CAMERA)
        add(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.POST_NOTIFICATIONS)
        }
        // Before scoped storage, MediaStore writes still need the file permission.
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
    }.toTypedArray()

    private companion object {
        const val PREFS = "voicecam"
        const val KEY_AUDIO = "with_audio"
        const val KEY_SAVER = "power_saving"
    }
}
