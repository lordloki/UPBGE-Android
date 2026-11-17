// SPDX-License-Identifier: GPL-3.0-or-later
// intern/ghost/intern/GHOST_SystemAndroid.cc

#include "GHOST_SystemAndroid.hh"
#include "GHOST_EventButton.hh"
#include "GHOST_EventCursor.hh"
#include "GHOST_EventKey.hh"
#include "GHOST_EventString.hh"
#include "GHOST_WindowAndroid.hh"

#include <android/log.h>
#include <android/native_app_glue/android_native_app_glue.h>
#include <android/input.h>
#include <chrono>

#define LOG_TAG "upbge_ghost"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// -----------------------------------------------------------------------------
// Construction
// -----------------------------------------------------------------------------
GHOST_SystemAndroid::GHOST_SystemAndroid() {
  m_start_ms = getMilliSeconds();
}

GHOST_SystemAndroid::~GHOST_SystemAndroid() = default;

GHOST_TSuccess GHOST_SystemAndroid::init() {
  GHOST_TSuccess ok = GHOST_System::init();
  if (ok != GHOST_kSuccess) return ok;
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemAndroid::exit() {
  if (m_window) {
    m_window = nullptr;
  }
  return GHOST_System::exit();
}

// -----------------------------------------------------------------------------
// Time
// -----------------------------------------------------------------------------
GHOST_TUns64 GHOST_SystemAndroid::getMilliSeconds() const {
  using namespace std::chrono;
  return static_cast<GHOST_TUns64>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

// -----------------------------------------------------------------------------
// Window
// -----------------------------------------------------------------------------
void GHOST_SystemAndroid::onNativeWindowCreated(ANativeWindow *win) {
  LOGI("onNativeWindowCreated %p", win);
  if (!m_window) {
    m_window = new GHOST_WindowAndroid(this, "UPBGE", 0, 0,
                                       static_cast<uint32_t>(ANativeWindow_getWidth(win)),
                                       static_cast<uint32_t>(ANativeWindow_getHeight(win)),
                                       GHOST_kWindowStateNormal,
                                       GHOST_ContextSettings{});
    // Register with the window manager so dispatch finds it.
    m_windowManager->addWindow(m_window);
  }
  m_window->setNativeWindow(win);
}

void GHOST_SystemAndroid::onNativeWindowDestroyed() {
  LOGI("onNativeWindowDestroyed");
  if (m_window) m_window->setNativeWindow(nullptr);
}

// -----------------------------------------------------------------------------
// App commands from the native app glue
// -----------------------------------------------------------------------------
void GHOST_SystemAndroid::onAppCmd(int32_t cmd) {
  switch (cmd) {
    case APP_CMD_INIT_WINDOW:
      if (m_app && m_app->window) onNativeWindowCreated(m_app->window);
      break;
    case APP_CMD_TERM_WINDOW:
      onNativeWindowDestroyed();
      break;
    case APP_CMD_GAINED_FOCUS: {
      if (m_window) pushEvent(new GHOST_Event(getMilliSeconds(),
                                              GHOST_kEventWindowActivate, m_window));
      break;
    }
    case APP_CMD_LOST_FOCUS: {
      if (m_window) pushEvent(new GHOST_Event(getMilliSeconds(),
                                              GHOST_kEventWindowDeactivate, m_window));
      break;
    }
    case APP_CMD_WINDOW_RESIZED: {
      if (m_app && m_app->window) onNativeWindowCreated(m_app->window);
      break;
    }
    case APP_CMD_PAUSE: case APP_CMD_STOP: case APP_CMD_DESTROY: {
      if (m_window) pushEvent(new GHOST_Event(getMilliSeconds(),
                                              GHOST_kEventWindowClose, m_window));
      break;
    }
    default: break;
  }
}

// -----------------------------------------------------------------------------
// Input: minimal mapping. Touch -> left mouse button. Motion -> cursor move.
// -----------------------------------------------------------------------------
int32_t GHOST_SystemAndroid::onInputEvent(AInputEvent *event) {
  int32_t type = AInputEvent_getType(event);
  if (type == AINPUT_EVENT_TYPE_MOTION) {
    int32_t action = AMotionEvent_getAction(event);
    float x = AMotionEvent_getX(event, 0);
    float y = AMotionEvent_getY(event, 0);
    int32_t action_masked = action & AMOTION_EVENT_ACTION_MASK;

    if (action_masked == AMOTION_EVENT_ACTION_DOWN ||
        action_masked == AMOTION_EVENT_ACTION_POINTER_DOWN) {
      m_pointer_down = true;
      if (m_window) pushEvent(new GHOST_EventButton(
          getMilliSeconds(), GHOST_kEventButtonDown, m_window,
          GHOST_kButtonMaskLeft));
    } else if (action_masked == AMOTION_EVENT_ACTION_UP ||
               action_masked == AMOTION_EVENT_ACTION_POINTER_UP) {
      m_pointer_down = false;
      if (m_window) pushEvent(new GHOST_EventButton(
          getMilliSeconds(), GHOST_kEventButtonUp, m_window,
          GHOST_kButtonMaskLeft));
    } else if (action_masked == AMOTION_EVENT_ACTION_MOVE) {
      if (m_window) pushEvent(new GHOST_EventCursor(
          getMilliSeconds(), GHOST_kEventCursorMove, m_window,
          static_cast<int32_t>(x), static_cast<int32_t>(y)));
    }
    m_last_x = static_cast<int32_t>(x);
    m_last_y = static_cast<int32_t>(y);
    return 1;
  }
  if (type == AINPUT_EVENT_TYPE_KEY) {
    int32_t keycode = AKeyEvent_getKeyCode(event);
    int32_t action  = AKeyEvent_getAction(event);
    // Only forward BACK. Everything else stays in Java land for the future
    // add-on to handle (it may want volume keys for game logic).
    if (keycode == AKEYCODE_BACK && action == AKEY_EVENT_ACTION_DOWN) {
      if (m_window) pushEvent(new GHOST_EventKey(
          getMilliSeconds(), GHOST_kEventKeyDown, m_window,
          GHOST_kKeyEsc, false, nullptr));
      return 1;
    }
  }
  return 0;
}

// -----------------------------------------------------------------------------
// Event loop
// -----------------------------------------------------------------------------
bool GHOST_SystemAndroid::processEvents(bool waitForEvent) {
  // Read all pending events from the glue without blocking the GHOST loop.
  int ident = 0;
  int events = 0;
  android_poll_source *source = nullptr;
  while ((ident = ALooper_pollAll(
              waitForEvent ? -1 : 0, nullptr, &events,
              reinterpret_cast<void **>(&source))) >= 0) {
    if (source) source->process(m_app, source);
    if (m_app->destroyRequested != 0) return false;
  }
  // Dispatch into GHOST's own window manager / timer system.
  dispatchEvents();
  return true;
}

void GHOST_SystemAndroid::pushEvent(GHOST_Event *e) {
  m_eventManager->pushEvent(e);
}

GHOST_TSuccess GHOST_SystemAndroid::getCursorPosition(int32_t &x, int32_t &y) const {
  x = m_last_x; y = m_last_y; return GHOST_kSuccess;
}
