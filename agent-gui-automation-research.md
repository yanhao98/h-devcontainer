# AI Agent 桌面 GUI 自动化调研

> 调研时间：2026-03-11

## 核心问题

AI Agent 如何精准控制桌面电脑？截图→坐标映射的精度问题怎么解决？

## 一、商业方案

### 1. Anthropic Computer Use（最成熟）

- **核心机制**：训练 Claude 的"像素计数"能力——从屏幕边缘或已知 UI 元素出发，精确计算鼠标需要移动的像素数
- **性能**：配合收购的 Vercept 视觉增强技术，Claude Sonnet 4.6 在 OSWorld 基准达 **72.5%**；Vercept UI 识别准确率 92%（ScreenSpot v1）
- **平台**：跨平台，通过 Anthropic API / Amazon Bedrock / Google Cloud Vertex AI 调用
- **建议分辨率**：不超过 XGA（1024×768）以优化速度和准确性
- **局限**：仍在 beta 阶段，滚动/拖拽/缩放等操作仍有挑战

### 2. OpenAI CUA / Operator

- **核心机制**：GPT-4o 视觉 + 强化学习训练，"感知→推理→行动"迭代循环
- **集成方式**：已整合到 ChatGPT 的 agent mode
- **侧重**：浏览器内操作为主，对原生桌面应用的直接控制能力较弱
- **安全**：敏感操作（登录、CAPTCHA）前主动寻求用户确认

### 3. 微软 UFO 系列（Windows 专享）

- **发展路线**：UFO（2024.02）→ UFO² 桌面 AgentOS（2025.04）→ UFO³ Galaxy 多设备编排（2025.11）
- **核心创新——混合 API 方案**：
  - 融合 Windows UI Automation (UIA)、Win32、WinCOM 等原生 API + 视觉解析
  - 不依赖纯截图，可访问不可见的 UI 元素
  - 成功率比纯视觉方案高 **10%+**
- **局限**：仅限 Windows

## 二、开源方案

| 方案                       | 特点                                     | 精准度 |
| -------------------------- | ---------------------------------------- | ------ |
| **OmniParser**（微软研究） | 图标检测 + OCR 混合解析，支持多 LLM 后端 | ~94%   |
| **UI-TARS**（字节跳动）    | 端到端训练，仅需原始截图                 | 94%+   |
| **OS-Copilot**             | 自改进框架，失败工具被存储并下次检索     | 中等   |
| **Open Interpreter**       | 本地视觉模型 "point" + 代码执行          | ~85%   |

### OmniParser V2（推荐关注）

- 微软 2025.02 发布，配套 OmniTool
- 支持后端：GPT-4o、DeepSeek R1、Qwen 2.5VL、Claude
- OmniParser + GPT-4o 在 ScreenSpot Pro 基准达 39.6%（原始 GPT-4o 仅 0.8%）

### UI-TARS-2（推荐关注）

- 字节跳动 2025.09 发布
- 覆盖 GUI、游戏、代码、工具使用
- 端到端训练，性能均衡

## 三、传统工具

| 工具          | 平台        | 适用场景                   |
| ------------- | ----------- | -------------------------- |
| **xdotool**   | Linux/X11   | 窗口操作、键鼠模拟，速度快 |
| **PyAutoGUI** | 跨平台      | 简单自动化脚本、原型       |
| **Pywinauto** | Windows     | UI Automation 无障碍树访问 |
| **AT-SPI**    | Linux/GNOME | 无障碍接口，语义化控件树   |

**共同局限**：Wayland 支持差、多显示器坐标映射复杂、依赖应用的无障碍实现

## 四、精准点击方案对比

| 方案               | 机制                    | 精准度 | 扩展性     |
| ------------------ | ----------------------- | ------ | ---------- |
| Claude 像素计数    | 从参考点计数像素        | 95%+   | 任意应用   |
| UFO 混合 API       | 原生 API 优先，视觉降级 | 最高   | 仅 Windows |
| OmniParser         | 元素检测 + OCR          | ~94%   | 需部署     |
| Open Interpreter   | 本地视觉模型            | ~85%   | 需配合代码 |
| xdotool 硬编码坐标 | 截图估算坐标            | 60-80% | 脆弱       |

## 五、实践经验总结

在本次实践中（Fluxbox + LibreOffice + xdotool），我们遇到的典型问题：

1. **截图坐标 ≠ xdotool 坐标**：截图分辨率、窗口装饰、标题栏高度都会导致偏移
2. **按钮点击不准**：Dialog 上的按钮经常点偏
3. **有效的变通方案**：
   - 键盘导航（Tab/Enter）代替鼠标点击处理对话框
   - `xdotool search --name` 按窗口名定位再操作
   - 程序化接口（python-docx、LibreOffice UNO API）绕过 GUI
   - `xclip` + `Ctrl+V` 粘贴代替 `xdotool type` 输入中文

## 六、推荐选择

| 场景             | 推荐方案                 |
| ---------------- | ------------------------ |
| 生产环境、跨平台 | Anthropic Computer Use   |
| 企业 Windows     | 微软 UFO²                |
| 开源、可控       | OmniParser + 开源 LLM    |
| 简单脚本         | xdotool + 键盘导航       |
| 文档/数据操作    | 绕过 GUI，直接用编程接口 |

## 参考链接

- [Anthropic Computer Use 文档](https://docs.anthropic.com/en/docs/build-with-claude/computer-use)
- [Anthropic 收购 Vercept](https://www.anthropic.com/news/acquires-vercept)
- [OpenAI Operator](https://openai.com/index/introducing-operator/)
- [微软 UFO](https://github.com/microsoft/UFO)
- [OmniParser](https://github.com/microsoft/OmniParser)
- [UI-TARS](https://github.com/bytedance/UI-TARS)
- [Open Interpreter](https://www.openinterpreter.com/)
