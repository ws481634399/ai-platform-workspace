# Review Report — 商城会员登录与会话 STORY-003-01-01-02

> 阶段：sdd-review 产物（同态检查点，状态保持 testing）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Test Report 来源：`商城前台/商城会员/会员注册与认证/商城会员登录与会话/evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-004/007 code-change、EV-005/009 test-run、EV-006/008 evidence-ref）
- 检查时间：2026-09-15T12:40:00+08:00

## 1. 检查结论

无开放 blocker/major/minor。后端 dev 期四处失败（构造器注入、撤销事务回滚、issuer 测试装配、
claim 断言类型）与前端两处测试断言失败均在开发闭环内修复并留有 red→green 证据；
五片 Deviations 理由均成立（后端 DEV-1~3、前端 DEV-1~2，详见 §1.2）。

### 1.1 需求一致性

| AC | test-run 证据（EV-005 covers AC-008~013；EV-009 covers AC-014~015） | 结论 |
| --- | --- | --- |
| AC-008 | TC-001：双 Token body+cookie、memberId 字符串、JWT sub/subject_type/auth_version claim | passed |
| AC-009 | TC-002：不存在/错密码/格式非法统一 401 文案，不可区分账号存在性 | passed |
| AC-010 | TC-003：DISABLED 密码正确仍 403「账号已禁用」 | passed |
| AC-011 | TC-004/TC-005：旋转、旧 token 失效、重放整族撤销（查库）、伪造/缺失 401 | passed |
| AC-012 | TC-006：logout 撤族+auth_version+1+清 cookie，旧 refresh 401 | passed（access 陈旧端到端拒绝随 M3 Test，§4 已登记） |
| AC-013 | TC-007/TC-008：白名单与 MEMBER/ADMIN 双向 403 矩阵（网关 + identity 双层） | passed |
| AC-014 | TC-009：restore 单次恢复；并发 3×401 单飞刷新一次、三请求重放 200；Bearer/X-Trace-Id 注入 | passed |
| AC-015 | TC-010：refresh 失败集中清态一次并带 redirect 跳登录；safeRedirect 同源相对白名单；登录回跳 | passed |

8 条 AC 均被 covers 包含其的 test-run 条目覆盖，追踪链 AC→TC（10 条）→测试方法→DU evidence 无断链。

### 1.2 设计一致性（Design → DU → Implementation）

- **family 旋转模型**：32 字节 SecureRandom→Base64URL、库存 SHA-256 hex、family_id=UUID、TTL P7D、
  consume 条件 UPDATE（used_at 空+未过期+版本匹配），与 requirement-design §2.2 及 ADMIN
  RefreshSessionApplicationService 基线逐项对齐；会员侧类物理隔离，未改任何 ADMIN 代码。
- **统一凭据错误**：signIn 先做格式/长度预检（非法即走同一 401 文案分支），再 username_norm 查询、
  BCrypt matches，最后才判 DISABLED——不存在与错密码不可区分，禁用必须在密码正确后才暴露，
  与 story-design 安全语义一致。
- **接口契约**：响应体含 refreshToken+memberId（story-design §2 商城前端合同），cookie 双发
  HttpOnly+Secure+SameSite=Strict、Path=/api/auth/member、maxAge 相对时长（对齐 AdminAuthController
  现状写法）；logout 204 + Max-Age=0。
- **网关矩阵**：converter 对 subject_type ∈ {ADMIN,MEMBER} 发 ROLE_<TYPE>（未知/缺失不给角色），
  白名单/hasRole MEMBER/denyAll 404/products 公开例外与 requirement-design §4 矩阵一致；
  yml 两路由 URI 均可经环境变量覆写（MALL_GATEWAY_IDENTITY_URI/MALL_GATEWAY_MEMBER_URI）。
- **安全边界**：明文 refresh 只出参一次、库内仅摘要；cookie 限定路径；logout 非 MEMBER 主体 403；
  密钥/TTL 全部走配置占位无硬编码。
- **前端登录态架构**：http 拦截器→coordinator 单飞→member store→守卫四段与
  requirement-design §3.1 一致；协调器从 mall-admin 原样移植（inflight Promise/finally 复位/
  失败动态 import 清会话），http.spec 以 axios adapter 计划证明「3 并发 1 刷新 3 重放」。
- **前端会话策略**：access 内存 + refresh HttpOnly cookie（withCredentials），restore 整轮单次；
  与后端 cookie 属性（Path=/api/auth/member、SameSite=Strict）及 §8 裁决一致；memberId 全程
  string 不数值化（DU-FE-501 雪花纪律延续）。
- **守卫与回跳**：requiresMember/游客页纯策略函数可单测；redirect 经 safeRedirect 白名单
  （仅以单 `/` 开头且排除 `//`、`/\`），登录成功 replace 回跳，防开放重定向。
- **表单规则**：member-form 正则与后端 MemberUsername.PATTERN、MemberPasswordPolicy
  （8-32 含字母+数字）逐项一致；错误提示优先透传 UnifyResult.message（401 统一文案/409 冲突/
  403 禁用均由后端文案驱动），本地预检只做格式前置拦截。
- **Deviations 复核**：
  - 后端 DEV-1（REQUIRES_NEW）修正了移植基线的真实事务缺陷，有 200→401 的红基线实证且方向更安全；
    DEV-2（测试自动配置）仅 test classpath 生效、生产包不含，条件装配复用既有 encoder 保证密钥一致；
    DEV-3（FORBIDDEN Kind）作用于 identity 内部异常类型，既有 4 个 Kind 映射不变。
  - 前端 DEV-1（cookie 轨道而非 localStorage）依据 requirement-design §8 的明确裁决，
    与 mall-admin 实际实现同构；DEV-2（注册页并入）有 story-design §1 授权且未虚增 TC。
  五项三要素齐全，未发现未记录偏离。

### 1.3 跨仓一致性（Phase 2.4）

- 两仓 DU 均 completed：repo-1 DU-BE-602（EV-004，baseline 为 DU-BE-601 完成态）、
  repo-2 DU-FE-601（EV-007），baseline/result commit 均回填且与各自仓内 HEAD 祖先链一致
  （逐仓 hash 见各仓 DU metadata.yaml）。
- member_refresh_token 表由 DU-BE-601 V7 预先建好，本 Story 无新迁移，Mapper SQL 列名与 V7 DDL
  逐列核对一致（digest/family_id/member_id/auth_version/expires_at/used_at/revoked_at/created_at）。
- 跨仓契约两侧锁定：后端 MemberAuthController 三端点（UnifyResult 包装、memberId 字符串、
  cookie 属性）↔ 前端 memberAuthApi/auth.ts 路径、字段、withCredentials 逐一核对；
  前端切片以 mock 锁定，真实浏览器/两进程 HTTP 联调归 M3 Test 五集成场景，无提前消项。
- 前置路由为后续 DU 预置但未提前消项：/api/mall/members/** 下游 8102 端点（DU-BE-603/604）
  尚不存在，本 Story 仅在网关切片以 200 桩验证授权矩阵；前端未写任何 /api/mall/** 业务调用。

### 1.4 代码质量

- `mvn clean package` 24 模块 BUILD SUCCESS，242 测试全绿；网关 converter 与 identity 异常映射
  两处变更的回归面（CHG-0015 7 例、M1 网关/身份套件、注册 5 例）零失败。
- 抽查后端：会话服务无状态、Clock/SecureRandom 可注入（包私有测试构造器对齐 ADMIN 先例）；
  MemberUserMapper 增量 UPDATE 走原子 `auth_version = auth_version + 1`（updated_at 由
  ON UPDATE 维护）；测试断言全部按本用例唯一用户名/JOIN 过滤，延续 DU-BE-601 的共享 H2 库纪律。
- 前端四检：vitest 22/22、vue-tsc 0 错误、eslint 0 errors（56 warnings 全为 eslint.config.js
  中已降级的 Prettier 重叠规则）、vite build 路由级分包成功；访问策略为纯函数无 Vue 依赖，
  coordinator 无状态可直接单测；新增唯一依赖 vitest（devDependency，与 mall-admin 同版本 ^4.0.8）。
- 无依据 standards 明确条文的新增违规。

### 1.5 知识同步候选

- 候选经验（供后续 Story/converge 决策，本次不沉淀）：
  1. 「@Transactional 方法内先写库再抛运行时异常，写库会随回滚消失」——安全类「撤销后拒绝」
     路径需 REQUIRES_NEW 或非事务化；ADMIN refresh 链路存在同类潜在缺陷，可在后续维护性 DU
     统一处理（本次按不改 admin 原则未动）。
  2. 「不带 @Profile 的服务 bean 在 test profile 下需要的端口，宜用 test-scope 自动配置
     + @ConditionalOnMissingBean 兜底，避免逐测试类 @Import」。
  3. 「编译失败后 javac 可能残留无 -parameters 的 class，参数反射异常时先 clean test 排除脏产物」。
  4. 「单飞协调器是跨应用可复制模式：mall-admin→mall-web 第二次落地，后续如小程序端可直接
     按 utils/refresh-coordinator.ts + auth/clear-session.ts 两件套移植」。
  5. 「路由访问决策保持纯函数（无 Vue/VueRouter 依赖）可在 vitest 无 DOM 环境下穷举 redirect 矩阵，
     开放重定向防护应覆盖 `//` 与 `/\` 两种前缀」。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| — | — | — | 无开放发现（dev 期后端四处、前端两处失败均已在开发期闭环并记入各 DU red-green.md 与 DEV） | — |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/质量 + 知识候选）
- [x] 无未闭环 blocker/major/minor
- [x] Deviations 三要素齐全且经复核合理（后端 DEV-1/2/3、前端 DEV-1/2）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（两仓 DU completed、result commit 回填、V7 表结构与 Mapper 逐列一致、前后端契约核对）
- [x] 追踪链 AC→TC→EVD 完整，红绿灯证据可追溯
