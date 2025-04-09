# FruitXR

![](https://files.rinsuki.net/2025/fruitxr-top.png)

very Work-in-Progress PoC of the OpenXR Runtime for macOS.

DISCLAIMER: This runtime is NOT OpenXR conformant.

at this time, only you can do is see Swapchain, so you probably don't want to run this, for now.

## Features (already implemented)

* Swapchain の内容のウインドウでの確認
* x86_64 プロセスで動く (w/ Rosetta 2)
  * FruitXR以前に公開されていたmacOS向けOpenXRランタイムはMetaの XR Simulator しかなく、これは arm64 バイナリしか用意されていなかったので、これまでOpenXRをx86_64のプロセスから使うことは不可能でした。
  * 実際の Intel Mac ではテストしていませんが、当時の性能を考えると、あまり使いたい人はいないでしょう (Mac Pro (2020) を持っているなら別かもしれませんが)。
  * 注: macOS版UnityのOpenXR実装はx86_64では壊れているため (XrSessionCreateInfo#next を NULL のまま初期化しようとする)、Unity側の今後のアップデートなしでは動作できません。
    * ほぼ全ての x86_64 macOS 用のビルドがあるゲームは x86_64 Windows 用のビルドか arm64 Windows 用のビルドがあるはずなので、arm64ビルドを使うか、誰かが wineopenxr を Proton から移植すれば動くはずです。

## How to Run

* Open ./FruitXR.xcodeproj
* Run
  * (WARNING: current OpenXR runtime (`/usr/local/share/openxr/1/active_runtime.json`) will be overwritten without consent for now)

## Questions

### Q. Why not port the Monado https://monado.dev/ for macOS instead?

A.

* I don't want to mess around with C++ codebases if there are other way to do that
* I think it would be good to avoid MoltenVK as long as application isn't requires it
  * (Monado's compositor uses Vulkan AFAIK)
* I don't have a idea to how adopt macOS IPC/shared textures way to Monado's codebase

## LICENSE

TBD