# DockToggle 深度评估研究报告

> 基于源码分析、DockDoor 开源项目研究、Click2Minimize 用户反馈调研的综合评估

---

## 一、从相似项目可学习的地方

### 1.1 从 DockDoor 学习

DockDoor 是目前最活跃的开源 Dock 增强工具（Swift 编写），以下设计值得借鉴：

#### 🔑 事件驱动架构 vs 轮询架构

| 方面 | DockDoor 做法 | DockToggle 现状 | 建议 |
|---|---|---|---|
| Dock 交互检测 | 使用 `NSEvent.addGlobalMonitorForEvents` 监听鼠标移动，仅在鼠标进入 Dock 区域时激活 | 使用 `CGEvent` tap 拦截所有左键点击 | DockToggle 的 CGEvent tap 更适合其"吞掉点击"的需求，**保持现有方案** |
| Dock 信息刷新 | **事件驱动**：仅在鼠标悬停到 Dock 时才查询 AX API | **定时轮询**：每 1 秒刷新一次图标缓存 | ⚠️ **应改为事件驱动** |
| 窗口状态追踪 | 使用 `AXObserver` 监听窗口变化通知 | 使用 `NSWorkspace` 通知 + 定时轮询 | 可借鉴 AXObserver 模式 |

#### 🔑 智能缓存策略

DockDoor 的缓存设计：
- **按需刷新**：只有在用户交互时才查询 Accessibility 数据
- **短时缓存**：缓存窗口预览 150ms，避免频繁截屏
- **失效策略**：窗口列表变化时自动使缓存失效

**DockToggle 可借鉴**：将 1 秒轮询改为"鼠标进入 Dock 区域时刷新"，大幅降低空闲功耗。

#### 🔑 多显示器处理

DockDoor 的做法：
- 检测所有 `NSScreen` 并确定 Dock 所在的显示器
- 监听 `NSApplication.didChangeScreenParametersNotification` 响应显示器变化
- 针对每个显示器分别处理坐标映射

**DockToggle 现状**：仅使用 `NSScreen.main`，在外接显示器场景下可能出错。

#### 🔑 Stage Manager 适配

DockDoor 已实现：
- 检测 Stage Manager 是否启用（通过读取 `com.apple.WindowManager` 的 defaults）
- 在 Stage Manager 模式下调整窗口预览的布局和行为

---

### 1.2 从 Click2Minimize 用户反馈学习

Click2Minimize 用户在论坛上报告的常见问题（**DockToggle 需要规避**）：

| 用户痛点 | 出现频率 | DockToggle 是否存在 |
|---|---|---|
| 与 Dock 自动隐藏模式冲突 | 高 | ⚠️ 未处理 |
| Stage Manager 下行为异常 | 高 | ⚠️ 未处理 |
| 多显示器时判断错误 | 中 | ⚠️ 仅检测 main screen |
| 全屏应用下误触发 | 中 | ⚠️ 未过滤 |
| 部分应用图标无法识别 | 中 | ✅ 已有 5 种 PID 提取策略 |
| 电量/CPU 影响 | 低-中 | ⚠️ 1 秒定时器有开销 |
| 权限丢失后无法恢复 | 低 | ✅ 有权限轮询恢复 |

#### 用户最希望有的功能
1. **应用排除列表** — 某些 App 不需要 toggle 行为（如 Finder、Terminal）
2. **修饰键支持** — Option+Click 才触发（避免误触）
3. **自定义动画/反馈** — 提供视觉/声音确认操作已执行

---

### 1.3 从 BetterTouchTool 方案学习

BTT 社区实现 Dock toggle 的常用 AppleScript 模式：

```applescript
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    if frontApp is equal to targetApp then
        set visible of process frontApp to false  -- hide
    end if
end tell
```

**启发**：
- BTT 用户报告的一个关键 edge case：**当应用只有"无标题"窗口时**（如某些 Electron 应用的弹窗），`AXFocusedWindow` 返回这些窗口而非主窗口
- BTT 用 `delay 0.1` 来等待 Dock 动画完成后再执行操作 — 这与 DockToggle 的 400ms debounce 思路类似

---

## 二、功耗优化方案

### 2.1 功耗热点分析

通过对 [DockToggleApp.swift](file:///Users/eros/Documents/DockToggle/Sources/DockToggleApp.swift) 和引擎模块的分析，识别出以下功耗热点：

| # | 热点 | 源文件 | 影响 | 严重程度 |
|---|---|---|---|---|
| 1 | **1 秒定时器持续刷新缓存** | [DockToggleApp.swift#L81-L87](file:///Users/eros/Documents/DockToggle/Sources/DockToggleApp.swift#L81-L87) | 每秒遍历 AX 树 + 所有 Dock 图标 | 🔴 高 |
| 2 | **2 秒权限检查定时器** | [DockToggleApp.swift#L130-L153](file:///Users/eros/Documents/DockToggle/Sources/DockToggleApp.swift#L130-L153) | 每 2 秒调用 `AXIsProcessTrusted()` + `CGPreflightListenEventAccess()` | 🟡 中 |
| 3 | **每次刷新遍历所有运行中 App** | [DockIconCache.swift#L198-L239](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockIconCache.swift#L198-L239) | `NSWorkspace.shared.runningApplications` 多次线性扫描 | 🟡 中 |
| 4 | **Thread.sleep 阻塞线程** | [ActionExecutor.swift#L134](file:///Users/eros/Documents/DockToggle/Sources/Engine/ActionExecutor.swift#L134)、[DockInspector.swift#L38](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockInspector.swift#L38) | 阻塞 utility 线程 | 🟢 低 |
| 5 | **CGEvent tap 在主 RunLoop** | [EventTapEngine.swift#L50](file:///Users/eros/Documents/DockToggle/Sources/Engine/EventTapEngine.swift#L50) | 独立线程 RunLoop，本身高效 | ✅ 已优化 |
| 6 | **DebugLog 频繁文件 IO** | [DebugLog.swift#L27-L33](file:///Users/eros/Documents/DockToggle/Sources/DebugLog.swift#L27-L33) | 每次事件都写入磁盘 | 🟡 中 |

### 2.2 具体优化方案

#### 🔴 优化 #1：将 1 秒轮询改为事件驱动（预计降低 80% 空闲 CPU）

**当前问题**：
```swift
// DockToggleApp.swift L81-87
cacheRefreshTimer = Timer.scheduledTimer(
    withTimeInterval: 1.0,  // ← 每秒执行！
    repeats: true
) { _ in
    DockInspector.shared.refreshFrame()  // 读取 AX API
    DockIconCache.shared.refresh()       // 遍历整个 Dock AX 树
}
```

**优化方案**：改为 3 层触发机制：

```
Layer 1: NSWorkspace 通知（应用启动/退出/激活）→ 标记缓存失效
Layer 2: 鼠标进入 Dock 区域时 → 按需刷新
Layer 3: 保留低频定时器（30 秒或更长）作为兜底
```

具体做法：
- 监听 `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` 标记缓存需要刷新
- 在 `EventTapEngine.handleEvent` 中，当检测到点击在 Dock 区域且缓存已失效时，才触发 `DockIconCache.refresh()`
- 将定时器间隔从 1 秒改为 30 秒（仅作为兜底）

#### 🟡 优化 #2：权限检查降频 + 条件轮询

**当前**：每 2 秒检查权限（即使已经全部授予）

**优化**：
- 权限全部授予后，将轮询间隔提升到 30 秒（仅用于检测权限被撤销的罕见情况）
- 权限未授予时，保持 2 秒轮询
- Event Tap 意外禁用时，立即切回快速轮询

#### 🟡 优化 #3：缓存 runningApplications 查询结果

**当前**：`extractPID` 中多次调用 `NSWorkspace.shared.runningApplications`（Strategy A-E），每次都是完整扫描。

**优化**：在 `performRefresh()` 开始时一次性获取快照：
```swift
let apps = NSWorkspace.shared.runningApplications
let appsByBundleID = Dictionary(grouping: apps, by: { $0.bundleIdentifier })
let appsByName = Dictionary(grouping: apps, by: { $0.localizedName })
```
然后在各 Strategy 中使用字典查找（O(1)）代替线性扫描（O(n)）。

#### 🟡 优化 #4：DebugLog 批量写入

**当前**：每条日志立即写入磁盘（`fh.write(data)`）。

**优化**：
- 内存中累积日志，每 5 秒或 50 条批量 flush
- Release 构建中降低日志级别，减少大量 `[CACHE]` 日志
- 或使用 `os_log` 替代文件日志（系统日志更高效，且支持 Console.app 过滤）

#### 🟢 优化 #5：替换 Thread.sleep

[ActionExecutor.swift#L134](file:///Users/eros/Documents/DockToggle/Sources/Engine/ActionExecutor.swift#L134) 中的 `Thread.sleep(forTimeInterval: 0.1)` 会阻塞调度线程。改用 `DispatchQueue.asyncAfter` 或 async/await。

---

## 三、Bug 预防与健壮性改进

### 3.1 已识别的潜在 Bug

#### 🔴 Bug 1：Force Unwrap 崩溃风险

[DockIconCache.swift#L171](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockIconCache.swift#L171) 和 [DockInspector.swift#L118](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockInspector.swift#L118)：
```swift
let axValue = value as! AXValue?  // ← force cast!
```
如果 `value` 不是 `AXValue` 类型（某些 App 返回异常 AX 数据），会直接崩溃。

**修复**：改用 `as?` 可选转换：
```swift
guard let axValue = value as? AXValue, ... else { return nil }
```

同样的问题也出现在 [ActionExecutor.swift#L84](file:///Users/eros/Documents/DockToggle/Sources/Engine/ActionExecutor.swift#L84)：
```swift
let windowElement = window as! AXUIElement?  // ← force cast!
```

#### 🔴 Bug 2：Event Tap 被系统禁用后无自动恢复

macOS 会在某些情况下自动禁用 Event Tap（如系统安全策略更新、锁屏后恢复），当前代码只在 `monitorTimer` 中检测到禁用后尝试重启，但 [startEngine()](file:///Users/eros/Documents/DockToggle/Sources/DockToggleApp.swift#L37) 并未考虑旧的 EventTap 线程可能仍在运行。

**建议**：
- 添加 `CGEventTapEnable` 的回调监控（tap 禁用时 type 为 `.tapDisabledByTimeout` 或 `.tapDisabledByUserInput`）
- 在 [handleEvent](file:///Users/eros/Documents/DockToggle/Sources/Engine/EventTapEngine.swift#L78) 中处理这些事件类型
- 实现指数退避重试

#### 🟡 Bug 3：竞态条件 — shouldSwallowNextMouseUp

[EventTapEngine.swift#L13](file:///Users/eros/Documents/DockToggle/Sources/Engine/EventTapEngine.swift#L13)：
```swift
private var shouldSwallowNextMouseUp = false
```
这个标志在 event tap 回调线程上设置和读取。虽然 event tap 通常是串行的，但如果系统以某种方式重入（极端情况下），可能导致遗漏 mouseUp 事件，让 Dock 进入不可点击状态。

**建议**：使用 `OSAllocatedUnfairLock` 保护（与 FrontmostTracker 一致）。

#### 🟡 Bug 4：Dock 自动隐藏模式

当 Dock 设置为自动隐藏时：
- `cachedGlobalDockFrame` 可能返回隐藏时的极小区域
- 用户点击 Dock 边缘唤出 Dock 后，缓存的 frame 可能与实际可见 frame 不匹配
- `DockInspector.isDockHidden()` 检查存在但未在 `EventTapEngine.handleEvent` 中使用

**建议**：在 handleEvent 中加入 Dock 隐藏检测：
```swift
guard !DockInspector.shared.isDockHidden() else {
    return Unmanaged.passUnretained(event)
}
```

#### 🟡 Bug 5：重复代码导致不一致

[DockInspector](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockInspector.swift) 和 [DockIconCache](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockIconCache.swift) 中的 PID 提取逻辑几乎完全相同（`extractPID`/`extractApp`，`pidByTitle`，`pidByTitleFuzzy` 等），但是独立维护。

TODO 中也提到了这个问题。当修复其中一个而忘记另一个时，会产生不一致 Bug。

### 3.2 健壮性改进清单

| 改进 | 影响 | 难度 |
|---|---|---|
| 替换所有 `as!` 为 `as?` 安全转换 | 防止崩溃 | 简单 |
| Event Tap 失效后自动重新创建 | 防止永久失效 | 中等 |
| 统一 PID 提取逻辑为独立模块 | 防止不一致 bug | 中等 |
| 添加 Dock 隐藏状态检测 | 防止误操作 | 简单 |
| 为 `shouldSwallowNextMouseUp` 添加超时清除 | 防止 mouseUp 永久丢失 | 简单 |
| 添加 Crashlytics 或 `NSSetUncaughtExceptionHandler` | 收集线上崩溃 | 中等 |

---

## 四、全场景适配方案

### 4.1 场景覆盖矩阵

| 场景 | 当前状态 | 风险 | 优化方案 |
|---|---|---|---|
| **底部 Dock** | ✅ 正常 | 低 | — |
| **左侧 Dock** | ⚠️ 未充分测试 | 中 | 需验证坐标映射 |
| **右侧 Dock** | ⚠️ 未充分测试 | 中 | 需验证坐标映射 |
| **Dock 自动隐藏** | ❌ 未处理 | 高 | 见下方详细方案 |
| **Dock 放大效果** | ⚠️ 未测试 | 高 | 放大改变图标 frame，缓存可能失效 |
| **Stage Manager** | ❌ 未处理 | 高 | 见下方详细方案 |
| **多 Space** | ⚠️ 部分处理 | 中 | frontmost 可能跨 Space |
| **全屏应用** | ❌ 未过滤 | 高 | 全屏时不应 toggle |
| **多显示器** | ❌ 仅检测主屏 | 高 | 见下方详细方案 |
| **Split View** | ⚠️ 未测试 | 中 | 分屏中的应用 minimize 行为特殊 |
| **Mission Control** | ⚠️ 未处理 | 低 | MC 激活时 Dock 行为不同 |
| **无窗口应用** | ⚠️ 部分处理 | 中 | 某些 menubar-only 应用 |
| **多进程应用** | ✅ 已处理 | 低 | bundleID + name 匹配 |
| **Electron 应用** | ⚠️ 未验证 | 中 | AX 元数据可能不完整 |

### 4.2 关键场景详细方案

#### 📌 Dock 自动隐藏

**问题**：Dock 自动隐藏时，`cachedGlobalDockFrame` 反映的是隐藏态的 frame（通常是屏幕边缘的 1px 触发区域）。当用户移动鼠标唤出 Dock 并点击时，缓存 frame 与实际 Dock frame 不匹配，导致：
- 点击被 `frame.contains(point)` 拒绝（漏判）
- 或缓存的图标位置已偏移（误判）

**方案**：
1. 监听 Dock auto-hide 状态变化：
   ```swift
   // 通过 defaults read com.apple.dock autohide
   let autoHide = UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "autohide") ?? false
   ```
2. 当 auto-hide 启用时，使用更宽松的 Dock 区域检测（扩展热区）
3. 在点击事件到达时**实时刷新** Dock frame（而非依赖缓存），因为自动隐藏 Dock 显现后 frame 会变化
4. 加入 `DockInspector.isDockHidden()` 检查 — 如果 Dock 正在隐藏中，放行所有点击

#### 📌 Stage Manager

**问题**：Stage Manager 改变了窗口组织方式，前台应用组（Set）与传统的单应用前台模型不同。

**方案**：
1. 检测 Stage Manager 是否启用：
   ```swift
   let stageManagerEnabled = UserDefaults(suiteName: "com.apple.WindowManager")?
       .bool(forKey: "GloballyEnabled") ?? false
   ```
2. Stage Manager 下，多个 App 可以在同一个"Set"中都处于可见状态。需要更精确地判断"真正的 frontmost"
3. 考虑：在 Stage Manager 下，隐藏一个应用可能改变当前 Set 的组成，导致意外行为。可考虑在 Stage Manager 下默认使用 Minimize 而非 Hide

#### 📌 全屏应用

**问题**：全屏应用下，Dock 通常不可见（需要鼠标移到底部才会浮现），此时对全屏应用执行 hide/minimize 会破坏全屏状态。

**方案**：
```swift
// 检查目标应用是否在全屏模式
func isAppFullscreen(pid: pid_t) -> Bool {
    let appElement = AXUIElementCreateApplication(pid)
    var window: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &window) == .success,
          let win = window as! AXUIElement? else { return false }
    
    var fullscreen: CFTypeRef?
    if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fullscreen) == .success,
       let isFS = fullscreen as? Bool {
        return isFS
    }
    return false
}
```
在 `handleEvent` 中加入全屏检查，全屏应用直接放行。

#### 📌 多显示器

**问题**：当前 [DockInspector.refreshFrame()](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockInspector.swift#L43) 的 Strategy 4 仅使用 `NSScreen.main`，但 Dock 始终显示在主显示器上（除非使用第三方工具）。

**方案**：
1. 确保 Dock frame 检测使用正确的显示器：
   ```swift
   // Dock 始终在包含 Dock 的屏幕上
   let dockScreen = NSScreen.screens.first { screen in
       let sf = screen.frame
       let vf = screen.visibleFrame
       // Dock 存在于 frame 与 visibleFrame 的差值区域
       return sf != vf
   } ?? NSScreen.main
   ```
2. 监听 `NSApplication.didChangeScreenParametersNotification`，显示器配置变化时刷新 Dock frame
3. 处理 macOS Sequoia 上的多 Dock 显示器（如果 Apple 未来支持）

#### 📌 Dock 放大效果 (Magnification)

**问题**：启用放大效果时，图标的实际 frame 会随鼠标位置动态变化，缓存的静态 frame 可能不准确。

**方案**：
- 放大不影响图标的**中心位置**，只影响大小。可以使用中心点 + 容差范围匹配，而非严格 `frame.contains(point)`
- 或：在鼠标点击发生时**实时查询**被点击位置的 AX 元素（而非依赖预缓存的 frame）。这就是 [DecisionEngine](file:///Users/eros/Documents/DockToggle/Sources/Engine/DecisionEngine.swift) 的 `AXUIElementCopyElementAtPosition` 方案 — 考虑将其作为 fallback 启用

---

## 五、优先级路线图

### Phase 1：稳定性 & 安全（1-2 天）
- [ ] 修复所有 `as!` force unwrap → `as?`
- [ ] 添加 Event Tap 自动恢复机制（处理 `.tapDisabledByTimeout`）
- [ ] 为 `shouldSwallowNextMouseUp` 添加 500ms 超时自动重置
- [ ] 统一 DockInspector / DockIconCache 的 PID 提取逻辑

### Phase 2：功耗优化（1-2 天）
- [ ] 将 1 秒轮询改为事件驱动 + 30 秒兜底
- [ ] 权限检查降频（授权后改为 30 秒）
- [ ] 缓存 `runningApplications` 快照，减少重复扫描
- [ ] DebugLog 批量写入 + Release 构建降级

### Phase 3：场景适配（2-3 天）
- [ ] Dock 自动隐藏模式支持
- [ ] 全屏应用过滤
- [ ] 多显示器正确检测
- [ ] Stage Manager 检测与适配
- [ ] Dock 放大效果兼容（DecisionEngine 作为 fallback）

### Phase 4：功能增强（1-2 天）
- [ ] 应用排除列表（用户可配置）
- [ ] 可选修饰键（Option+Click）
- [ ] 显示器配置变化自动响应
- [ ] 多 Space 切换时的 frontmost 校准

---

## 附录：关键文件参考

| 文件 | 核心职责 | 关注重点 |
|---|---|---|
| [EventTapEngine.swift](file:///Users/eros/Documents/DockToggle/Sources/Engine/EventTapEngine.swift) | CGEvent 拦截 | force unwrap、tap 恢复 |
| [DockIconCache.swift](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockIconCache.swift) | 图标位置缓存 | 刷新频率、PID 提取 |
| [DockInspector.swift](file:///Users/eros/Documents/DockToggle/Sources/Engine/DockInspector.swift) | Dock 区域检测 | 多屏/自动隐藏 |
| [ActionExecutor.swift](file:///Users/eros/Documents/DockToggle/Sources/Engine/ActionExecutor.swift) | 隐藏/最小化执行 | Thread.sleep、全屏 |
| [DockToggleApp.swift](file:///Users/eros/Documents/DockToggle/Sources/DockToggleApp.swift) | 应用生命周期 | 定时器管理 |
| [FrontmostTracker.swift](file:///Users/eros/Documents/DockToggle/Sources/Engine/FrontmostTracker.swift) | 前台应用追踪 | 线程安全 ✅ |
