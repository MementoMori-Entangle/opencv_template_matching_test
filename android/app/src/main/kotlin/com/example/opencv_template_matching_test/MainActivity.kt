package com.example.opencv_template_matching_test

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.CvType
import org.opencv.core.MatOfDouble
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "opencv_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "matchImages") {
                val image1 = call.argument<String>("image1") ?: ""
                val image2 = call.argument<String>("image2") ?: ""
                val similarity = matchImagesFromPath(image1, image2)
                if (similarity != null) {
                    result.success(similarity)
                } else {
                    result.error("ERROR", "画像処理失敗", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun matchImagesFromPath(path1: String, path2: String): Double? {
        if (!OpenCVLoader.initDebug()) {
            android.util.Log.e("OpenCV", "OpenCVの初期化に失敗しました")
            return null
        }
        val mat1 = Imgcodecs.imread(path1, Imgcodecs.IMREAD_GRAYSCALE)
        val mat2 = Imgcodecs.imread(path2, Imgcodecs.IMREAD_GRAYSCALE)
        if (mat1.empty()) {
            android.util.Log.e("OpenCV", "画像1の読み込みに失敗: $path1")
            return null
        }
        if (mat2.empty()) {
            android.util.Log.e("OpenCV", "画像2の読み込みに失敗: $path2")
            return null
        }
        // 画像サイズチェック（テンプレートが画像より大きい場合のみ実行）
        if (mat1.rows() > mat2.rows() || mat1.cols() > mat2.cols()) {
            android.util.Log.e("OpenCV", "テンプレート画像のサイズが小さすぎます: 画像1(${mat1.cols()}x${mat1.rows()}) 画像2(${mat2.cols()}x${mat2.rows()})")
            return null
        }
        val result = Mat()
        Imgproc.matchTemplate(mat2, mat1, result, Imgproc.TM_CCOEFF_NORMED)
        val mmr = Core.minMaxLoc(result)
        return mmr.maxVal
    }
}
