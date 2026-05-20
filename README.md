# 🧠 LLMKit

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Metal Optimized](https://img.shields.io/badge/GPU-Metal%20Accelerated-blue.svg)](https://developer.apple.com/metal/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**The ultimate on-device AI framework for the Apple Ecosystem.**

LLMKit is a native Swift SDK designed to run GGUF models locally on iOS and macOS. Our mission is to democratize Privacy-First AI by abstracting away 100% of the underlying C++, pointer management, and Metal GPU memory allocation.

Build AI-powered, privacy-respecting applications in minutes, not weeks.

## 🌍 Ecosystem Impact (Why LLMKit?)
Historically, integrating local Large Language Models into Apple apps required deep knowledge of C++, CMake, complex asynchronous state management, and manual Metal API configuration. 

**LLMKit solves this.** We provide the foundational infrastructure for Apple developers to build the next generation of applications:
- **Zero C++:** A 100% declarative Swift API.
- **Privacy by Design:** Fully offline inference. No user data ever leaves the device.
- **Metal First:** Maximum hardware optimization using Apple Silicon GPUs.
- **Plug & Play UI:** Pre-built SwiftUI components for chat interfaces and model downloading.

## 📦 Installation (Swift Package Manager)

LLMKit is designed to be the structural AI dependency for your next app.

1. In Xcode, go to **File** > **Add Package Dependencies...**
2. Paste the repository URL: `https://github.com/GBRJ333/LLMKit.git`
3. Choose **Up to Next Major Version**.
4. Add the `LLMKit` and `LLMKitUI` targets to your app.

```swift
import LLMKit
import LLMKitUI

// You are now ready to run local AI!
```

## 🚀 Quick Start
Forget complex build settings. Here is how you run a local LLM using LLMKit's pre-built UI:

```swift
import SwiftUI
import LLMKitUI

struct ContentView: View {
    var body: some View {
        // A fully functional AI Chat interface in one line of code!
        LLMChatView()
    }
}
```
