# tflite_flutter referenzia il delegate GPU opzionale di TensorFlow Lite,
# non incluso come dipendenza (l'app non lo usa): R8 fallisce la build in
# release senza questa regola, vedi build/app/outputs/mapping/release/missing_rules.txt.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
