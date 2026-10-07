package com.everif.everif_face_sdk

import kotlin.test.Test
import kotlin.test.assertEquals

internal class FaceEngineBoundaryTest {
    @Test
    fun mapsKnownErrorsWithoutLeakingNativeDetails() {
        assertEquals("multipleFaces", FaceEngine.publicError(IllegalStateException("multipleFaces: detector details")))
        assertEquals("internal", FaceEngine.publicError(IllegalStateException("secret native failure")))
    }
}
