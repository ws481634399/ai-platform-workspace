# Review Report — 收货地址管理 STORY-003-01-03-01

> 阶段：sdd-review 产物（同态检查点，状态保持 testing）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Test Report 来源：`商城前台/商城会员/收货地址/收货地址管理/evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-016/019 code-change、EV-018/021 test-run、EV-017/020 evidence-ref）
- 检查时间：2026-09-21T18:30:00+08:00

## 1. 检查结论

无开放 blocker/major/minor。后端 dev 期五处真实失败（H2 DDL 双不兼容、参数化注解、
H2 元数据命名、时间夹具、ECJ 桩类）与前端两处（夹具展开顺序、mock 返回类型）均在开发期
闭环并留 red→green 证据；九片 Deviations 理由均成立（后端 DEV-1~5、前端 DEV-1~4，
详见 §1.2）。

### 1.1 需求一致性

| AC | test-run 证据（EV-018 covers AC-019~024；EV-021 covers AC-019~025） | 结论 |
| --- | --- | --- |
| AC-019 | TC-001：POST 201 AddressView（字符串 id/无 memberId/ISO 时间），count=0 强制默认 + insert 后 reload 取 DB 时间；前端新增成功强拉、徽标取后端 isDefault | passed（首条默认真实两进程随 M3 Test） |
| AC-020 | TC-002：双会员列表隔离 + is_default DESC, updated_at DESC 顺序，{items,defaultId} 信封；前端写后强拉本地不排序 | passed |
| AC-021 | TC-003/004：更新/删除全部 memberId+id 双条件，越权 404 B0201 且他人数据不变（删 0 行即 404）；前端 store 失败不落状态、toast 透传 | passed（真实双会员浏览器越权随 M3 Test） |
| AC-022 | TC-005/006：同事务 clearDefault+markDefault、SQL 断言仅一默认、并发生成列 uk 兜底其一 409 B0203；前端乐观置顶+失败回滚快照重拉再抛 | passed（MySQL 真实并发 409 复验随 M3 Test，DEV-4 已登记） |
| AC-023 | TC-007：删默认不重选，GET /default 200 {item:null}；前端强拉后空态/无徽标由服务端决定 | passed |
| AC-024 | TC-008/009/010：聚合+Bean Validation 双道（32/手机正则/64/128/邮编 6 位）400、第 21 条 409 B0202、V2 生成列与 uk 迁移元数据可验证；前端行内错误不关弹层 + 20 条零请求提示 | passed |
| AC-025 | TC-011：mall-web 地址全流程切片 21 例 + 四检全绿（58/58、0 类型错误、0 lint errors、build 分包），requiresMember 守卫 + 布局入口 | passed（真实浏览器流程随 M3 Test） |

7 条 AC 均被 covers 包含其的 test-run 条目覆盖，追踪链 AC→TC（11 条）→测试方法→DU evidence 无断链。

### 1.2 设计一致性（Design → DU → Implementation）

- **地址聚合与归属**：ShippingAddress create/reconstitute/revise 不变量内聚（收货人 ≤32、
  手机/邮编正则、详址 SSOT 128、邮编 null 合法）；Repository 端口八方法全部 memberId+id
  双条件，应用层 loadOwned 失败统一 404 B0201——越权与不存在同文案，不泄露地址存在性。
- **默认唯一双保险**：应用层同事务 clear+mark（InOrder 可验证）+ 数据库层生成列
  default_member_flag = CASE WHEN is_default=1 THEN member_id ELSE NULL END 配 UNIQUE 索引；
  DuplicateKeyException 显式转 409 B0203（BusinessException 无 cause 构造器，不依赖异常嵌套）。
- **上限语义**：count≥20 在写库前 409 B0202，与前端 ADDRESS_LIMIT=20/reachLimit 同界；
  首条强制默认保证 defaultId 在有地址时永不为 null（getDefault {item:null} 仅在空列表）。
- **DTO 边界**：AddressView 经 @StringId 仅出参序列化字符串、不含 memberId；
  AddressRequest @Pattern 对 null 放行（邮编选填）；前端类型逐字段对齐，postalCode 空串归一 null。
- **时间与排序**：Mapper 写 NOW(6)、应用层 insert/update 后 reload 取 DB 时间，
  不信客户端时钟；列表排序固定两键，前端不做本地重排（写后强拉消除漂移）。
- **前端架构**：API 复用唯一 http 出口；独立 member-address store 与资料缓存解耦
  （DEV-4），reset 防跨账号脏数据；仅设默认乐观化（AC-022 唯一即时性要求），
  失败回滚后强拉保证最终一致；弹层错误不关层、删除 window.confirm 二次确认。
- **Deviations 复核**：
  - 后端 DEV-1 由真实 Flyway 红基线驱动，CASE WHEN 是标准 SQL 且 MySQL 侧唯一性等价
    （有 UNIQUE 物化论证）；DEV-2 严格回到 story SSOT 128，前后端同步；DEV-3 以前端对齐
    已落地控制器与 story-design；DEV-4 主动登记 H2/MySQL 并发差异到 M3 Test 而非掩盖；
    DEV-5 为测试库方言适配，不改生产 DDL 方向。
  - 前端 DEV-1 第三次沿用既定无 DOM 测试架构（既有 9 spec 全无挂载），未新增依赖；
    DEV-2/3 均为对齐后端 SSOT 与实际端点；DEV-4 状态归属划分有清晰生命周期理由，
    store spec 对强拉/回滚/乐观时点断言充分。
  - 九项三要素齐全，未发现未记录偏离。

### 1.3 跨仓一致性（Phase 2.4）

- 两仓 DU 均 completed：repo-1 DU-BE-604（result e6068a1…）、
  repo-2 DU-FE-603（result 6a10cdd…），baseline/result 与各自仓内
  HEAD 祖先链一致（完整 40 位 hash 见各 DU metadata.yaml）。
- 跨仓契约逐一核对：基址 `/api/mall/shipping-addresses` 六端点方法/路径全一致
  （GET 列表、POST 201、PUT /{id}、DELETE /{id} 204 空体、PUT /{id}/default、
  GET /default {item:null}）；AddressView 字段（字符串 id、无 memberId、postalCode 可 null、
  ISO 时间）↔ TS ShippingAddressView；B0201 404/B0202 409/B0203 409 中文文案 ↔
  resolveErrorMessage 透传；32/64/128/手机/邮编规则两侧常量化同值。
- 依赖面：后端仅 mall-member 变更（14 新增文件零修改既有产品类）+ V2 迁移，
  BOM/网关/其他服务零改动；前端零新增依赖、lockfile 未改。
  网关 `/api/mall/shipping-addresses/**` MEMBER 规则 DU-BE-602 已预置
  （GatewaySecurityConfiguration/application.yml/安全链测试），本 Story 首次消费，未改网关一行代码。
- 无提前消项：MySQL 真实生成列/并发 409、真实浏览器双会员链路均显式登记归 M3 Test 五集成场景。

### 1.4 代码质量

- `mvn clean package` 24 模块 BUILD SUCCESS、311 全绿；mall-member 由 44 增至 79，
  注册 relay/资料/头像等既有 44 例零失败。
- 抽查后端：Controller 不出现裸 memberId 入参（currentMemberId 复制 MemberProfileController
  模式）；Po 不含生成列（仅库派生）；Mapper COLUMNS 常量 + @Options(useGeneratedKeys)；
  端口双条件防越权；异常一律 BusinessException 带 ErrorCode/HttpStatus；
  V2 迁移含 idx_address_member(member_id,is_default,updated_at) 支撑列表排序。
- 前端四检：vitest 58/58、vue-tsc 0 错误、eslint 0 errors（133 warnings 全为已降级
  样式规则）、vite build 路由分包；乐观更新快照含 items/defaultId 两态，
  catch 中重拉再失败被吞（`.catch(()=>undefined)`）不掩盖原始 409 抛出。
- 无依据 standards 明确条文的新增违规。

### 1.5 知识同步候选

- 候选经验（供后续 Story/converge 决策，本次不沉淀）：
  1. 「H2 MODE=MySQL 既不认 MySQL 方言 IF() 也不认计算列 STORED——跨 MySQL/H2 的生成列
     用标准 CASE WHEN 且省略 STORED；UNIQUE 索引对 VIRTUAL 列物化键值，唯一性可在 H2 验证」。
  2. 「H2 2.x INFORMATION_SCHEMA.INDEXES 无 IS_UNIQUE 列，唯一性别查
     INDEX_TYPE_NAME LIKE '%UNIQUE%'；约束支持索引会自动加 _INDEX_n 后缀，断言用前缀 LIKE」。
  3. 「ECJ 增量编译在 testCompile 失败后会向 test-classes 留错误桩类致整类 Error；
     Maven 验证一律 clean test，红后尤其必须」。
  4. 「资源归属类接口统一 memberId+id 双条件，越权与不存在合并同错误码/文案（404 B0201），
     可避免资源存在性侧泄漏；删除以影响行数 0 判 404」。
  5. 「‘每聚合最多 N 条 + 恰好一个默认’两类不变量：上限放写前 count（可前置 409），
     唯一默认放同事务清理+数据库生成列唯一索引双保险，DuplicateKey 显式转业务 409」。
  6. 「前端列表类页面排序信任后端、写后强拉；仅对有即时反馈要求的单一动作（设默认）做乐观
     更新，快照必须含全部本地态且失败后强制重拉再 rethrow」。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| — | — | — | 无开放发现（dev 期后端五处、前端两处失败均已在开发期闭环并记入各 DU red-green.md 与 DEV） | — |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/质量 + 知识候选）
- [x] 无未闭环 blocker/major/minor
- [x] Deviations 三要素齐全且经复核合理（后端 DEV-1~5、前端 DEV-1~4）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（两仓 DU completed、result commit 回填、六端点契约/字段/错误码/同界常量逐一对齐、依赖与 lockfile 面已核、网关零改动）
- [x] 追踪链 AC→TC→EVD 完整，红绿灯证据可追溯
