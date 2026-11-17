// SPDX-License-Identifier: GPL-3.0-or-later
// intern/ghost/intern/GHOST_SystemAndroid.hh
//
// Minimal GHOST system for Android. Manages:
//   - the native app glue lifecycle (app entry, surface, pause/resume/destroy)
//   - one GHOST_WindowAndroid (the player is single-window on phones)
//   - input events from the glue: touches → GHOST_ButtonEvent,
//     motion → GHOST_EventCursor. No multi-touch, no stylus.
//
// All the touch/keyboard/stylus sophistication from Wanderson's fork is
// intentionally absent: this backend exists to BOOT a .blend, not to make
// the editor usable on a touchscreen.

#pragma once

#include "GHOST_System.hh"
#include "GHOST_WindowAndroid.hh"

struct android_app;

class GHOST_SystemAndroid : public GHOST_System {
 public:
  GHOST_SystemAndroid();
  ~GHOST_SystemAndroid() override;

  // Called by GHOST_AndroidMain once per process start, with the
  // android_app pointer the glue handed us.
  void setAndroidApp(android_app *app) { m_app = app; }

  // Hooks the glue calls into. They push GHOST events into the queue.
  void onNativeWindowCreated(ANativeWindow *win);
  void onNativeWindowDestroyed();
  void onAppCmd(int32_t cmd);
  int32_t onInputEvent(AInputEvent *event);

  // GHOST_System interface
  GHOST_TSuccess init() override;
  GHOST_TSuccess exit() override;
  bool processEvents(bool waitForEvent) override;
  int setConsoleWindowState(GHOST_TConsoleWindowState /*action*/) override { return 0; }
  GHOST_TSuccess setModifierKeyStateForEvent(
      GHOST_TKey /*key*/, bool /*isDown*/) override { return GHOST_kFailure; }
  bool setConsoleWindowStateForEvent(GHOST_TConsoleWindowState /*state*/) override { return false; }

  GHOST_TSuccess getMilliSecondsSinceStart(GHOST_TUns64 &ms) const {
    ms = getMilliSeconds(); return GHOST_kSuccess;
  }

  GHOST_TUns64 getMilliSeconds() const override;

  GHOST_TSuccess getCursorPosition(int32_t &x, int32_t &y) const override;
  GHOST_TSuccess setCursorPosition(int /*x*/, int /*y*/) override { return GHOST_kFailure; }
  GHOST_TSuccess getModifierKeys(GHOST_ModifierKeys & /*keys*/) const override { return GHOST_kSuccess; }
  GHOST_TSuccess getButtons(GHOST_Buttons & /*buttons*/) const override { return GHOST_kSuccess; }
  GHOST_TSuccess getCursorPositionClientRelative(int32_t & /*x*/, int32_t &y) const override { y = 0; return GHOST_kSuccess; }

  GHOST_TSuccess initDND() override { return GHOST_kSuccess; }
  void exitDND() override {}

  GHOST_TSuccess setMultitouchGesturesWin32(bool /*enable*/) override { return GHOST_kFailure; }

  // Convenience for GHOST_WindowAndroid.
  void pushEvent(GHOST_Event *e);

 private:
  android_app *m_app = nullptr;
  GHOST_WindowAndroid *m_window = nullptr;
  GHOST_TUns64 m_start_ms = 0;
  int32_t m_last_x = 0, m_last_y = 0;
  bool m_pointer_down = false;
};
