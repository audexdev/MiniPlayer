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

| Playing | Not Playing |
|---|---|
| ![preview1](https://private-user-images.githubusercontent.com/219630637/513310469-b0d893c3-150e-49b2-8f44-5477a20eaec0.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NjI5NTE5OTAsIm5iZiI6MTc2Mjk1MTY5MCwicGF0aCI6Ii8yMTk2MzA2MzcvNTEzMzEwNDY5LWIwZDg5M2MzLTE1MGUtNDliMi04ZjQ0LTU0NzdhMjBlYWVjMC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUxMTEyJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MTExMlQxMjQ4MTBaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1kYmJmYjdhN2M0NjY5MjFlYmJhZjRiNjdiZWY3MGI3NWVhMWU0NDg5YjhiOTI2MWViNzEzM2U4YTAxYWQ1MzZmJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.W-Wxz4DNUjgVa9Os0gg-JXz1l_IAtvCvYPV10zzOAo4) | ![preview2](https://private-user-images.githubusercontent.com/219630637/513310630-07eadc62-d9fb-4faa-a4ac-ca3ecd17ad56.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NjI5NTE5OTAsIm5iZiI6MTc2Mjk1MTY5MCwicGF0aCI6Ii8yMTk2MzA2MzcvNTEzMzEwNjMwLTA3ZWFkYzYyLWQ5ZmItNGZhYS1hNGFjLWNhM2VjZDE3YWQ1Ni5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUxMTEyJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MTExMlQxMjQ4MTBaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT00MDk2Mzc2YTFhNDUxMGU2OTMzNGU4OThjNjJkOWRkNjEyNWY4ZjEzODQ2ZmZlMmQ0NjQ4YjUzN2Y1MTJmZDM0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.a6HvZf2HZmOPQbuvjBXkxBwMx9eRN2kM1D4tmPgnarA) |

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