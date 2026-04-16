package com.unicorn.ai_elder_assistant

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "SpeechRecognizerPlugin"
        private const val CHANNEL = "com.elder_assistant/speech"
        private const val REQUEST_SPEECH = 1001
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var flutterChannel: MethodChannel? = null
    private var useIntentMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        flutterChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> startListening(result)
                "stopListening" -> { stopListening(); result.success(null) }
                "cancelListening" -> { cancelListening(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SPEECH) {
            val ch = flutterChannel ?: return
            if (resultCode == android.app.Activity.RESULT_OK) {
                val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                if (!matches.isNullOrEmpty()) {
                    ch.invokeMethod("onResult", matches[0])
                    Log.d(TAG, "Intent result: ${matches[0]}")
                }
            } else {
                ch.invokeMethod("onError", "cancelled")
            }
            isListening = false
            useIntentMode = false
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        if (isListening) cancelListening()

        val available = SpeechRecognizer.isRecognitionAvailable(this)
        Log.d(TAG, "startListening: isRecognitionAvailable=$available")

        if (available) {
            createDirectRecognizer(result)
        } else {
            Log.d(TAG, "Direct not available, using Intent mode")
            useIntentMode = true
            result.success("started")
            launchIntentRecognizer()
        }
    }

    private fun createDirectRecognizer(result: MethodChannel.Result) {
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ko-KR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        val channel = flutterChannel ?: run { result.error("ERROR", "Channel not ready", null); return }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                channel.invokeMethod("onReady", null)
            }
            override fun onBeginningOfSpeech() {
                channel.invokeMethod("onBegin", null)
            }
            override fun onRmsChanged(rmsdB: Float) {
                channel.invokeMethod("onRmsChanged", rmsdB)
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                isListening = false
                channel.invokeMethod("onEnd", null)
            }
            override fun onError(error: Int) {
                isListening = false
                Log.e(TAG, "Direct recognizer error: $error")
                // ALL errors fall back to Intent mode (more reliable)
                if (error != 7) { // 7 = no_match (用户没说话), don't fallback for that
                    Log.d(TAG, "Falling back to Intent mode due to error $error")
                    useIntentMode = true
                    launchIntentRecognizer()
                    return
                }
                val errorMap = mapOf(
                    1 to "network_timeout", 2 to "network_error",
                    3 to "audio_error", 4 to "server_error",
                    5 to "permission_error", 6 to "busy",
                    7 to "no_match", 8 to "partial_match", 9 to "unknown"
                )
                channel.invokeMethod("onError", errorMap[error] ?: "unknown_error")
            }
            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    channel.invokeMethod("onResult", matches[0])
                }
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    channel.invokeMethod("onPartialResult", matches[0])
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer?.startListening(recognizerIntent)
        result.success("started")
    }

    private fun launchIntentRecognizer() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ko-KR")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "말씀해 주세요")
        }
        startActivityForResult(intent, REQUEST_SPEECH)
    }

    private fun stopListening() {
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
    }

    private fun cancelListening() {
        try { speechRecognizer?.cancel() } catch (_: Exception) {}
        isListening = false
        useIntentMode = false
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
    }
}
