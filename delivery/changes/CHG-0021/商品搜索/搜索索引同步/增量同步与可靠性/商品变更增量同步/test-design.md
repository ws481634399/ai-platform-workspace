# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-01
- Feature Path: 商品搜索 > 搜索索引同步 > 增量同步与可靠性 > 商品变更增量同步
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成（product+search+ES）：上架/新建上架商品事务提交后，5s 轮询搜索接口可检出（UPSERT） | AC-001 | DU-BE-505 | Integration Gate 场景一 |
| TC-002 | 集成：改名/改分类品牌/换主图提交后 ES 文档字段更新；SKU 改价后 minPrice/maxPrice 刷新 | AC-002 | DU-BE-505 | Integration Gate 场景二/四 |
| TC-003 | 集成：下架后文档硬删除（GET doc 404、搜索不可见）；重复下架/删除不存在 id → 200 幂等 | AC-003 | DU-BE-505 | Integration Gate 场景三 |
| TC-004 | 集成：add ENABLED SKU 抬高高价极值/禁用唯一低价 SKU 后摘要正确；商品最后启用 SKU 被禁用 → 文档删除/不可搜 | AC-004 | DU-BE-505 | [S1] |
| TC-005 | 集成：停 mall-search，调上架接口仍 200 且商品落库；product 日志含 WARN；恢复服务不影响已提交事务 | AC-005 | DU-BE-505 | Integration Gate 场景五 |
| TC-006 | 单测：@TransactionalEventListener AFTER_COMMIT——事务回滚（校验失败）不推送；提交后推送；7 写方法 op 映射正确（下架类 DELETE） | AC-006 | DU-BE-505 | [S1] |
| TC-007 | 安全：POST /api/internal/search/products/sync 无 SERVICE 凭据 401/403；经网关访问内部路径 404 | AC-007 | DU-BE-505 | [S1] |
| TC-008 | API：sync 端点正常 upsert 返回 200 {accepted:true}；DELETE 不存在 id 200 幂等 | AC-003 | DU-BE-505 | [S1] |
| TC-009 | 单测：SearchSyncClient 超时配置（connect 1s/read 3s）通过配置断言/短超时候选地址验证 | AC-005 | DU-BE-505 | [S1] |

## 2. 测试策略

- 事件链路用 Spring 事件测试（@Transactional + 监听器捕获），不真发 HTTP；
- 端到端行为（改动能搜到）以 testcontainers 双服务+ES 集成或 Integration Gate 为准，dev 阶段至少保证 product 侧事件测试与 search 端点 MockMvc，跨服务链路进 E2E evidence。
- ES 故障窗口由 STORY-02 的 failure_record 机制兜底，本 Story 验证"主事务不阻断"。

## 3. 不可测项标注

- 跨服务真实 HTTP 链路在 dev 单仓内以 Integration Gate E2E 为准（同 repo-1 双模块本地联调可先行）。

## 4. 依赖与前置条件

- DU-BE-503（投影/端点）；SearchSyncApplicationService 与 BE-506 同迭代落地。
