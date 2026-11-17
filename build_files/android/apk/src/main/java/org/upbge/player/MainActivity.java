/*
 * MainActivity.java — the Java side of the UPBGE player.
 *
 * Responsibilities:
 *   - Create an Android SurfaceView that hosts ANativeWindow.
 *   - Hand the surface to the native glue (libupbgeplayer.so).
 *   - Forward lifecycle events (resume / pause / destroy).
 *   - Forward launch intents (which .blend to load) as extras.
 *
 * The native glue (in GHOST_AndroidMain.cc + android_main_wrapper.cc) handles
 * the rest: input pump, GHOST event loop, player_main() thread.
 */

package org.upbge.player;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.WindowManager;

public class MainActivity extends Activity implements SurfaceHolder.Callback2 {
    private static final String TAG = "upbge.MainActivity";

    static {
        // Load the cross-compiled native library. The native_app_glue
        // trampoline is invoked automatically by the NDK startup code.
        System.loadLibrary("upbgeplayer");
    }

    private SurfaceView mView;
    private boolean mSurfaceReady = false;
    private String mBlendPath = null;

    // --- JNI bridge -----------------------------------------------------------
    private native void nativeOnSurfaceCreated(Surface surface);
    private native void nativeOnSurfaceDestroyed();
    private native void nativeSetBlendPath(String path);
    private native void nativeOnPause();
    private native void nativeOnResume();
    private native void nativeOnDestroy();

    // --- Activity -------------------------------------------------------------
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // Inspect launch intent: did the add-on hand us a .blend path?
        Intent intent = getIntent();
        if (intent != null) {
            Uri data = intent.getData();
            if (data != null) {
                mBlendPath = data.toString();
                Log.i(TAG, "launch .blend=" + mBlendPath);
                nativeSetBlendPath(mBlendPath);
            } else if (intent.hasExtra("blend_path")) {
                mBlendPath = intent.getStringExtra("blend_path");
                Log.i(TAG, "launch extra .blend=" + mBlendPath);
                nativeSetBlendPath(mBlendPath);
            }
        }

        mView = new SurfaceView(this);
        mView.getHolder().addCallback(this);
        setContentView(mView);
    }

    @Override
    protected void onResume() {
        super.onResume();
        nativeOnResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
        nativeOnPause();
    }

    @Override
    protected void onDestroy() {
        nativeOnDestroy();
        super.onDestroy();
    }

    // --- SurfaceHolder.Callback2 ---------------------------------------------
    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Log.i(TAG, "surfaceCreated");
        mSurfaceReady = true;
        nativeOnSurfaceCreated(holder.getSurface());
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
        Log.i(TAG, "surfaceChanged w=" + w + " h=" + h);
        // The native side re-reads the window extents when ANativeWindow
        // changes, so we don't need a separate call here.
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        Log.i(TAG, "surfaceDestroyed");
        mSurfaceReady = false;
        nativeOnSurfaceDestroyed();
    }

    @Override
    public void surfaceRedrawNeeded(SurfaceHolder holder) {
        // No-op; the player thread renders continuously.
    }
}
