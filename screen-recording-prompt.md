# 录屏指令

当操作要求录屏时，按以下流程执行：

## 1. 启动录制

```bash
ffmpeg -f x11grab -video_size 1440x768 -i :1 -r 10 -c:v libx264 -preset ultrafast output.mp4 -y
```

- 使用 Bash 工具的 `run_in_background: true` 参数

## 2. 执行浏览器操作

每次点击前，先用 `evaluate_script` 高亮目标元素：

```javascript
(el) => {
  // 创建点击指示器
  const rect = el.getBoundingClientRect();
  const indicator = document.createElement('div');
  indicator.style.cssText = `
    position: fixed;
    left: ${rect.left + rect.width/2 - 20}px;
    top: ${rect.top + rect.height/2 - 20}px;
    width: 40px;
    height: 40px;
    border: 3px solid red;
    border-radius: 50%;
    pointer-events: none;
    z-index: 999999;
  `;
  document.body.appendChild(indicator);

  // 给元素添加红色边框
  el.style.outline = '3px solid red';
  el.style.outlineOffset = '2px';

  return 'highlight added';
}
```

操作流程：
1. `take_snapshot` 获取页面元素
2. `evaluate_script` 高亮目标元素（传入 `args: [{"uid": "目标uid"}]`）
3. 等待 1 秒（让视频捕获到高亮）
4. `click` 执行点击

## 3. 停止录制

```bash
pkill -INT ffmpeg && sleep 2
```

- **不要用 KillShell**，会导致视频损坏
- 用 `pkill -INT` 发送中断信号，让 ffmpeg 优雅退出

## 4. 输出结果

- 显示视频文件路径和基本信息（大小、时长）

---

## 使用示例

> 测试页面能否正常操作（录屏）

> 录屏：打开 https://example.com，点击 Learn more 链接
