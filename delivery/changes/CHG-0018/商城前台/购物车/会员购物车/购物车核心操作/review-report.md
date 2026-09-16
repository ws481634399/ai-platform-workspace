# Review Report — STORY-003-03-01-01 购物车核心操作

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-01-01
- 审查对象：DU-BE-801（repo-1：mall-cart / mall-product / mall-gateway）
- 审查时间：2026-09-16
- 审查者：trae-agent
- 测试报告来源（test-report-source）：`evidence/test-report.md`（mall-cart 23/23、product 95/95、gateway 19/19 + 真实环境 E2E）

## 1. 检查结论

**通过（PASS）。** 购物车写模型实现符合 story-design/requirement-design 契约：

- 四段 Lua 脚本承担全部并发正确性（HEXISTS 合并累加、HLEN 条目上限、HSET 数量兜底、SINGLE/ALL 选择、
  key 存活才续期），应用层与脚本返回码一一映射，无应用层 read-modify-write 竞态窗口；
- 加购可售性先校验后写车（product ON_SALE + sku ENABLED 双状态），不可售/故障严格区分 400/503，
  且全部失败路径在原子写之前，车内容绝不被失败请求污染；
- memberId 仅从安全上下文取得，请求体无 memberId 入口；内部端点与会员端点双过滤器链隔离，
  网关对 `/api/internal/**` denyAll（对外表现 404，不暴露存在性）；
- 零库存锁定调用（AC-014）经 pom 依赖审计与代码走查确认；
- 真实 jar + Docker infra 端到端覆盖加购合并/不可售/鉴权/网关收口/M4 读取/Redis 结构与 TTL。

开发期暴露的 5 个问题（RED-1~5，见 red-green.md）全部在开发期闭环并留守护测试，最终审查未发现
遗留 blocker / major。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | ProductRepositoryImpl 初版先按 PO 分组再末端转域，泛型推断编译失败 | 已修复（ebfbeb2）：图片/属性/SKU 在 groupingBy 时即 mapping 转领域模型；95 例全绿 |
| F-002 | minor | 内部端点权限语义初判为 403，实测 InternalIdentityFilter 对 internal 路径短路返回 401 INTERNAL_UNAUTHORIZED | 已对齐（ebfbeb2）：测试期望与用例名固化 401 语义，与 mall-member 既有行为一致 |
| F-003 | minor | Jayway `$..[?(...)].length()` 对过滤结果逐对象取字段数（实得 6）而非集合大小 | 已修复（ebfbeb2）：改用 Hamcrest hasSize 断言，语义与意图一致 |
| F-004 | info | story-spec §4 早期文字写「不存名称价格」，story-design 明确含 priceFenAtAdded 快照价 | 以 design 为准实现，DU implementation.md DEV-1 已记录偏离；快照价仅写模型留存，读模型聚合在 DU-BE-802 |
| F-005 | info | cart 服务未引 actuator，/actuator/health 经包装返回 500 | 不影响业务与门禁；健康端点统一化留后续基础设施 Story |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 上限常量（100 条目 / 999 数量）仅由 Lua 在原子段判定，应用层无旁路写入口 | 通过（CartConstants 单点 + 仓储端口唯一写路径，TC-002/TC-004） |
| 滑动 TTL：所有写操作对存活 key 续期；空车不被 remove/select 重建 | 通过（TC-001/TC-011；remove 脚本 EXISTS 守卫） |
| 加购失败不脏车：不可售/非法参数在 Redis 写前返回；503 依赖故障语义独立 | 通过（TC-003，B0303 与 S0301/S0302 分离） |
| 会员隔离与越权 | 通过：memberId 仅取 SecurityContextFacade；类级 MEMBER；ADMIN 403（TC-007） |
| M4 预留内部端点 | 通过：selected-items 仅 SERVICE 凭证；会员 JWT 401；网关 404（TC-009） |
| product sku/batch 契约 | 通过：≤100 去重保序、缺失占位 salable=false、双状态、@StringId 字符串 ID（TC-010） |
| 网关路由/鉴权收口 | 通过：/api/mall/cart/** MEMBER + 8104 路由；19/19 无回归 |
| 不锁库存边界（AC-014） | 通过：mall-cart 无 inventory 依赖与调用路径（TC-008） |
| 金额/ID 口径 | 通过：priceFen 整数分；雪花 ID 全线字符串传输，RestClient 入参 parseLong 兼容 |
| 自动化与构建 | 通过：mall-cart 23/23、mall-product 95/95、mall-gateway 19/19、三模块 package 成功 |
| 真实环境 | 通过：§test-report §4 全链路实测，测后清理测试数据 |

证据索引（evidence-index）：Story `evidence/evidence.yaml` EV-001~EV-004，
repo-1 DU evidence/（changeset/commits/red-green/logs）。

## 4. Deviations

- DEV-1：story-spec §4 与 story-design 关于是否保存快照价的文字不一致，按 design 实现 priceFenAtAdded；
  本 Story 写模型不对外回传价格，实时价聚合属 DU-BE-802 范围。
