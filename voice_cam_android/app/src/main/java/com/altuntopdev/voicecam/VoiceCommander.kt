package com.altuntopdev.voicecam

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/**
 * Keeps [SpeechRecognizer] running in a loop so the app is always listening.
 *
 * Android's recognizer only ever handles one utterance and then stops, so every
 * result/error is followed by a restart. Errors get a small backoff to avoid
 * hammering the recognition service when it is unavailable.
 *
 * Two things keep the loop quiet: the on-device recognizer is preferred (it
 * does not play the start/stop earcons the network one does), and the streams
 * those earcons come out of are muted while listening.
 */
class VoiceCommander(
    private val context: Context,
    private val language: String = "tr-TR",
    private val onCommand: (VoiceCommand) -> Unit,
    private val onStatus: (Status) -> Unit,
) : RecognitionListener {

    /** What the UI needs to know about the listener. */
    sealed class Status {
        object Listening : Status()
        object Stopped : Status()
        data class Heard(val text: String) : Status()
        data class Error(val message: String) : Status()
    }

    private val main = Handler(Looper.getMainLooper())
    private val audio = context.getSystemService(AudioManager::class.java)
    private var recognizer: SpeechRecognizer? = null

    /** True between [start] and [stop] — not "the mic is open right now". */
    var isActive = false
        private set

    private var failureStreak = 0
    private var lastCommand: VoiceCommand? = null
    private var lastCommandAt = 0L
    private var muted = false

    /** Set once the on-device engine says it has no model for [language]. */
    private var useSystemRecognizer = false

    private val restart = Runnable { listenOnce() }

    fun start() {
        if (isActive) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            onStatus(Status.Error(context.getString(R.string.error_no_recognizer)))
            return
        }
        isActive = true
        failureStreak = 0
        muteBeeps()
        createRecognizer()
        listenOnce()
    }

    fun stop() {
        if (!isActive) return
        isActive = false
        main.removeCallbacks(restart)
        destroyRecognizer()
        unmuteBeeps()
        onStatus(Status.Stopped)
    }

    fun destroy() {
        stop()
        main.removeCallbacksAndMessages(null)
        // Belt and braces: never leave the phone muted behind us.
        unmuteBeeps()
    }

    private fun createRecognizer() {
        destroyRecognizer()
        val fresh = if (!useSystemRecognizer &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }
        fresh.setRecognitionListener(this)
        recognizer = fresh
    }

    private fun destroyRecognizer() {
        recognizer?.let {
            it.cancel()
            it.destroy()
        }
        recognizer = null
    }

    private fun listenOnce() {
        if (!isActive) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            // Longer silence windows mean fewer restarts, and every restart is a
            // chance for the engine to make a noise.
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                2_000L,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                2_000L,
            )
        }
        try {
            recognizer?.startListening(intent)
            onStatus(Status.Listening)
        } catch (e: SecurityException) {
            onStatus(Status.Error(e.message ?: context.getString(R.string.error_mic)))
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        if (!isActive) return
        main.removeCallbacks(restart)
        main.postDelayed(restart, delayMs)
    }

    // --- Beeps ---------------------------------------------------------------

    /**
     * The recognizer's earcons come out of the media/system/notification
     * streams, depending on the device. Muting the ring and alarm streams too
     * would hide calls, so those are left alone.
     */
    private fun muteBeeps() {
        if (muted) return
        BEEP_STREAMS.forEach { stream ->
            runCatching { audio.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, 0) }
        }
        muted = true
    }

    private fun unmuteBeeps() {
        if (!muted) return
        BEEP_STREAMS.forEach { stream ->
            runCatching { audio.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0) }
        }
        muted = false
    }

    // --- RecognitionListener -------------------------------------------------

    override fun onReadyForSpeech(params: Bundle?) {
        failureStreak = 0
    }

    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    override fun onPartialResults(partialResults: Bundle?) {
        // Acting on partials makes the command feel instant instead of waiting
        // out the recognizer's end-of-speech timeout.
        handle(partialResults, isFinal = false)
    }

    override fun onResults(results: Bundle?) {
        handle(results, isFinal = true)
        scheduleRestart(RESTART_DELAY_MS)
    }

    override fun onError(error: Int) {
        // The on-device engine has no model for this language — fall back to the
        // system one for good, even though it is the chattier of the two.
        if (!useSystemRecognizer && error in LANGUAGE_ERRORS) {
            useSystemRecognizer = true
            createRecognizer()
            scheduleRestart(RESTART_DELAY_MS)
            return
        }

        val delay = when (error) {
            // Nothing was said — the normal case for an always-on listener.
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
            -> RESTART_DELAY_MS

            SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
            SpeechRecognizer.ERROR_CLIENT,
            -> BUSY_DELAY_MS

            else -> {
                failureStreak++
                onStatus(Status.Error(messageFor(error)))
                minOf(BUSY_DELAY_MS * failureStreak, MAX_BACKOFF_MS)
            }
        }
        scheduleRestart(delay)
    }

    private fun handle(bundle: Bundle?, isFinal: Boolean) {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
        if (matches.isEmpty()) return
        matches.firstOrNull()?.takeIf { it.isNotBlank() }?.let { onStatus(Status.Heard(it)) }

        val command = matches.firstNotNullOfOrNull { VoiceCommands.commandIn(it) } ?: return
        val now = System.currentTimeMillis()
        // The same phrase arrives as several partials and then once more as the
        // final result; only fire on the first sighting.
        if (command == lastCommand && now - lastCommandAt < COMMAND_DEBOUNCE_MS) return
        lastCommand = command
        lastCommandAt = now
        onCommand(command)
        if (!isFinal) {
            // Cut the utterance short so the next command can be picked up right
            // away instead of after the trailing silence timeout.
            recognizer?.cancel()
            scheduleRestart(RESTART_DELAY_MS)
        }
    }

    private fun messageFor(error: Int): String = context.getString(
        when (error) {
            SpeechRecognizer.ERROR_AUDIO -> R.string.error_mic
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> R.string.error_permission
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
            -> R.string.error_network
            SpeechRecognizer.ERROR_SERVER -> R.string.error_server
            else -> R.string.error_generic
        },
    )

    companion object {
        private const val RESTART_DELAY_MS = 250L
        private const val BUSY_DELAY_MS = 800L
        private const val MAX_BACKOFF_MS = 5_000L
        private const val COMMAND_DEBOUNCE_MS = 2_500L

        private val BEEP_STREAMS = intArrayOf(
            AudioManager.STREAM_MUSIC,
            AudioManager.STREAM_SYSTEM,
            AudioManager.STREAM_NOTIFICATION,
        )

        /** ERROR_LANGUAGE_NOT_SUPPORTED / ERROR_LANGUAGE_UNAVAILABLE (API 33). */
        private val LANGUAGE_ERRORS = setOf(12, 13)
    }
}
