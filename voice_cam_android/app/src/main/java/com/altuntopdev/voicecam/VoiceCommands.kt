package com.altuntopdev.voicecam

import java.util.Locale

/** The two things the user can ask for out loud. */
enum class VoiceCommand { START, STOP }

/**
 * Maps a speech transcript onto a [VoiceCommand].
 *
 * Kept free of Android types so the matching — the part most likely to get a
 * phrase wrong — can be unit tested on the JVM.
 */
object VoiceCommands {

    private val TURKISH: Locale = Locale.forLanguageTag("tr-TR")

    private val START_PHRASES = listOf(
        "kayit baslat", "kaydi baslat", "kayda basla", "kayit basla",
        "video baslat", "videoyu baslat", "cekimi baslat", "cekime basla",
        "baslat", "basla", "kaydet", "start recording", "start", "record",
    )

    private val STOP_PHRASES = listOf(
        "kayit durdur", "kaydi durdur", "kayit bitir", "kaydi bitir",
        "videoyu durdur", "cekimi durdur", "kaydi kes", "kaydi bitirdim",
        "durdur", "bitir", "dur", "stop recording", "stop",
    )

    /** Stop wins over start so "kaydı durdur" is never read as "kayıt". */
    fun commandIn(text: String): VoiceCommand? {
        val normalized = normalize(text)
        if (normalized.isEmpty()) return null
        if (STOP_PHRASES.any { normalized.containsPhrase(it) }) return VoiceCommand.STOP
        if (START_PHRASES.any { normalized.containsPhrase(it) }) return VoiceCommand.START
        return null
    }

    /**
     * Folds Turkish letters onto ASCII so a transcript like "Kaydı Başlat"
     * matches the keyword list however the recognizer spelled it.
     */
    fun normalize(text: String): String = text
        .lowercase(TURKISH)
        .replace('ı', 'i')
        .replace('ş', 's')
        .replace('ğ', 'g')
        .replace('ü', 'u')
        .replace('ö', 'o')
        .replace('ç', 'c')
        .replace('â', 'a')
        // Also drops the combining dot Turkish lowercasing leaves on "İ".
        .replace(Regex("[^a-z0-9 ]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()

    /** Whole-word match, so "dur" does not fire inside "durum". */
    private fun String.containsPhrase(phrase: String): Boolean =
        Regex("(^|\\s)${Regex.escape(phrase)}($|\\s)").containsMatchIn(this)
}
