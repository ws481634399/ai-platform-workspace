# Review Report — 会员资料维护 STORY-003-01-02-01

> 阶段：sdd-review 产物（同态检查点，状态保持 testing）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Test Report 来源：`商城前台/商城会员/会员资料/会员资料维护/evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-010/013 code-change、EV-012/015 test-run、EV-011/014 evidence-ref）
- 检查时间：2026-09-15T17:30:00+08:00

## 1. 检查结论

无开放 blocker/major/minor。后端 dev 期五处真实失败（授权 500、MockMvc multipart 边界、
seed 无 eventId、SDK 响应构造、邮箱边界夹具）与前端三处（邮箱夹具、TS6133、SFC no-undef）
均在开发期闭环并留 red→green 证据；八片 Deviations 理由均成立（后端 DEV-1~5、前端 DEV-1~3，
详见 §1.2）。

### 1.1 需求一致性

| AC | test-run 证据（EV-012 covers AC-016~018；EV-015 covers AC-016~018/025） | 结论 |
| --- | --- | --- |
| AC-016 | TC-001/TC-003：GET /me 字符串 memberId 六字段；memberId 无入参仅取 subject（Long.parseLong 非法 401）；懒补偿确定性 UUID v3 重建幂等、seed 不一致 401 B0101；前端 memberId 只读展示 | passed |
| AC-017 | TC-002：昵称 1–32/手机 ^1[3-9]\d{9}$/邮箱 ≤128 宽松正则/性别枚举，空昵称 33 字坏手机坏邮箱坏 gender 全 400；PUT 无 memberId 入参；前端同界字段错误 + 400 文案透传 + 失败不污染缓存 | passed |
| AC-018 | TC-004/TC-005：魔数三格式 200 公开 URL 落库；伪装 GIF/2.1MB 400 且存储零调用（服务端不信文件名/MIME，扩展名重算）；存储故障 503 S0102 不写半成品；前端预拦截+预览+成败双色提示 | passed（真实 MinIO 上传/桶公开读/9000 不通 503 随 M3 Test，§4 已登记） |
| AC-025 | TC-006：mall-web 个人中心查看/修改全流程切片 15 例 + 四检全绿（37/37、0 类型错误、0 lint errors、build 分包），requiresMember 守卫 + 布局入口 | passed（真实浏览器流程随 M3 Test） |

4 条 AC 均被 covers 包含其的 test-run 条目覆盖，追踪链 AC→TC（6 条）→测试方法→DU evidence 无断链。

### 1.2 设计一致性（Design → DU → Implementation）

- **资料聚合与部分更新**：MemberProfile 不变量内聚（昵称非空白 ≤32、手机/邮箱可 null、
  性别非 null、avatarUrl ≤512）；合并语义 null=保留/空白=清空/非空 trim 在应用层归一，
  与 story-spec §3「空值允许清空」一致；Mapper UPDATE 用 NOW(6) 不传客户端时间。
- **头像安全链**：大小先于魔数、魔数先于存储——任一拒绝路径 verifyNoInteractions(AvatarStorage)
  有用例锁定；contentType/扩展名由 AvatarFormat.detect 魔数重算，对象 key 为
  `member-avatar/{memberId}/{UUIDv4}.{ext}`，不含客户端文件名（路径穿越/覆盖他人隐患闭合）。
- **懒补偿幂等**：确定性 UUID v3 事件 ID 同会员恒定 + provision existsByMemberId 双幂等；
  seed 404/401→401（不静默造档），其他故障/连接失败→503（可重试，不泄露身份侧细节）。
- **MinIO 故障隔离**：MinioClient bean 构造无网络；桶懒就绪不阻断启动（DEV-2，落实
  requirement-design §7）；ensure 失败不置 ready 下次全量重试，建桶竞态二次 bucketExists 消化；
  putObject 成功语义为「bucketExists 成功即 ready，put 失败不重置」（后续直 put 重试）。
- **授权双层**：方法级 @PreAuthorize + 路径层 /api/mall/** hasRole MEMBER（生产与测试链同改），
  advice 再兜 AccessDeniedException→403；与网关注入的 ROLE_MEMBER 语义一致，
  SERVICE token 经 /api/internal/** 独立规则不受影响。
- **前端架构**：API 复用唯一 http 出口（Bearer/401 单飞自动覆盖新端点）；资料态并入既有
  member store（不另起 store），成功整体替换/失败不污染；校验常量与后端同界（32/2MB/正则）；
  PUT 仅发 diff 字段（DEV-3），空串清空语义与后端契约对齐。
- **Deviations 复核**：
  - 后端 DEV-1 解决真实契约缺口（seed 无 eventId），确定性 v3 为 RFC 4122 合法 UUID 且
    CHAR(36) 兼容，幂等性有落库断言；DEV-2 落实设计已有的风险裁决，非削弱行为；
    DEV-3/4 均由真实 500/400 红基线驱动，双道/双层都是更安全失败方向；DEV-5 有 spec
    「由设计定」授权且无空窗。
  - 前端 DEV-1 沿用 DU-FE-601 既定测试架构（6 个既有 spec 全无 DOM），未新增依赖；
    DEV-2 为 typescript-eslint 官方对 TS 的明确建议，仅 .vue 生效且 tsc 兜底；
    DEV-3 失败保留预览改善可重试性，卸载统一 revoke 无泄漏。
  八项三要素齐全，未发现未记录偏离。

### 1.3 跨仓一致性（Phase 2.4）

- 两仓 DU 均 completed：repo-1 DU-BE-603（baseline cefbfb7…/result 8c5a1e6…）、
  repo-2 DU-FE-602（baseline d54a6b7…/result c20c24c…），baseline/result 与各自仓内
  HEAD 祖先链一致（逐仓 hash 见 DU metadata.yaml）。
- 跨仓契约逐一核对：GET/PUT `/api/mall/members/me` 字段六件
  （memberId/username/nickname/avatarUrl/gender/phone/email）与 TS MemberProfile 对齐；
  POST `/api/mall/members/me/avatar` multipart part=file ↔ 后端 @RequestPart("file")；
  错误码 A0101/A0102/S0102 中文文案 ↔ resolveErrorMessage 透传链；性别 UNKNOWN/MALE/FEMALE
  ↔ MemberGender 联合类型；null/空串语义两侧一致。
- 依赖面：mall-bom 登记 minio 8.5.17 后 24 模块全量依赖收敛成功；前端零新增依赖、
  lockfile 未改。网关 /api/mall/members/** 路由与角色由 DU-BE-602 预置，本 Story 首次消费，
  未改网关一行代码。
- 无提前消项：真实 MinIO/两进程/浏览器链路均显式登记归 M3 Test 五集成场景。

### 1.4 代码质量

- `mvn clean package` 24 模块 BUILD SUCCESS、276 全绿；bom/member 变更回归面
  （注册 relay/internal provision 10 例既有、identity 79、gateway 19）零失败。
- 抽查后端：ProfileApplicationService 纯 Mockito 11 例无 Spring 上下文，顺序/零调用可验证；
  MinioAvatarStorage ready 标志 volatile + synchronized 双重检查；异常一律转
  BusinessException 带 ErrorCode/HttpStatus，不向接口层泄漏 SDK 类型；配置全走
  @ConfigurationProperties/env 占位无硬编码密钥。
- 前端四检：vitest 37/37、vue-tsc 0 错误、eslint 0 errors（92 warnings 全为
  eslint.config.js 已降级样式规则）、vite build 路由分包；objectURL 成对 revoke
  （成功后与 onBeforeUnmount）；File input 失败后清空 value 允许重选同名文件。
- 无依据 standards 明确条文的新增违规。

### 1.5 知识同步候选

- 候选经验（供后续 Story/converge 决策，本次不沉淀）：
  1. 「Spring Security 方法级 @PreAuthorize 的拒绝在 DispatcherServlet 内抛出，
     @ControllerAdvice 的 Exception 兜底会先于 ExceptionTranslationFilter——凡有全局兜底
     advice 的服务，授权 403 需路径层规则或局部 AccessDeniedException 映射双保险」。
  2. 「MockMvc multipart 绕过 Servlet 容器大小解析，上传限制必须在应用层显式校验，
     容器 MaxUploadSizeExceededException 只覆盖真实 Tomcat 路径」。
  3. 「跨服务补偿缺事件 ID 时，nameUUIDFromBytes 派生确定性 UUID v3 是幂等键的轻量解法
     （命名空间前缀隔离用途），配合目标侧唯一约束形成双幂等」。
  4. 「MinIO/S3 客户端 bean 构造无连接，桶策略应懒就绪——基础设施离线不应成为
     不相关主链（登录/注册）的启动硬依赖」。
  5. 「ESLint flat config 下 vue SFC 的 TS 虚拟文件不享受 TS 源文件的 no-undef 豁免，
     官方做法是对 **/*.vue 关 no-undef 交 vue-tsc」。
  6. 「邮箱长度边界夹具：总长 128 = local 123 + '@b.cn' 5；前后端同型陷阱已踩两次」。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| — | — | — | 无开放发现（dev 期后端五处、前端三处失败均已在开发期闭环并记入各 DU red-green.md 与 DEV） | — |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/质量 + 知识候选）
- [x] 无未闭环 blocker/major/minor
- [x] Deviations 三要素齐全且经复核合理（后端 DEV-1~5、前端 DEV-1~3）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（两仓 DU completed、result commit 回填、三端点契约字段/错误码/性别枚举逐一对齐、依赖与 lockfile 面已核）
- [x] 追踪链 AC→TC→EVD 完整，红绿灯证据可追溯
