# Review Report — AI 商品对比 STORY-008-02-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-02-01
- 评审日期：2026-09-20
- 评审人：trae-agent（本机自审 + 机 gate）
- 评审对象：repo-3 06b0610、repo-2 f2fd7ca（DU-FE-002 部分）；Story 全量产物
- 验证依据：ai-service pytest（时点 43，含对比 15；当前全量 81）；mall-web vitest 129（含 CompareView 5）；ruff/vue-tsc/eslint/build 全过

## 1. 检查结论

通过（approved）。四查（需求一致性 / 设计一致性 / 跨仓适用性 / 代码质量）均无阻断项，AC-014~021 全部有自动化证据闭环，对比数据全部来自实时 Tool 返回，未引入超出设计的依赖与连接路径。

| 维度 | 结论 |
| --- | --- |
| 需求一致性 | 通过：AC-014~021 逐条在 test-report §3 映射；2~6 件约束、缺失即声明、结论有据均落地 |
| 设计一致性 | 通过：批量详情（单点失败降级）→ 属性归一 → 维度选择 → 对比表构建 → 场景化总结五节点链与 story-design 一致；productIds 显式传参 |
| 跨仓适用性 | 通过：GUEST 可用、400/403/502 契约与错误信封（X-Trace-Id）双端一致；mall-product 零改动；前端成功直出不 unwrap |
| 代码质量 | 通过：pytest/ruff 全绿；CompareView 无 v-html、无新依赖；Tool 复用单品字段白名单与通道 |
| 安全 | 通过：入参 2~6 强校验，含无效/不可售 id → 400 不静默剔除；ai.compare.enabled 开关 fail-closed（403 + 入口隐藏） |

## 2. 发现清单

### F-01（观察项，不阻断）

- 真实 mall-product 端到端详情串联未在本阶段执行（测试以 JavaMock 出证），列入 C 类 Integration Gate，联调环境按 story-design §4 串一次。
- 前端开关 false 时入口隐藏由 features store 既有模式保证；直达路由场景由后端 403 fail-closed 收口。

### 红线核对

- 未手改 `.sdd/`；状态全部经 openspec gate/workflow 推进。
- 本地提交未 push（当前授权范围）。
- 未把实现细节写入 standards/。

## 3. 完成确认

- [x] AC-014 2~N 个真实商品对比返回 comparisonDimensions + products + summary 结构
- [x] AC-015 每个 productId 均经 get_products_detail Tool 获取实时详情，无纯名称对比路径
- [x] AC-016 同类商品合理维度（CPU/RAM/存储/GPU/屏幕/重量/价格），异类不强求统一 Schema
- [x] AC-017 缺失属性显示"暂无该项数据"，无推测值
- [x] AC-018 价格/库存状态逐格 == Tool 实时返回值
- [x] AC-019 场景化总结引用具体属性，无不依据的"A 最好"
- [x] AC-020 CompareView 维度表格 + AI 总结（含 Loading/Error/403 态）
- [x] AC-021 不直连 Product DB（无业务库连接串），对比核心 pytest + ruff 通过
- [x] 遗留项均归 C 类 Integration Gate，无代码缺口

Story 可判 completed。
