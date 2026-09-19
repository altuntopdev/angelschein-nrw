package com.altuntopdev.voicecam

import android.content.Context
import android.content.Intent
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
 * hammering the recognition service when it is unavailable (no network for the
 * online engine, another app holding the mic, ...).
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
    private var recognizer: SpeechRecognizer? = null

    /** True between [start] and [stop] — not "the mic is open right now". */
    var isActive = false
        private set

    private var failureStreak = 0
    private var lastCommand: VoiceCommand? = null
    private var lastCommandAt = 0L

    private val restart = Runnable { listenOnce() }

    fun start() {
        if (isActive) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            onStatus(Status.Error(context.getString(R.string.error_no_recognizer)))
            return
        }
        isActive = true
        failureStreak = 0
        recognizer = SpeechRecognizer.createSpeechRecognizer(context).also {
            it.setRecognitionListener(this)
        }
        listenOnce()
    }

    fun stop() {
        if (!isActive) return
        isActive = false
        main.removeCallbacks(restart)
        recognizer?.let {
            it.cancel()
            it.destroy()
        }
        recognizer = null
        onStatus(Status.Stopped)
    }

    fun destroy() {
        stop()
        main.removeCallbacksAndMessages(null)
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
            // EXTRA_PREFER_OFFLINE is deliberately not set: engines that have no
            // offline pack for the language answer it with ERROR_NO_MATCH
            // instead of falling back. With the Turkish offline pack installed
            // the recognizer already runs on-device on its own.
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
        val delay = when (error) {
            // Nothing was said — that is the normal case for an always-on
            // listener, so loop straight back around.
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
    }
}
