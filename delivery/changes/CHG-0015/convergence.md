# Convergence — CHG-0015 M3 前置就绪修复

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0015
- 完成时间：2026-09-15T20:20:00+08:00
- standards-need-update：yes
- product-need-update：no
- featuretree-need-update：no
- glossary-need-update：no

## 1. 知识变化总结

本 Change 为 M3 功能开发前的跨切面就绪修复（不新增业务能力），沉淀两条可跨 Change 复用的技术规则：

1. **业务 ID 字符串出参约定**：64 位雪花 ID 超过 JS 安全整数，统一 `@StringId` 出参字符串化、入参保持 Long；金额/数量/分页保持 number。
2. **服务间内部端点隔离模式**：`/api/internal/**` 独立共享凭证（X-Internal-Token）、JWT 不通内部、网关 denyAll 对外 404 同构体、白名单最小显式。

无新业务术语、无新业务规则、无新增/变更能力节点（Story 沿用 CHG-0012 已 delivered 的商城查询节点）。

## 2. 更新判断

### Standards 晋升

- 文件：`standards/engineering/backend/api-design-standard.md`
- 操作：新增 §5.3「业务 ID 序列化（字符串出参）」
- 内容：@StringId 组合注解统一出参、入参保持 Long 双形态兼容、仅业务 ID 字符串化、自增/雪花一视同仁、前端禁 Number 转换与 local-n 临时键约定
- 理由：雪花 ID 精度问题是跨语言系统级约束；CHG-0016/17/18（会员地址、商品浏览、购物车）新增接口全部面对同一约束
- 复用场景：未来所有携带雪花 ID 的对外 DTO 与 mall-admin/mall-web 消费端

- 文件：`standards/security-guidelines.md`
- 操作：「认证与授权」段新增「服务间内部端点隔离」小节
- 内容：内部凭证独立、JWT 与内部身份不互通、网关 404 同构外拒、白名单最小化、常量时间比较
- 理由：会员/购物车等后续 Change 将新增更多服务间调用（地址、库存、商品快照），需统一内外网隔离基线
- 复用场景：所有 `/api/internal/**` 端点与网关路由配置

### Spec 晋升候选

无。本 Change 不新增长期产品行为约束（修复前后业务行为不变，仅修正 ID 表现形态与数据正确性）。

### Feature Tree 更新

不需要。STORY-002-03-02-01 节点已在 CHG-0012 交付时置为 delivered，本 Change 是其就绪修复，不新增能力节点。

### Glossary 更新

无。未引入新领域概念（「内部凭证」「字符串 ID」为技术实现术语，不进业务术语表）。

### No Update

- @StringId 注解的具体实现类位置、InternalIdentityFilter 的过滤器顺序、各服务 application.yml 配置键名：实现细节。
- 冒烟品牌/分类自增 ID、商品雪花 ID 等具体数据：一次性验证数据。
- 网关白名单当前具体路径清单：随 Change 演进，已在代码与安全标准（最小化原则）中表达。

## 3. 知识沉淀过程

- 按 sdd-knowledge 能力 A 对 spec/design/DU implementation/test-report/review-report 全量提取，候选 2 项技术规则。
- 检索既有 standards：coding-standards、api-design-standard、security-guidelines、backend/architecture-standard §5.3 均无对应条文（命中仅为「SQL 字符串拼接」等无关内容），判定为新增而非合并。
- 两条规则分别落入 `standards/engineering/backend/api-design-standard.md §5.3` 与 `standards/security-guidelines.md`，均标注来源 CHG-0015 与验证要点。
- 按能力 C 重建/核对 `standards/INDEX.md` 与 `.sdd/knowledge-index.json`（既有文件章节更新，索引条目仍有效）。
- 无 Conflict；review EV-012 已闭环，无 Unresolved 项。

## 4. 全局验收标准对照

| AC | 验收点（story-spec §5） | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 网关匿名商品列表 200 | EV-005/EV-009，冒烟 | 通过 |
| AC-002 | 网关匿名详情 200；不可售 404 | EV-003/EV-009 | 通过 |
| AC-003 | /api/internal/** 外网拒绝 | EV-002/EV-005/EV-009 | 通过 |
| AC-004 | 库存初始化真实 SKU 成功 | EV-004/EV-009，冒烟 | 通过 |
| AC-005 | 库存分页 total 准确 | EV-004/EV-009 | 通过 |
| AC-006 | 商品 id 字符串不丢精度 | EV-001/EV-009，冒烟 | 通过 |
| AC-007 | 五域业务 ID 全字符串 | EV-001～EV-008/EV-009（EV-012 闭环） | 通过 |
| AC-008 | 入参双形态兼容 | EV-001/EV-009 | 通过 |
| AC-009 | 真实价区整数分无 null | EV-003/EV-009 | 通过 |
| AC-010 | 无启用 SKU 商品过滤 | EV-003/EV-009 | 通过 |
| AC-011 | mall-admin 五页面零回归 | EV-007/EV-008/EV-009 | 通过 |
| AC-012 | skuId 原样回传无偏差 | EV-009，404 反证（EV-012 闭环） | 通过 |

追踪链：12 AC ↔ 14 TC ↔ EV-001～EV-012，无断链；21 任务中本 Change 2 DU（其余 19 DU 属 CHG-0016/17/18，不在本 Change 范围）。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取（含两仓 DU 证据）
- [x] 知识分类完成（2 项 standards 新增，其余 no-update）
- [x] standards 更新已写入（2 处，带来源与验证要点）
- [x] 无 Spec 晋升候选（本 Change 无新业务规则）
- [x] Feature Tree 无需更新（节点已 delivered）
- [x] 索引已核对
- [x] 两个 DU 均 completed 且 result commit 与各仓 HEAD 对齐
- [x] 无未解决 Conflict、blocker 或 major finding（EV-012 已闭环）
