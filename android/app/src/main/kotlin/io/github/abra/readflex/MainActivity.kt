package io.github.abra.readflex

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val systemUiHandler = Handler(Looper.getMainLooper())
    private val hideSystemNavigation = Runnable { hideSystemNavigationBar() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scheduleSystemNavigationHide()
    }

    override fun onPostResume() {
        super.onPostResume()
        scheduleSystemNavigationHide()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            scheduleSystemNavigationHide()
        }
    }

    override fun onDestroy() {
        systemUiHandler.removeCallbacks(hideSystemNavigation)
        super.onDestroy()
    }

    private fun scheduleSystemNavigationHide() {
        hideSystemNavigationBar()
        systemUiHandler.removeCallbacks(hideSystemNavigation)
        systemUiHandler.postDelayed(hideSystemNavigation, 1200)
    }

    private fun hideSystemNavigationBar() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
            return
        }

        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }
}
