# MiniPlayer for Music 🎵

A lightweight, minimal floating Mini Player for **macOS Music.app**, built with Swift + ScriptingBridge.

> No Electron, No heavy frameworks — just a small native music controller that stays on top.

---

## ✨ Features

- 🎧 Displays **current track, artist, and album art**
- ▶️ Playback controls: play/pause, next, previous
- 🔀 Shuffle & 🔁 Repeat (All / One / Off)
- 🕒 Progress bar with seek support
- 🖼 Fetches album art via iTunes Search API
- 📌 **Always-on-top floating window**
- 🎹 Spacebar to toggle Play/Pause when window is focused
- 🧊 Clean minimal UI

---

## ⚠️ Important

This app controls **Music.app via ScriptingBridge**, which **does not work in macOS Sandbox mode**.

> ✅ Run build with **App Sandbox OFF**  
> ❌ Will not work as a sandboxed App Store app  
> ✅ Perfect for local use or GitHub distribution

---

## 🚀 Usage

1. Launch MiniPlayer
2. Play a song in the **Music** app
3. Control playback from MiniPlayer window
4. Click window → Press **Space** to toggle play/pause

---

## Dependencies

This project uses the following Swift packages:

- [Sweep](https://github.com/JohnSundell/Sweep) — Simple string scanning utilities
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio) - A framework that makes CoreAudio easier to use.