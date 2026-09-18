# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-02
- Feature Path: 商品搜索 > 搜索索引同步 > 索引生命周期与全量构建 > 手工重建与索引一致性检查
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成（ES IT）：触发 rebuild，构建中并发搜索持续可用（别名仍指旧索引）；完成后 GET _alias 指向新物理索引、新数据可搜、旧索引 GET 404 | AC-001 | DU-BE-504 | [S1] |
| TC-002 | 集成：任务行 RUNNING→SUCCEEDED，total/indexed_count 与实际一致；mock 中途失败 → FAILED+error_message，别名与旧索引不变仍可查 | AC-002 | DU-BE-504 | [S1] |
| TC-003 | API：首触发 200 {taskNo,RUNNING}；RUNNING 期间第二次 POST → 409 B0503 且响应/数据可定位当前 taskId | AC-003 | DU-BE-504 | [S1] |
| TC-004 | 集成：一致性检查正常时两计数相等、差集空；人为 DELETE 3 文档 → missingProductIds 含 3 个；造 2 个孤儿 docId → extra 报 2；构造 >200 差异 → truncated=true 且列表 200 | AC-004 | DU-BE-504 | [S1] |
| TC-005 | 安全：无 search:index:rebuild 权限 JWT POST → 403；无 list GET → 403；未登录经网关 /api/admin/search/** → 401 | AC-005 | DU-BE-504 | [S1] |
| TC-006 | 迁移：identity V9 权限/菜单种子存在且授予超管角色 | AC-005 | DU-BE-504 | [S1] |
| TC-007 | 前端 Vitest：SearchIndexView 任务列表渲染、重建 confirm、RUNNING 禁用+轮询进度、409 提示、差异表格/truncated 提示 | AC-006 | DU-FE-502 | [S1] |
| TC-008 | 构建门禁：mall-admin type-check/lint/test/build 全绿 | AC-006 | DU-FE-502 | [S1] |

## 2. 测试策略

- ES IT：重建流程用真实别名切换 API 验证原子性；并发用 CountDownLatch/直接先插 RUNNING 行模拟。
- 前端：api mock + 定时器 vi.useFakeTimers 控制轮询。
- 浏览器验证（按钮权限/实际触发）放 Integration Gate。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- DU-BE-503（生命周期/投影/全量/两表）；mall-identity 迁移基线到 V8。
