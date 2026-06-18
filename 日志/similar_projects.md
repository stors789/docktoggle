# DockToggle 类似项目调研

## DockToggle 核心功能回顾

[DockToggle](file:///Users/eros/Documents/DockToggle) 的核心功能是：**点击 Dock 中已在前台的 App 图标时，执行隐藏（Hide）或最小化（Minimize）操作**，将 Dock 变成一个"开关"。技术上通过 `CGEvent` 事件拦截实现，是一个轻量级的 Dock 行为增强工具。

---

## 🔥 高度相似的项目

### 1. Click2Minimize
| 项目 | 详情 |
|---|---|
| **官网** | [click2minimize.com](https://click2minimize.com) |
| **类型** | 闭源商业软件 |
| **平台** | macOS |
| **核心功能** | 点击 Dock 图标最小化/隐藏窗口（与 DockToggle 最接近） |

**功能对比：**
- ✅ Dock 点击最小化 — 与 DockToggle 的核心功能**几乎完全相同**
- ✅ 支持鼠标/触控板手势进行窗口管理（最小化、最大化、窗口吸附）
- ✅ 垂直 App 切换器
- ✅ Dock 锁定功能
- ❌ **不开源**，无法在 GitHub 上查看源码

> [!IMPORTANT]
> Click2Minimize 是功能上**最接近 DockToggle** 的项目，但它是闭源付费软件。DockToggle 的开源免费特性是其最大差异化优势。

---

### 2. Click2Hide
| 项目 | 详情 |
|---|---|
| **类型** | 闭源工具 |
| **平台** | macOS |
| **核心功能** | 点击 Dock 图标隐藏应用 |

功能上专注于"点击隐藏"，比 Click2Minimize 更轻量，与 DockToggle 的 Hide 模式高度重合。

---

## 🟢 功能重叠的开源项目

### 3. DockDoor
| 项目 | 详情 |
|---|---|
| **GitHub** | [github.com/ejbills/DockDoor](https://github.com/ejbills/DockDoor) |
| **类型** | 开源免费 (有 Pro 版本) |
| **Stars** | 非常活跃，社区认可度高 |
| **核心功能** | Dock 窗口预览 + 窗口管理 |

**功能对比：**
- ✅ 悬停 Dock 图标时显示实时窗口预览（类似 Windows 任务栏）
- ✅ 设置中有 **"Hide all app windows on dock icon click"** 选项 — 可部分实现 DockToggle 的功能
- ✅ Alt+Tab / Cmd+Tab 增强窗口切换
- ✅ 从预览窗口直接关闭/最小化/最大化窗口
- ✅ **开源**，Swift 编写
- ❌ 功能更重，不如 DockToggle 轻量聚焦

> [!TIP]
> DockDoor 是目前最活跃的开源 Dock 增强工具，虽然定位不同（侧重窗口预览），但它的 "hide on click" 设置与 DockToggle 的 Hide 模式功能重叠。

---

### 4. DockAutoHide
| 项目 | 详情 |
|---|---|
| **GitHub** | [github.com/nshcr/DockAutoHide](https://github.com/nshcr/DockAutoHide) |
| **类型** | 开源免费 |
| **核心功能** | 智能隐藏/显示 Dock |

- ✅ 当窗口覆盖 Dock 时自动隐藏 Dock，空间空闲时恢复
- ❌ 不涉及点击行为修改，与 DockToggle 的功能不同
- 💡 但属于同一类"Dock 行为增强"工具

---

## 🟡 相关但定位不同的工具

### 5. BetterTouchTool (BTT)
| 项目 | 详情 |
|---|---|
| **官网** | [folivora.ai](https://folivora.ai) |
| **类型** | 闭源商业软件（有试用） |
| **核心功能** | 全能自动化 + 手势工具 |

- ✅ 可通过自定义触发器实现 Dock 图标点击最小化（需配置 AppleScript）
- ✅ 社区有现成的 "Windows-style Dock" 预设
- ✅ 功能极其强大，几乎能自定义 macOS 的一切
- ❌ 不开源，付费
- ❌ 过于庞大，DockToggle 更轻量专注

### 6. HyperDock（已停更）
| 项目 | 详情 |
|---|---|
| **官网** | [bahoom.com](https://bahoom.com) |
| **类型** | 闭源商业软件 |
| **状态** | ⚠️ 自 2018 年停更，现代 macOS 兼容性差 |

- ✅ 悬停 Dock 图标显示窗口预览
- ✅ 点击预览缩略图聚焦/恢复窗口
- ❌ 不再维护，Apple Silicon 兼容性差
- 💡 DockToggle [README](file:///Users/eros/Documents/DockToggle/README.md) 中也提到了它作为同类参考

### 7. DockView
| 项目 | 详情 |
|---|---|
| **官网** | [noteifyapp.com/dockview](https://noteifyapp.com/dockview/) |
| **类型** | 闭源付费 |
| **核心功能** | HyperDock 的现代替代品，窗口预览 |

### 8. DockMate
| 项目 | 详情 |
|---|---|
| **官网** | [macenhance.com/dockmate](https://www.macenhance.com/dockmate) |
| **类型** | 闭源付费 |
| **核心功能** | Dock 增强，窗口预览和管理 |

---

## 🔵 更广泛的窗口管理生态

这些工具虽然不直接修改 Dock 点击行为，但属于同一个 macOS 窗口管理生态：

| 工具 | 类型 | 功能 |
|---|---|---|
| [Rectangle](https://github.com/rxhanson/Rectangle) | 开源免费 | 窗口吸附/分屏管理 |
| [Yabai](https://github.com/koekeishiya/yabai) | 开源免费 | 平铺式窗口管理器 |
| [Amethyst](https://github.com/ianyh/Amethyst) | 开源免费 | 自动平铺窗口管理器 |
| [AlwaysOnTop](https://github.com/itsabhishekolkha/AlwaysOnTop) | 开源免费 | 窗口置顶 |
| [uBar](https://brawersoftware.com/products/ubar) | 闭源付费 | 完整 Dock 替代品（类 Windows 任务栏） |

---

## 📊 竞品对比总结

| 项目 | 开源 | 免费 | 点击隐藏 | 点击最小化 | 窗口预览 | 轻量 | 活跃维护 |
|---|---|---|---|---|---|---|---|
| **DockToggle** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Click2Minimize | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Click2Hide | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ？ |
| DockDoor | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| BetterTouchTool | ❌ | ❌ | ✅* | ✅* | ❌ | ❌ | ✅ |
| HyperDock | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |

> `*` 需自行配置

---

## 💡 DockToggle 的差异化优势

1. **开源 + 免费** — Click2Minimize 是最接近的竞品，但它是闭源付费的
2. **极致轻量** — 纯 Swift 编译，无第三方依赖，不像 DockDoor 那样功能臃肿
3. **专注单一功能** — 只做"点击切换"，代码清晰，用户无需学习复杂配置
4. **双模式切换** — 同时支持 Hide 和 Minimize 两种模式
5. **macOS 原生技术栈** — CGEvent tap + Accessibility API，完全使用系统级 API
