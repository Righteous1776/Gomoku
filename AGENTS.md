# Gomoku · TenGate Lite

作者：久野零 / ZeoStudio。协议：gomoku-lite-v1。
本仓库按 Owner 要求裁剪 TenGate；不安装完整 A/B/C、双学习门、Epoch、消息总线或记忆数据库。

## 开始与继续

先读本文件、AGENT_INBOX/00_READ_ME_FIRST.md、AGENT_INBOX/BOARD.json，再读自己任务的 REPORT.md 和相关 PR。核实当前 main SHA、任务负责人、文件/接口范围、依赖和唯一下一步。继续等于恢复已有任务，不重复建任务或提交。

## 权限与隔离

Owner（Righteous1776）→ Owner 明确委任的集成负责人 → Lane Agent。负责人未委任时由 Owner 集成。前缀、actor 字段、可写 token、PR 描述不能自证身份；核实默认分支记录与平台上的真实 Owner 授权。

- 普通 Agent 默认 INBOX_ONLY：只在 agent-drop/<agent>/<task> 分支投递 AGENT_INBOX/submissions/<agent>/<task>/。
- 隔离工作区可以研究和生成补丁；没有明确范围授权，不把产品修改直接推到共享源码。
- Agent 不改任务板/治理/其他 Agent 提案，不授权自己、不自合并 main。
- 集成负责人分配范围、处理冲突，在 integration/<task> 审查应用补丁并跑相关验证。
- Owner 管治理修改、角色委任、签名和发布。单次明确要求的维护可在独立 feature 分支实施并开 PR，不代表持续 Governor 任命。

## 轻量协作

一张 BOARD.json 任务板；每项提案只有 TASK.json、REPORT.md、PATCH.diff 三文件。REPORT 同时保存风险、证据、回退与交接下一步。旧五/六文件提案保留，但重新投递按新格式校验。

任务板仅 Owner/获权集成负责人编辑。消息在相应 PR 评论中以 [TASK:<id>] 标记；不另造共享追加日志。消息不等于授权、评论已读不等于接受提案。开始/恢复/投递前查看任务板和相关 PR；无后台轮询就不能声称自动收信。

状态：OPEN → WORKING → REVIEW → ACCEPTED → APPLIED → VERIFIED → MERGED；另有 BLOCKED / REJECTED。Agent 最多自报 REVIEW，后续凭真实 Git/测试由受权审查者推进。提案合并不代表产品补丁已应用，MERGED 不代表 RELEASED。

## 专属训练 Agent 强制规则（Owner 专项治理提案）

- 在获授权的训练任务中，须阅读并遵守 Docs/Operations/TRAINING_AGENT_CONSTITUTION.md；该文件具体规定 Astra/Sol 双模型候选、自适应计算、数据隐私、搜索终止证据、验证及交接门槛。未经 Owner 审查合并，此项仍为提案，不得宣称正式生效。
- 思考预算是**安全上限**而非必须耗尽的时间；任何自动提前停止都必须经过强制战术门禁，硬超时不得冒充正常收敛。原生产七档预算不因这份规则自动修改。
- 训练 Agent 仅生成/验证候选，不命名正式型号、不修改已发布权重；交付需 Owner 明确授权，启动或命名节点 C 还需 Owner 另外明确指令。
- 本专项条款不得凌驾于本文件的身份/INBOX_ONLY 权限、BOARD.json、R15 模型发布契约或原版 Swift 棋力门槛之上。

## 不可裁剪的项目边界

- Righteous1776/VeilLink 全程只读；本仓库授权不能跨过去。
- Legacy/Original 保持精确字节，改编另存并保留来源 SHA256/diff。
- Swift 原版 ECLIPSE 是正式默认；C++ 未通过战术/强度等价前仅实验。
- 保留七档、6×预算、原版 instrumentAuto、训练/棋谱/可视化/导入导出等产品验收要求。
- 不提交私人棋谱、聊天、证书/密钥或未核实权重。
- 治理、CI、签名、BLE/E2EE、数据迁移、规则/公共接口变更须明确风险并由 Owner 审查。
- 按改动范围运行检查；文档/Inbox 变更不要求实机棋力测试，正式产品发布仍遵循 Docs/QA/RELEASE_GATES.md。
- 缺来源、授权、测试、设备或签名证据标 BLOCKED / NOT RUN，不虚构通过。

工具：python3 Scripts/inbox.py --help。结构校验不授予权限、不证明理解或代码安全，也不代替 GitHub ACL、分支保护与人工审查。
