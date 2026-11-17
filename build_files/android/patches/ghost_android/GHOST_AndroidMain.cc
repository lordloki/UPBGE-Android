// SPDX-License-Identifier: GPL-3.0-or-later
// intern/ghost/intern/GHOST_AndroidMain.cc
//
// Glue between the Android native_app_glue and the rest of GHOST. The native
// glue expects the application to:
//   - export void android_main(struct android_app* app)
//   - pump its event loop forever (or until app->destroyRequested)
//
// This file implements android_main in terms of GHOST_SystemAndroid: it creates
// the system, registers the command/input callbacks, and lets GHOST's normal
// event loop do the rest. The blenderplayer binary provides the actual
// application logic on top — see build_files/android/patches/player_entrypoint/
// for how the player's main() is wrapped.

#include "GHOST_SystemAndroid.hh"

#include <android/native_app_glue/android_native_app_glue.h>
#include <android/log.h>

#define LOG_TAG "upbge_main"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

static GHOST_SystemAndroid *g_system_android = nullptr;

// Glue callbacks forward into the GHOST system.
static void on_app_cmd(struct android_app *app, int32_t cmd) {
  if (g_system_android) g_system_android->onAppCmd(cmd);
}

static int32_t on_input_event(struct android_app *app, AInputEvent *event) {
  if (g_system_android) return g_system_android->onInputEvent(event);
  return 0;
}

extern "C" void android_main(struct android_app *app) {
  LOGI("android_main: starting UPBGE blenderplayer");

  // Make the glue non-blocking so GHOST can drive the loop.
  app->onAppCmd     = on_app_cmd;
  app->onInputEvent = on_input_event;

  // Build the GHOST system. The actual application main lives in the
  // blenderplayer target (see player_entrypoint/android_main_wrapper.cc),
  // which will call GHOST_CreateSystemVulkan() with our GHOST_SystemAndroid.
  g_system_android = new GHOST_SystemAndroid();
  g_system_android->setAndroidApp(app);

  // The player main (BLI_main) is expected to be invoked from a separate
  // thread created by the wrapper in player_entrypoint/. This function does
  // NOT return until app->destroyRequested is set.
  while (!app->destroyRequested) {
    g_system_android->processEvents(false);
    // Sleep to avoid busy-looping; the player thread does the actual work.
    usleep(1000);  // 1 ms
  }

  LOGI("android_main: destroy requested, exiting");
  delete g_system_android;
  g_system_android = nullptr;
}
