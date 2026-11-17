// SPDX-License-Identifier: GPL-3.0-or-later
// intern/ghost/intern/GHOST_WindowAndroid.hh
//
// Minimal Android window backed by an ANativeWindow. Vulkan-only: there is no
// EGL/GLES surface here. The window receives resize/focus events from
// GHOST_SystemAndroid and forwards ANativeWindow to the GPU module when a
// VkSurfaceKHR is requested.
//
// This is the minimum needed to boot a blenderplayer .blend on Android.

#pragma once

#include "GHOST_Window.hh"
#include <android/native_window.h>

class GHOST_SystemAndroid;

class GHOST_WindowAndroid : public GHOST_Window {
 public:
  GHOST_WindowAndroid(GHOST_SystemAndroid *system,
                      const char *title,
                      int32_t left, int32_t top,
                      uint32_t width, uint32_t height,
                      GHOST_TWindowState state,
                      const GHOST_ContextSettings &ctxSettings);

  ~GHOST_WindowAndroid() override;

  // Called by GHOST_SystemAndroid when the host hands us a new ANativeWindow
  // (on surfaceCreated) or takes it away (on surfaceDestroyed).
  void setNativeWindow(ANativeWindow *win);
  ANativeWindow *getNativeWindow() const { return m_window; }

  // GHOST_Window interface
  void setTitle(const char *title) override {}
  void getTitle(char *title) const override { strcpy(title, "UPBGE"); }
  void getWindowBounds(GHOST_Rect &bounds) const override;
  void getClientBounds(GHOST_Rect &bounds) const override;
  bool setWindowCursorGrab(GHOST_TGrabCursorMode /*mode*/) override { return false; }
  bool setWindowCursorShape(GHOST_TStandardCursor /*shape*/) override { return true; }
  bool setWindowCustomCursorShape(uint8_t * /*bitmap*/, uint8_t * /*mask*/,
                                  int /*sizex*/, int /*sizey*/,
                                  int /*hotx*/, int /*hoty*/,
                                  bool /*canInvertColor*/) override { return true; }
  bool setWindowCursorVisibility(bool /*visible*/) override { return true; }
  GHOST_TSuccess setWindowCursorPosY(int /*y*/) override { return GHOST_kSuccess; }
  GHOST_TSuccess setWindowCursorPosX(int /*x*/) override { return GHOST_kSuccess; }
  void setCursorColorMask(uint8_t /*mask*/, const uint8_t (* /*colors*/)[3],
                          bool /*useCustomColor*/, const uint8_t (* /*usercolors*/)[3]) override {}

  // Drawing context: we only support Vulkan on Android.
  GHOST_TSuccess swapBuffers() override { return GHOST_kSuccess; }
  GHOST_TSuccess activateDrawingContext() override { return GHOST_kSuccess; }
  GHOST_TSuccess releaseDrawingContext() override { return GHOST_kSuccess; }
  GHOST_Context *getContext() override { return nullptr; }

 protected:
  void invalidate() override {}

 private:
  GHOST_SystemAndroid *m_system;
  ANativeWindow *m_window = nullptr;
  int32_t m_left = 0, m_top = 0;
  uint32_t m_width = 0, m_height = 0;
};
