// SPDX-License-Identifier: GPL-3.0-or-later
// intern/ghost/intern/GHOST_WindowAndroid.cc

#include "GHOST_WindowAndroid.hh"
#include "GHOST_SystemAndroid.hh"

GHOST_WindowAndroid::GHOST_WindowAndroid(
    GHOST_SystemAndroid *system,
    const char * /*title*/,
    int32_t left, int32_t top,
    uint32_t width, uint32_t height,
    GHOST_TWindowState /*state*/,
    const GHOST_ContextSettings & /*ctxSettings*/)
    : GHOST_Window(width, height, state, false),
      m_system(system),
      m_left(left), m_top(top),
      m_width(width), m_height(height) {
  // The ANativeWindow arrives later via setNativeWindow(), called from
  // GHOST_AndroidMain when the host fires onNativeWindowCreated.
}

GHOST_WindowAndroid::~GHOST_WindowAndroid() {
  if (m_window) {
    ANativeWindow_release(m_window);
    m_window = nullptr;
  }
}

void GHOST_WindowAndroid::setNativeWindow(ANativeWindow *win) {
  if (m_window == win) return;
  if (m_window) ANativeWindow_release(m_window);
  m_window = win;
  if (m_window) ANativeWindow_acquire(m_window);
  // The width/height come from the window itself, not the constructor args.
  if (m_window) {
    m_width  = static_cast<uint32_t>(ANativeWindow_getWidth(m_window));
    m_height = static_cast<uint32_t>(ANativeWindow_getHeight(m_window));
  }
  // Push a resize event so the GPU module picks up the new extents.
  m_system->pushEvent(new GHOST_Event(
      m_system->getMilliSeconds(), GHOST_kEventWindowSize, this));
}

void GHOST_WindowAndroid::getWindowBounds(GHOST_Rect &bounds) const {
  bounds.m_l = m_left; bounds.m_r = m_left + static_cast<int32_t>(m_width);
  bounds.m_t = m_top;  bounds.m_b = m_top + static_cast<int32_t>(m_height);
}

void GHOST_WindowAndroid::getClientBounds(GHOST_Rect &bounds) const {
  // On Android the client == the window (no decorations).
  bounds.m_l = 0; bounds.m_r = static_cast<int32_t>(m_width);
  bounds.m_t = 0; bounds.m_b = static_cast<int32_t>(m_height);
}
