# Implementation（Change 跨仓聚合兼容层）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址：注册 / 登录与会话 / 会员资料 / 收货地址）
- Task 来源：两实现仓 7 个 DU 的 task-design.md / task-spec.md
- 主仓库：repo-1
- Story：STORY-003-01-01-01（注册）、STORY-003-01-01-02（登录与会话）、STORY-003-01-02-01（会员资料维护）、STORY-003-01-03-01（收货地址管理）

## 1. Delivery Unit 状态总览

| DU | 仓库 | Story | 状态 |
| --- | --- | --- | --- |
| DU-BE-601 | repo-1（ai-platform-backend） | 注册 | completed（mall-member 全量绿；outbox-lite + 双幂等建档） |
| DU-BE-602 | repo-1 | 登录与会话 | completed（identity/gateway 双令牌与 MEMBER 隔离测试全绿） |
| DU-FE-601 | repo-2（ai-platform-frontend） | 登录与会话 | completed（登录态基础设施 + 登录/注册页，22 例） |
| DU-BE-603 | repo-1 | 会员资料维护 | completed（/me 读写、MinIO 头像、profile-seed 懒补偿） |
| DU-FE-602 | repo-2 | 会员资料维护 | completed（个人中心资料页，累计 37 例） |
| DU-BE-604 | repo-1 | 收货地址管理 | completed（V2 生成列默认唯一，79 例，全仓 311/311） |
| DU-FE-603 | repo-2 | 收货地址管理 | completed（地址管理页，21 例，累计 58/58） |

## 2. Commit 记录

### repo-1（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| 2f70309a7834513300387327a7e7048ebbea0ab8 | DU-BE-601 | feat(identity,member): 会员注册全链路 outbox-lite 与 provision |
| f1367cb5617cae51a3de1c78256f6992915f5fa6 | DU-BE-602 | feat(identity,gateway): 会员登录/刷新/退出双令牌与网关 MEMBER 隔离 |
| 8c5a1e690845b85e03ee839318d4bcdbce88893b | DU-BE-603 | feat(member): 会员资料 GET/PUT /me、MinIO 头像上传与 profile-seed 懒补偿 |
| e6068a1bf813dacf353fd509ab0535563f868230 | DU-BE-604 | feat(member): 收货地址 V2 生成列默认唯一 + CRUD/设默认/上限20/归属404 |

（各 DU 另有 docs(sdd)/chore(metadata) 类仓内提交，非代码变更，详见各 DU evidence/commits.md；
基线为各 Story 上一 chore(sdd) 提交，完整 40 位 hash 见各 DU metadata.yaml。）

### repo-2（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| 97b83107636fbf9051140d591f6addcb86aad0db | DU-FE-601 | feat(web): 会员登录态基础设施与登录/注册页 |
| c20c24c6230790a8bd5af70571e2165a1d67ff64 | DU-FE-602 | feat(mall-web): 个人中心资料页（GET/PUT /me 表单与头像预览上传） |
| 6a10cdd2de3d5b317bdc1022cad8382e2e4b70b5 | DU-FE-603 | feat(mall-web): 收货地址管理页（列表/默认徽标/弹层/删除确认/乐观设默认） |

（文档类提交同上，见各 DU evidence/commits.md 与 metadata.yaml。）

## 3. 各仓实施引用

- repo-1：
  - `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员注册/DU-BE-601/implementation.md`
  - `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-BE-602/implementation.md`
  - `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-BE-603/implementation.md`（MinIO 懒建桶/503 隔离、profile-seed 缺档补偿等 DEV）
  - `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-BE-604/implementation.md`（V2 生成列 CASE WHEN 跨方言、唯一默认并发双保险）
- repo-2：
  - `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-FE-601/implementation.md`
  - `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-FE-602/implementation.md`
  - `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-FE-603/implementation.md`（逻辑切片测试、独立 address store、乐观设默认回滚等 DEV-1~4；red→绿见各 DU evidence/red-green.md）

## 4. 与 Task / AC 对应关系

| AC | 内容（摘要） | 承载 DU |
| --- | --- | --- |
| AC-001~007 | 注册：唯一冲突、规则 400、事件双幂等建档、失败补偿、无半成品 | DU-BE-601 |
| AC-008~013 | 登录：双令牌 claim、统一错误文案、停用拒绝、刷新旋转/401、登出失效、令牌域 403 | DU-BE-602 |
| AC-014~015 | 刷新恢复与单飞重放、401 清登录态跳登录并回跳 | DU-FE-601 |
| AC-016~018 | GET/PUT /me、缺档懒补偿、头像上传与 503 隔离 | DU-BE-603 + DU-FE-602 |
| AC-019~024 | 地址：首条默认、归属列表、越权 404、唯一默认并发、删默认不重选、校验与 20 上限 | DU-BE-604 + DU-FE-603 |
| AC-025 | mall-web 四页面流程可用，build/lint/type-check/test 通过 | DU-FE-601/602/603 |

25 条 AC 全部完成（AC-025 为跨 Story 前端工程门禁）。真实两进程/浏览器/真实 MySQL 与 MinIO
的 5 个集成场景统一在 M3 Test 阶段执行，各 DU 的待联调项已在 story test-report 逐条登记。
