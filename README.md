## Dev Container 执行顺序总结

1. initializeCommand (本地主机，容器创建前)
2. 容器创建
3. onCreateCommand (容器首次创建时执行一次)
4. updateContentCommand ()
5. postCreateCommand (每次容器启动时执行)
6. 容器启动
7. postStartCommand (容器内，每次启动)
8. VS Code 附加到容器
9. postAttachCommand (容器内，每次附加)

## 参考资料

- https://containers.dev/implementors/json_reference/

- https://github.com/devcontainers/features
- https://github.com/devcontainers/feature-starter

- https://bun.sh/docs/runtime/nodejs-compat

- https://github.com/Kilo-Org/kilocode/blob/3cd45ec127d5a86c4c103fc4684545cf6aa3e30c/cli/Dockerfile
- https://code.claude.com/docs/zh-CN/devcontainer

## 已知问题与解决方案

### JavaScript 调试器的 autoAttachFilter 问题

在 Dev Container 中使用 JavaScript 调试器时，`autoAttachFilter` 设置存在以下问题：

**问题描述：**
- `autoAttachFilter` 会在 `NODE_OPTIONS` 中注入 `bootloader.js` 的 `--require` 参数
- 并错误地重复拼接 `--max-old-space-size`，形成类似：
  ```
  NODE_OPTIONS= --require /home/.../bootloader.js  --max-old-space-size=4096--max-old-space-size=4096
  ```
- 导致启动时报错：
  ```
  Error: illegal value for flag --max-old-space-size=4096--max-old-space-size=4096 of type size_t
  ```

**解决方案：**
在 `devcontainer.json` 中将 `debug.javascript.autoAttachFilter` 设置为 `"disabled"` 以规避该问题：
```jsonc
"debug.javascript.autoAttachFilter": "disabled"
```

**相关参考：**
- https://stackoverflow.com/questions/75708866/vscode-dev-container-fails-to-load-ms-vscode-js-debug-extension-correctly
- https://davidwesst.com/blog/missing-bootloader-in-vscode-devcontainer/
