package com.altuntopdev.voicecam

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VoiceCommandsTest {

    @Test
    fun `turkish start phrases map to START`() {
        listOf(
            "Kayıt başlat",
            "kaydı başlat",
            "Kayda başla",
            "videoyu başlat",
            "çekimi başlat",
            "başlat",
        ).forEach {
            assertEquals("\"$it\"", VoiceCommand.START, VoiceCommands.commandIn(it))
        }
    }

    @Test
    fun `turkish stop phrases map to STOP`() {
        listOf(
            "Kaydı durdur",
            "kayıt durdur",
            "kaydı bitir",
            "durdur",
            "dur",
        ).forEach {
            assertEquals("\"$it\"", VoiceCommand.STOP, VoiceCommands.commandIn(it))
        }
    }

    @Test
    fun `stop wins when a phrase carries both words`() {
        assertEquals(VoiceCommand.STOP, VoiceCommands.commandIn("kayıt durdur"))
    }

    @Test
    fun `unrelated speech is ignored`() {
        listOf(
            "bugün hava çok güzel",
            "durum nedir",
            "başlangıç noktası",
            "",
        ).forEach {
            assertNull("\"$it\"", VoiceCommands.commandIn(it))
        }
    }

    @Test
    fun `normalize folds turkish letters and punctuation`() {
        assertEquals("kaydi baslat", VoiceCommands.normalize("Kaydı, başlat!"))
        assertEquals("cekimi durdur", VoiceCommands.normalize("ÇEKİMİ DURDUR"))
    }
}
