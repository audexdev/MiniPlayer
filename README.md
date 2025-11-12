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

## 🖼 Preview

| Floating UI | Playback Controls | Progress Slider |
|---|---|---|
| ![preview1](https://placehold.co/300x200) | ![preview2](https://placehold.co/300x200) | ![preview3](https://placehold.co/300x200) |

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

## 🛠 Build from source

```sh
git clone https://github.com/YOUR_USERNAME/MiniPlayer.git
cd MiniPlayer
open MiniPlayer.xcodeproj