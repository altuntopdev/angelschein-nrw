package com.altuntopdev.voicecam

import android.Manifest
import android.content.Intent
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

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
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
        VoiceCamService.start(this, withAudio = binding.audioSwitch.isChecked)
        binding.root.postDelayed(::render, 300)
    }

    private fun hasPermissions() = requiredPermissions()
        .filter { it != Manifest.permission.POST_NOTIFICATIONS }
        .all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }

    private fun render() {
        val running = VoiceCamService.running
        binding.toggleButton.setText(if (running) R.string.stop_listening else R.string.start_listening)
        binding.statusText.setText(if (running) R.string.status_listening else R.string.status_off)
        binding.audioSwitch.isEnabled = !running
    }

    // --- VoiceCamService.Listener --------------------------------------------

    override fun onStateChanged(listening: Boolean, recording: Boolean) = runOnUiThread {
        render()
        if (recording) binding.statusText.setText(R.string.status_recording)
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
            // Only for the ongoing notification; denying it must not block the app.
            add(Manifest.permission.POST_NOTIFICATIONS)
        }
        // Before scoped storage, MediaStore writes still need the file permission.
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
    }.toTypedArray()
}
