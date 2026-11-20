# Gomoku Inbox · 轻量操作卡

先读 ../AGENTS.md 和 BOARD.json。Owner/获权集成负责人负责登记任务、agent_id、state、scope、interfaces、depends_on。scope 只接受精确路径或末尾 / 的目录，避免复杂通配符。

## Agent 四步

1. 拉取最新 main，检查任务板、相关 PR 评论和已有 REPORT 的下一步。没有分配就只读调查。
2. 在隔离工作区研究，生成相对真实 main SHA 的文本补丁。远端分支命名 agent-drop/<agent>/<task>。
3. 只投递 AGENT_INBOX/submissions/<agent>/<task>/ 中的三个文件：
   - TASK.json：schema=gomoku-drop-v1；agent_id、task_id、base_sha、state=DRAFT或REVIEW；tests=[{command,status,evidence}]，status 取 PASS/FAIL/NOT RUN/BLOCKED。
   - REPORT.md：## Goal、## Changes、## Risks、## Rollback、## Evidence、## Next 六节；兼作会话交接。
   - PATCH.diff：git diff 生成的 UTF-8 文本补丁；纯调查写 NO_PATCH: 具体原因。
4. 运行校验，开 [AGENT-DROP] Draft PR；不得把产品改动一并推入、自行改任务板或自合并。

```sh
python3 Scripts/inbox.py status
python3 Scripts/inbox.py check-board
python3 Scripts/inbox.py check-drop --base <main完整SHA> --head <提案完整SHA> --branch agent-drop/<agent>/<task>
```

TASK.json 最小例子（示例不是授权）：

```json
{"schema":"gomoku-drop-v1","agent_id":"engine-agent","task_id":"CPP","base_sha":"填写真实40位SHA","state":"REVIEW","tests":[{"command":"ctest --test-dir build","status":"NOT RUN","evidence":"尚未执行，不能当作通过"}]}
```

check-drop 从 base 的 Git 对象读取可信任务板，拒绝跨目录投递、未分配任务、过期基线、自报 ACCEPTED、文件/接口冲突、依赖未合并与范围外补丁。调用方必须核实 base 是 PR 目标分支当前 SHA；本地 CLI 无法证明远端新鲜度。通过只代表 VALIDATED_LOCAL。

## 集成与消息

负责人检查提案、基线、依赖、冲突、隐私、许可证与测试；在 integration/<task> 独立应用后再跑项目验证并提交 PR。ACCEPTED 不等于 APPLIED；APPLIED 不等于 VERIFIED；MERGED 不等于发布。敏感面交 Owner 明确审查。

消息使用相应 PR 评论，以 [TASK:<id>] 标明关联任务，可链接其它 PR；不再建 Exchange 消息总线和回执目录。没有自动后台轮询；恢复/开始/投递前人工或 Agent 主动看消息。

## 兼容与限制

旧五/六文件历史保留；重新投递按新格式。01_GOVERNOR_IDENTITY.md、02_RULES.md 仅兼容导航。WORK_HANDOFF.md 保留原始产品任务，当前协作协议以 AGENTS.md 与本卡为准。

不部署完整插件双学习门/宪法/记忆层，缺失的旧 Gate 不伪报 PASS。工具仅结构与路径检查，不证明理解、授权、补丁正确、无密钥或语义无冲突；审查与真实 GitHub 权限仍是必要边界。
