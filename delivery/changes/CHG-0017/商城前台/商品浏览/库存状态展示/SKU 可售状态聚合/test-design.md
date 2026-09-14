# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-03-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商品浏览 > 库存状态展示 > SKU 可售状态聚合
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 内部 API：POST /api/internal/inventory/availability 50 个 skuId → 一次批量 SQL 返回各 available；无记录行=0 | AC-015 | DU-BE-705 | SQL 计数 |
| TC-002 | 公开 API：POST /api/mall/skus/availability 多 skuId → 三态；后端日志/客户端断言仅一次 inventory 调用 | AC-015 | DU-BE-705 | 无 N+1 |
| TC-003 | 参数化阈值：available=0→OUT_OF_STOCK；1/9→LOW_STOCK；10→IN_STOCK | AC-016 | DU-BE-705 | 常量 10 |
| TC-004 | JSON 白名单断言：公开响应只有 skuId+stockStatus，不含任何精确数字 | AC-016 | DU-BE-705 | |
| TC-005 | 故障注入：inventory 5xx/超时 → HTTP 200 且条目 UNKNOWN；部分失败 partial 降级 | AC-017 | DU-BE-705 | |
| TC-006 | API：空数组、101 个、含非法 ID → 400 AVAILABILITY_BATCH_INVALID；内部端点无凭证 401 | AC-015 | DU-BE-705 | 边界/安全 |

## 2. 测试策略

- Inventory：Mapper SQL 集成（total-locked 边界）。
- Product：MockRestServiceServer 模拟 inventory 成功/失败/partial；RestClient 调用计数；阈值参数化单测。
- 安全：InternalIdentityFilter 切片。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- CHG-0015（X-Internal-Token）；inventory_stock 测试数据。
