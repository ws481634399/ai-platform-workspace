# Implementation（跨仓实施汇总）— 收货地址管理 STORY-003-01-03-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story：STORY-003-01-03-01 收货地址管理
- 实施日期：2026-09-21（后端 DU-BE-604）/ 2026-09-15（前端 DU-FE-603）
- 范围边界：mall-member 收货地址 CRUD + 设默认 + 查询默认（`/api/mall/shipping-addresses`，
  类级 MEMBER、memberId+id 双条件资源归属、每会员 20 条上限、默认地址全表唯一）；
  V2 迁移 shipping_address（生成列 default_member_flag + uk 兜底默认唯一）；
  mall-web 收货地址页（列表/默认徽标/新增编辑弹层/删除确认/乐观设默认）。
  不含：地址库选择器与下单结算联动（后续 CHG）、省市区三级联动组件（本期文本输入）。
  网关 MEMBER 路由规则已由 DU-BE-602 预置，本 Story 两仓均未改网关。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-604 | repo-1（ai-platform-backend） | 完成并验证：mall-member 79/79（新增 35：领域 18 + 应用 6 + API 11），全量 24 模块 311 例全绿（基线 276+35） |
| DU-FE-603 | repo-2（ai-platform-frontend / mall-web） | 完成并验证：vitest 12 文件 58/58（新增 21：api 6 + 表单 9 + store 6），vue-tsc 0 错误、eslint 0 errors、vite build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| e6068a1bf813dacf353fd509ab0535563f868230 | DU-BE-604 | repo-1 | feat(member): 收货地址 V2 生成列默认唯一 + CRUD/设默认/上限20/归属404（14 新增文件零修改既有，35 例测试） |
| 6a10cdd2de3d5b317bdc1022cad8382e2e4b70b5 | DU-FE-603 | repo-2 | feat(mall-web): 收货地址管理页（列表/默认徽标/新增编辑弹层/删除确认/乐观设默认，10 文件 21 例测试） |

（两仓各另有 docs(sdd) implementation/evidence 与 chore(sdd) metadata 回填两个非代码提交，
详见各 DU evidence/commits.md，非代码提交不计入 code-change Evidence。）

基线说明（本 Change 累计代码提交链）：STORY-01 注册 DU-BE-601 代码提交
2f70309a7834513300387327a7e7048ebbea0ab8；STORY-02 登录与会话 DU-BE-602 代码提交
f1367cb5617cae51a3de1c78256f6992915f5fa6、DU-FE-601 代码提交
97b83107636fbf9051140d591f6addcb86aad0db；STORY-03 会员资料 DU-BE-603 代码提交
8c5a1e690845b85e03ee839318d4bcdbce88893b、DU-FE-602 代码提交
c20c24c6230790a8bd5af70571e2165a1d67ff64。本 Story 构建于两仓 STORY-03 收尾态之上
（两仓本 Story 的基线均为上一 Story 的 chore(sdd) metadata 回填提交，其后仅有非代码
SDD docs/chore 提交，完整 40 位基线见各 DU metadata.yaml）；
repo-1 新增 V2 迁移，repo-2 无依赖变更。

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-BE-604/implementation.md`
  - DEV-1：V2 DDL 去 STORED 改 `GENERATED ALWAYS AS (CASE WHEN is_default=1 THEN member_id ELSE NULL END)`
    ——H2 MODE=MySQL 测试库不认 IF() 函数与 STORED 关键字；省略 STORED 后 MySQL 8 走默认
    VIRTUAL，UNIQUE 索引对虚拟生成列仍物化键值，默认唯一性等价。
  - DEV-2：详址上限取 SSOT **128**（后端 task-design 误写 200），ShippingAddress.DETAIL_MAX=128。
  - DEV-3：设默认动作为 **PUT /{id}/default**（非早期文档的 POST /set-default），以
    story-design §2/requirement-design §4 为准。
  - DEV-4：并发设默认的 MySQL 真实生成列 + DuplicateKey 409 复验留 M3 Test；
    H2 并发用例可能串行化成两成功（AddressDefaultConcurrencyTest 容忍两结局，失败必须为 B0203）。
  - DEV-5：H2 2.x INFORMATION_SCHEMA.INDEXES 无 IS_UNIQUE 列，唯一性别在
    INDEX_TYPE_NAME LIKE '%UNIQUE%'；约束支持索引自动命名 uk_address_default_INDEX_2，
    断言须前缀 LIKE；冲突异常文案含小写 uk_address_default（assertj 无忽略大小写 message 断言）。
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-FE-603/implementation.md`
  - DEV-1：task-spec「vitest 全流程组件测试」落为 api/表单/store 三逻辑切片（沿用
    DU-FE-601/602 无 DOM 挂载栈惯例，不新增依赖），真实点击链路归 M3 Test。
  - DEV-2：前端详址上限同步取 SSOT 128（常量/maxlength/校验三处统一），与后端同界。
  - DEV-3：setDefault 端点对齐后端 PUT /{id}/default（api spec 单例锁定路径）。
  - DEV-4：独立 pinia member-address store（不挂 member store）；写操作成功统一强拉、
    仅设默认乐观更新+失败回滚重拉；新增/编辑弹层同 SFC 内聚未拆 AddressForm。

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-019 | POST 新增 201 AddressView（@StringId 字符串 id、无 memberId）；count=0 首条强制 isDefault=true，insert 后 reload 拿 DB 时间；前端新增成功关弹层并强拉、默认徽标由后端 isDefault 决定 | passed（ShippingAddressApiTest::TC-001 首条默认；AddressApplicationServiceTest 首条强制默认；address.spec/store.spec；TC-001/TC-011，联调项见 test-report §4） |
| AC-020 | 列表 `is_default DESC, updated_at DESC` 仅本人地址（listByMember 双条件），响应 {items,defaultId}；前端直接渲染后端顺序、本地不排序、写后强拉 | passed（TC-002 双会员隔离+排序 SQL；store fetch/强拉 4 例；TC-002/TC-011） |
| AC-021 | update/delete/setDefault 全部 memberId+id 双条件加载；越权 loadOwned 失败 404 B0201 且他人数据不变（delete 0 行即 404）；前端 store 仅在成功响应后落状态、失败 toast 数据不变 | passed（TC-003/TC-004 双会员越权矩阵；store 409/回滚用例佐证失败不落状态；TC-003/004/011） |
| AC-022 | setDefault 同事务 clearDefault+markDefault，catch DuplicateKeyException→409 B0203；生成列 uk_address_default 数据库层兜底全会员仅一默认；前端乐观即时置顶、失败回滚快照+重拉+toast | passed（TC-005 SQL 断言仅一条默认、TC-006 并发双线程；store 乐观时点与 409 回滚两例；TC-005/006/011；MySQL 真实验证留 M3 Test，DEV-4） |
| AC-023 | 删除默认 204 后不重选默认；GET /default 返回 200 {item:null}；前端删除成功强拉，空态/无徽标由服务端 items/defaultId 决定 | passed（TC-007 删默认 + getDefault item:null；store remove 强拉空列表；TC-007/011） |
| AC-024 | Bean Validation + 聚合双道：收货人 1–32、手机 ^1[3-9]\d{9}$、省市区 1–64、详址 1–128、邮编空/6 位数字 → 400；第 21 条 → 409 B0202；V2 生成列与 uk 迁移可验证；前端行内字段错误不关弹层 + 20 条上限零请求提示 | passed（TC-008 参数化 400、TC-009 上限 409、TC-010 H2 元数据断言；address-form.spec 9 例 + reachLimit 用例；TC-008~011） |
| AC-025 | mall-web 收货地址查看/新增/编辑/删除/设默认流程可用；vitest 58/58、type-check/lint/build 全绿；/member/addresses 挂 requiresMember，布局增「收货地址」入口 | passed（TC-011：四检 + 21 新增切片用例；浏览器联调归 M3 Test） |

## 5. Fan-in 与验证结论

- 后端：repo-1 `mvn clean package` 24 模块 BUILD SUCCESS，全量 **311/311**（0 failures/0 errors/0 skipped，
  基线 276 + 本 Story 35）；变更全部落在 mall-member（14 新增文件，零修改既有产品类），
  identity/gateway 与既有注册/登录/资料链路零回归。
- 前端：repo-2 mall-web vitest 12 文件 **58/58**（基线 37 + 21）、vue-tsc 双 tsconfig 0 错误、
  eslint 0 errors（133 warnings 全为已降级样式规则）、vite build 成功
  （AddressListView 路由级分包 10.19 kB/gzip 3.33 kB）；无新增依赖、未改 lockfile。
- 过程红基线：后端 H2 生成列 DDL 双不兼容（IF()/STORED）、H2 元数据列名/约束索引命名、
  ECJ 未 clean 留错误桩类（RED-1~5）；前端表单夹具展开顺序覆盖、mock 实现返回类型两处，
  均在开发期闭环并留 red→green 证据，无产品行为缺陷。
- 跨仓契约两侧锁定：六端点路径/方法（含 PUT /{id}/default、GET /default 的 {item:null}、
  DELETE 204 空体）、AddressView 字段（字符串 id、无 memberId、postalCode 可 null）、
  B0201/B0202/B0203 中文文案 ↔ resolveErrorMessage 透传链、详址 128/手机正则/邮编规则逐一核对一致。
- 真实 MySQL 8 生成列 DDL 与并发设默认 409、真实浏览器「登录→地址全流程→双会员越权 404→
  上限 409」两进程链路（网关 8080/member 8102）留待 M3 Test 五集成场景联调。
