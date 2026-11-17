// SPDX-License-Identifier: GPL-3.0-or-later
// source/gameengine/blenderplayer/android_main_wrapper.cc
//
// Wraps the player's traditional `int main(int argc, char** argv)` into the
// Android native app glue shape (`android_main(struct android_app*)`).
//
// On Android, "argv" is synthesized from blender_args.txt under the app's
// internal files dir (see GHOST_AndroidMain.cc — same convention Wanderson
// uses). The .blend path is added as the last positional argument by the
// future add-on when it installs a player bundle alongside a game.
//
// The wrapper spawns a thread that calls the original main(), so the GHOST
// event loop in android_main stays responsive to lifecycle commands.

#include <android/native_app_glue/android_native_app_glue.h>
#include <android/asset_manager.h>
#include <android/log.h>
#include <pthread.h>
#include <vector>
#include <string>
#include <cstring>
#include <fstream>
#include <unistd.h>

#define LOG_TAG "upbge_player_wrap"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Forward decl: the original main() of the blenderplayer, in
// source/gameengine/blenderplayer/main.cc. Renamed to player_main() by the
// entry-point patch.
extern "C" int player_main(int argc, char **argv);

struct PlayerArgs {
  std::vector<std::string> args;
  std::vector<char*> argv_storage;
};

// Reads blender_args.txt from the app's internal files dir. Each line is one arg.
static std::vector<std::string> read_args_file(struct android_app *app) {
  std::vector<std::string> out;
  // First the internal files dir
  std::string internal = app->activity->internalDataPath;
  std::ifstream f(internal + "/blender_args.txt");
  if (f.is_open()) {
    std::string line;
    while (std::getline(f, line)) {
      if (!line.empty()) out.push_back(line);
    }
  }
  // Default: -w (windowed), no -g (game engine flag, since UPBGE's player
  // already enables the game engine by default).
  if (out.empty()) {
    out = {"-w"};
  }
  return out;
}

static void *player_thread(void *p) {
  PlayerArgs *pa = static_cast<PlayerArgs*>(p);
  // Build a fake argv with argv[0] = "blenderplayer"
  pa->argv_storage.clear();
  pa->argv_storage.push_back(const_cast<char*>("blenderplayer"));
  for (auto &s : pa->args) pa->argv_storage.push_back(const_cast<char*>(s.c_str()));
  pa->argv_storage.push_back(nullptr);
  int argc = static_cast<int>(pa->argv_storage.size() - 1);
  char **argv = pa->argv_storage.data();
  LOGI("player_main: argc=%d argv[1]=%s", argc,
       argc > 1 ? argv[1] : "(none)");
  int rc = player_main(argc, argv);
  LOGI("player_main: rc=%d", rc);
  delete pa;
  return nullptr;
}

// Declared in GHOST_AndroidMain.cc — we call it from here instead of linking
// to the glue's own trampoline.
extern "C" void ghost_android_main(struct android_app *app);

extern "C" void android_main(struct android_app *state) {
  // Hand off to GHOST which sets up the system and waits.
  // Then spawn the player thread with the synthesized argv.
  PlayerArgs *pa = new PlayerArgs();
  pa->args = read_args_file(state);
  pthread_t tid;
  pthread_create(&tid, nullptr, player_thread, pa);
  pthread_detach(tid);
  // Now run the GHOST loop (does not return until destroyRequested).
  ghost_android_main(state);
}
