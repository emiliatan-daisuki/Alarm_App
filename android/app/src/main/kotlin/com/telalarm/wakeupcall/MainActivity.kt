package com.telalarm.wakeupcall

import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.telalarm.wakeupcall"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playAlarmSound") {
                playAlarmSound()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun playAlarmSound() {
        val mediaPlayer = MediaPlayer.create(this, R.raw.alarm_sound)
        mediaPlayer.setAudioStreamType(AudioManager.STREAM_ALARM)
        mediaPlayer.setOnCompletionListener {
            mediaPlayer.release() // 'it' 대신 mediaPlayer를 명시적으로 사용
        }
        mediaPlayer.start()
    }

}
