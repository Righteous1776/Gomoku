# TenGate Lite · 改造与验证记录

日期：2026-11-20（Asia/Shanghai）。任务：GOMOKU-GOV-LITE-001。
基线：3c963550fd2cc93b5b5be55d58a76023d89273b8。改造分支：feature/governance-lite。
来源：真实 GitHub 仓库；Owner 本会话明确要求学习 ZeoStudio-TenGate 并做更轻量的协作改造，随后指定云端浏览器编辑。

## 取舍

| 能力 | Lite 实现 |
|---|---|
| 身份/规则 | AGENTS.md + BOARD.json，Owner → 负责人 → Agent |
| 分工/依赖 | 六项 OPEN 任务；精确文件/目录范围与接口冲突检查 |
| Inbox | 每项 TASK.json、REPORT.md、PATCH.diff 三文件 |
| 断点续接 | 任务 ID + REPORT 下一步 + PR/commit；不增加 Session 数据库 |
| 消息 | PR 评论 [TASK:id]；不部署独立 Exchange/回执 |
| 校验 | 单个 Python 标准库脚本，无额外依赖 |
| CI | 一项 Ubuntu Inbox 检查；纯 Inbox/文档改动跳过 C++/macOS 构建 |
| 审查 | CODEOWNERS 指向真实 Owner；不声称服务器保护已开启 |

未启用插件完整 A/B/C 安装、双学习门、Epoch、编号记忆/睡眠复盘，不伪报完整 Gate 通过。
日常必读仅三个入口，不要求每轮重读产品迁移大纲；产品发布验收不降低。

## 来源学习

阅读了 ZeoStudio 统一入口、四份桥接/冲突/学习/作业参考、平台路由与 ChatGPT 接入卡、操作手册入口、Inbox 互操作、迁移和上下文预算章节，以及记忆层入口/权限/续接约束。参考了 Owner/Governor/Lane、提案隔离、消息不授予权限、真实状态与持续任务原则。
安装目录包版本 1.5.1，入口 metadata 自报 1.5.0；记录此差异，不宣称它就是上游仓库 4.1/5 的最新版。
当前仓库未安装 CONSTITUTION_SEAL、MANDATORY_READ_SET、07_LEARNING_GATE 和对应旧机器门；按 Owner 明确要求设计本仓库独立 Lite 协议，不伪造旧门通过或额外身份。

## 实际验证

从 GitHub 改造分支回读 Scripts/inbox.py、Scripts/tests/test_inbox.py、BOARD.json 后在 Linux/Python 3 执行：

```text
python3 -m unittest discover -s Scripts/tests -v
Ran 16 tests — OK
python3 Scripts/inbox.py check-board
BOARD_VALID
```

包含真实临时 Git 仓库中的研究提案/文本补丁正向测试，以及共享源码修改、篡改授权任务板、范围外补丁、自报接受、陈旧基线、符号链接、缺失测试证据、路径穿越、并行文件/接口冲突、依赖未合并/环与无负责人等负向测试。

## 局限与交接

校验只检查结构、路径、声明的测试证据存在，不证明理解、授权、测试真实、源码正确、无密钥或语义无冲突。base 是否为当前远端 main 需要调用者/审查人核实。普通 Agent 无自合并权限；任务板修改须由 Owner/获权负责人在受信分支批准。
首次协议 PR 用 head 自检；后续 agent-drop 的边界校验使用 PR base 中的可信脚本与任务板。GitHub ACL、review、分支保护仍须真实配置，CODEOWNERS 文件本身不强制保护。
既有 iOS CI 曾显示失败，本次不把其当作新协作工具通过，也不宣称修复产品迁移/IPA。
尚未任命持续 Governor，六项任务未实际派给其他 Agent，本轮不假装多 Agent 已运行。
下一步：审查并合并本治理 PR，再由 Owner/获权负责人按任务板分配真实 Agent。
