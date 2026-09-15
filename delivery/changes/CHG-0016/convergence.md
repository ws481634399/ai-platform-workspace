# Convergence — CHG-0016 商城会员与地址

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0016
- 完成时间：2026-09-21T19:30:00+08:00
- standards-need-update：yes
- product-need-update：yes（Spec 晋升候选 1 篇，待人工评审；不直接落 product/specs/）
- featuretree-need-update：yes（4 个 Story planned → delivered）
- glossary-need-update：no

## 1. 知识变化总结

本 Change 交付商城会员域全部 4 个 Story（注册 / 登录与会话 / 会员资料 / 收货地址）、7 个 DU
（repo-1 四个、repo-2 三个），确立五类可跨 Change 复用的技术规则与一组长期产品业务规则：

1. **会员 JWT 双令牌会话模型**：refresh family 旋转、重放整族撤销、auth_version、
   body+cookie 双渠道、前端 401 单飞重放、redirect 白名单——CHG-0017/18 全部会员态页面直接继承。
2. **授权与上传两条安全链**：方法级 @PreAuthorize 与全局兜底 advice 的执行序坑及双层收口；
   头像/文件上传的魔数嗅探、双道大小限制、对象 key 服务端生成、对象存储懒就绪与 503 隔离。
3. **跨服务数据同步 Outbox-Lite 模式**：事务内 outbox + afterCommit 投递 + 定时补偿，
   消费端事件 ID 唯一约束 + existsBy 双幂等，契约缺事件 ID 时确定性 UUID v3 派生。
4. **私有资源归属与聚合写约束**：ownerId+id 双条件、越权/不存在同构 404；
   上限写前 count 拦截、唯一默认生成列 + UNIQUE 双保险——直接适用于购物车/订单/收藏。
5. **两条工程验证约定**：H2/MySQL 生成列 DDL 兼容写法与 H2 元数据/ECJ 桩类坑；
   前端 vitest 纯逻辑切片测试形态（node 环境不挂 DOM，交互归浏览器集成）。

新业务能力：FEAT-003 商城会员下注册、登录会话、资料维护、收货地址四个 Story 节点
全部交付（Feature Tree 置 delivered）。无新业务术语表条目（会员/地址为通用领域概念，
已由 Feature Tree 节点承载；workspace 当前无 glossary 目录，不为此单建）。

## 2. 更新判断

### Standards 晋升

- 文件：`standards/security-guidelines.md`
- 操作：「认证与授权」段新增两小节 + 新增「文件上传与对象存储」顶级段
- 内容：①「会员 JWT 双令牌会话（access + refresh family）」——family 旋转与重放整族撤销
  （REQUIRES_NEW）、auth_version 失效、body/HttpOnly cookie 双发、前端 401 单飞重放、
  redirect 白名单防开放重定向；②「授权失败双保险」——@PreAuthorize 拒绝被全局
  Exception 兜底吞成 500 的执行序原理，路径层 hasRole + 方法级 + advice 显式 403；
  ③ 文件上传段——双道大小限制、魔数嗅探、服务端 UUID key、MinIO 懒建桶与 503 隔离、
  覆盖上传不删旧对象。
- 理由：会话与授权模式将被 CHG-0017（商品浏览会员态）、CHG-0018（购物车）原样继承；
  上传规则适用于后续商品图片等所有用户上传场景。均为系统级安全约束，非本 Change 实现细节。
- 复用场景：所有 /api/mall/** 会员态端点、mall-web http 客户端与路由守卫、全部文件上传链路。

- 文件：`standards/engineering/backend/framework-standard.md`
- 操作：§5 消息系统新增「5.4 跨服务数据同步：Outbox-Lite 与双幂等」
- 内容：事务内 outbox + afterCommit 即时投递 + 定时扫描补偿（禁业务事务内远程调用）；
  消费端确定性事件 ID 唯一约束 + existsBy 双幂等；上游缺事件 ID 时
  nameUUIDFromBytes 派生 UUID v3（用途前缀隔离）；404/401 与 5xx 失败语义分级。
- 理由：本 Workspace 无独立 MQ，服务间同步均会复用该轻量模式（订单→库存/营销快照等）。
- 复用场景：所有「主库提交后必须通知对端服务」的跨服务写链路。

- 文件：`standards/engineering/backend/api-design-standard.md`
- 操作：§10 接口安全新增「资源归属与聚合写约束（CHG-0016 晋升）」
- 内容：ownerId 只取认证主体、Repository 默认双条件、越权与不存在同构 404 防存在性侧泄漏；
  上限写前 count → 409；唯一默认生成列 + UNIQUE 双保险、DuplicateKey 显式转业务码；
  写后重查返回、排序在 Mapper 固定。
- 理由：购物车、订单、收藏等私有资源面对完全相同的归属/上限/默认语义，需统一接口范式。
- 复用场景：所有按资源 id 操作会员私有数据的 REST 端点。

- 文件：`standards/engineering/testing-standard.md`
- 操作：§13.5 补充 H2 并发串行化容忍条款；新增「13.6 H2 对 MySQL 生成列 DDL 的兼容写法」
  「13.7 ECJ 增量编译残留错误桩类」
- 内容：CASE WHEN 省略 STORED、H2 INDEXES 无 IS_UNIQUE/约束索引 _INDEX_n 后缀实测、
  冲突文案小写断言；testCompile 失败后须 clean test；H2 并发用例容忍串行化结局并标注
  真实 MySQL 集成复验。
- 理由：CHG-0016 五处真实红基线中的三处环境类问题，后续任何生成列 DDL 与 H2 测试都会再遇。
- 复用场景：mall-* 全部服务 Flyway + H2 测试库、唯一约束并发用例。

- 文件：`standards/engineering/frontend/coding-standard.md`
- 操作：新增「15. 单元测试形态约定：逻辑切片优先（CHG-0016 晋升）」
- 内容：可测逻辑下沉 api/utils/stores 三层；默认 node 环境不引 happy-dom/@vue/test-utils；
  SFC 靠 vue-tsc 双 tsconfig + vite build 兜底；vi.hoisted mock 唯一 http 出口、
  每例 setActivePinia；乐观/回滚/强拉的替代断言模式；引入 DOM 栈须经 lockfile 评审。
- 理由：DU-FE-601/602/603 连续三个 DU 验证了该形态（12 spec/58 例零 DOM 依赖），
  需固定为 mall-web/mall-admin 的默认测试架构，防止后续 DU 随意加依赖。
- 复用场景：mall-web/mall-admin 全部页面级功能的前端测试。

### Spec 晋升候选（人工评审后落 product/specs/）

- 文件：`product/specs/商城会员.md`（评审通过后创建）
- 操作：新增
- 内容（草稿，来源 requirement-spec.md §4，经 4 Story 实施与 311+58 测试验证成立）：
  - 标识：用户名 4–20 位（字母开头，字母/数字/下划线），大小写不敏感归一全局唯一，
    注册后本期不可改；密码 8–32 位含字母与数字，BCrypt 存储，任何日志/响应禁明文。
  - 注册一致性：Identity 建账号与凭据单事务原子；MemberRegistered 事件按 eventId+memberId
    双幂等初始化 Profile；初始化失败由重试任务与登录时缺档补偿两条路径兜底。
  - 登录：用户名归一查询；凭据错误统一文案不可区分；账号停用显式拒绝文案；
    签发双令牌且 memberId 以字符串承载。
  - 资料归属：会员资料/地址的 memberId 一律取自认证主体，请求体 memberId 忽略；
    访问他人资源 404 同构，不暴露存在性。
  - 收货地址：收货人 1–32 字；手机须大陆手机号格式；省/市/区必填 1–64、详址 1–128；
    邮编选填 6 位数字；每会员 ≤20 条；首条自动默认、设默认单事务清旧立新、
    删除默认后无默认（不自动重选）、查无默认返回空。
  - 头像：单文件 ≤2MB，仅图片，服务端魔数判定；对象存储不可用时上传失败但不影响其他功能。
- 理由：上述为长期产品行为约束（做什么），不是实现细节；CHG-0017/18 及订单履约类 Change
  在引用会员地址/默认地址时需要稳定的产品依据。
- 来源：requirement-spec.md「§4 业务规则总纲」全部 10 条 + 各 story-spec AC 验证结果。

### Feature Tree 更新

- 节点：STORY-003-01-01-01 商城会员注册 / STORY-003-01-01-02 商城会员登录与会话 /
  STORY-003-01-02-01 会员资料维护 / STORY-003-01-03-01 收货地址管理
- 操作：状态变更 planned → delivered（4 节点，全部 Story 下 DU 已 completed 且三阶段门禁通过）
- 方式：`openspec feature update <STORY-ID> --status delivered`（已执行）

### Glossary 更新

无。会员、收货地址、默认地址为电商通用领域概念且已由 Feature Tree 节点名称承载；
「refresh family」「生成列默认唯一」为技术实现术语，已进 standards，不进业务术语表。
workspace 目前无 glossary 目录，不为本 Change 单建。

### No Update

- 六端点的具体 JSON 字段、错误码号段 B0101/B0201~B0203 的具体编号、V2 表的列定义：
  实现细节，已在代码与 story 设计文档中表达，不具跨 Change 规则价值。
- MinIO endpoint/桶名、JWT 过期时长、刷新阈值等配置值：环境配置，走 application.yml
  与 local-infrastructure-standard，不进长期规则。
- 各 DU 具体 Deviations（H2 断言命名、TS mock 返回类型、邮箱/详址边界夹具长度等）：
  一次性踩坑记录，其中可复用的环境类经验已抽象进 testing-standard，其余留在 DU red-green.md。
- 前端 data-testid 命名清单：页面实现细节，联调时按页定位即可。

## 3. 知识沉淀过程

- 按 sdd-knowledge 能力 A 通读 4 Story 全部 Artifact（requirement/exploration/spec/design、
  4 套 story-spec/design/test-design、7 个仓内 DU 的 implementation/evidence、
  4 份 Story test-report/review-report、change evidence EV-001~021），提取技术候选 7 组、
  业务规则候选 1 组。
- 检索既有 standards（含安全、后端四件套、前端五件套、测试规范）：
  JWT 基础/内部端点隔离/H2 大小写/消费者幂等/方法级授权 403 已有覆盖 → 本次仅补未覆盖部分
  （family 旋转、上传链、Outbox-Lite 全貌、归属双条件、生成列/ECJ、前端测试形态），
  全部以追加新章节/小节方式合并，未改写既有条文，无 Conflict。
- Spec 候选按要求只在本文件起草（§2），未直接写 product/specs/，等待人工评审。
- 按能力 C 核对 `standards/INDEX.md` 与 `.sdd/knowledge-index.json`：本次均为既有文件的
  章节追加，索引条目（文件级）仍有效，无需重建结构。
- 无 Unresolved 问题；四个 Story 的 review-report 均无 blocker/major/minor 开放项。

## 4. 全局验收标准对照

| AC | 验收点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 合法注册 201 可立即登录，无明文外泄 | EV-001/EV-003，注册 story test-report TC-001 | 通过 |
| AC-002 | 重复用户名（含大小写变体）409 不重复建档 | EV-001/EV-003，TC-002 | 通过 |
| AC-003 | 用户名/密码不合规 400 字段提示 | EV-001/EV-003，TC-003 | 通过 |
| AC-004 | 注册后 member 侧 Profile 一致、默认昵称 | EV-001/EV-002/EV-003，TC-004 | 通过 |
| AC-005 | 注册事件重放仅一份 Profile（双幂等） | EV-001/EV-003，TC-005 | 通过 |
| AC-006 | 初始化失败可重试/登录补偿 | EV-001/EV-003，TC-006 | 通过 |
| AC-007 | 失败无半成品，可重新注册 | EV-001/EV-003，TC-007~009 | 通过 |
| AC-008 | 登录双令牌，subjectType=MEMBER/sub=字符串 memberId | EV-004/EV-005，登录 story test-report | 通过 |
| AC-009 | 错误凭据统一文案不可区分 | EV-004/EV-005 | 通过 |
| AC-010 | 停用账号 403 显式文案 | EV-004/EV-005 | 通过 |
| AC-011 | refresh 换新双令牌；旧 refresh 旋转失效；过期/伪造 → 401 | EV-004/EV-006，登录 story test-report | 通过 |
| AC-012 | 退出后双令牌失效，再访问私有接口 401 | EV-004/EV-006 | 通过 |
| AC-013 | MEMBER→/api/admin 与 ADMIN→/api/mall/members/me 越界均 403 | EV-004/EV-006 | 通过 |
| AC-014 | 刷新页面登录态恢复；access 过期并发请求单飞刷新并重放 | EV-007/EV-009 | 通过 |
| AC-015 | 刷新也失败 → 清理登录态跳登录，登录后回跳原页 | EV-007/EV-009 | 通过 |
| AC-016 | GET /me 字符串 memberId 六字段 + 缺档懒补偿 | EV-010/EV-012/EV-013/EV-015，TC-001/003 | 通过 |
| AC-017 | PUT 部分更新同界校验 | EV-010/EV-012/EV-013/EV-015，TC-002 | 通过 |
| AC-018 | 头像魔数/2MB/503 隔离全链 | EV-010/EV-012/EV-013/EV-015，TC-004/005（真实 MinIO 归 M3 Test） | 通过（联调项已登记） |
| AC-019 | 新增 201 首条默认 + 前端刷新徽标 | EV-016/EV-018/EV-019/EV-021，TC-001/011（联调项已登记） | 通过（联调项已登记） |
| AC-020 | 列表本人隔离、排序与后端一致 | EV-016/EV-018/EV-019/EV-021，TC-002/011 | 通过 |
| AC-021 | 越权改删 404 且数据不变 + 前端 toast | EV-016/EV-018/EV-019/EV-021，TC-003/004/011（浏览器联调已登记） | 通过（联调项已登记） |
| AC-022 | 设默认唯一/并发 409/前端乐观回滚重拉 | EV-016/EV-018/EV-019/EV-021，TC-005/006/011（MySQL 真实验证归 M3 Test） | 通过（联调项已登记） |
| AC-023 | 删默认不重选，getDefault {item:null} | EV-016/EV-018/EV-019/EV-021，TC-007/011 | 通过（联调项已登记） |
| AC-024 | 字段校验 400/20 条上限 409/V2 uk 迁移 | EV-016/EV-018/EV-019/EV-021，TC-008~011 | 通过 |
| AC-025 | mall-web 工程门禁（type-check/lint/test/build） | EV-009（22 例基线）+ EV-015（37 例）+ EV-021（58 例） | 通过 |

追踪链：25 AC（AC-025 为跨 Story 前端工程门禁）↔ 34 TC（S1 9 + S2 8 + S3 6 + S4 11）
↔ 7 DU（repo-1：DU-BE-601/602/603/604；repo-2：DU-FE-601/602/603）
↔ EV-001~021（7 code-change + 7 evidence-ref + 7 test-run），无断链。
遗留联调项（不阻断 Change 收敛，统一归 M3 Test 五集成场景）：真实 MinIO 9000 上传与
不通 503、真实 MySQL 生成列 DDL 与并发设默认 409、真实浏览器双进程会员全流程与越权矩阵、
member 不可用 30s 重试、刷新 restore。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取（含 4 Story 与两仓 7 个 DU 证据）
- [x] 知识分类完成（5 个 standards 文件追加、1 篇 Spec 晋升候选、4 节点 Feature Tree、其余 no-update）
- [x] standards 更新已写入（5 处，均标注来源 CHG-0016 与验证要点，仅追加不改写）
- [x] Spec 晋升候选已按业务规则整理于 §2（商城会员.md，待人工评审，未直接落 product/specs/）
- [x] Glossary 判定无需更新（理由见 §2）
- [x] Feature Tree 四个 Story 已置 delivered（openspec feature update）
- [x] 索引已核对（文件级索引不受章节追加影响）
- [x] 7 个 DU 均 completed，result commit 与各自仓提交链一致（doctor 的历史 DU 指针提示
      为 M3 各 Change 顺序推进的既知现象，CHG-0015 收敛时同样存在，非本 Change 新增问题）
- [x] 无未解决 Conflict、Unresolved 问题或开放的 blocker/major/minor
