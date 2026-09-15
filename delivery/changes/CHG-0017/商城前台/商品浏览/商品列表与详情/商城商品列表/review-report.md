# Review Report — STORY-003-02-02-01 商城商品列表

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-02-01
- 审查对象：DU-BE-703（repo-1）、DU-FE-703（repo-2）
- 审查时间：2026-09-16
- 审查者：trae-agent

## 1. 检查结论

**通过（PASS）。** 列表查询增强与 FE 列表页实现符合设计，价区排序走派生表 SQL（非内存排序），query 唯一状态源，测试覆盖充分。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | info | 分类树侧栏仅展示根分类（未递归渲染子分类） | M3 列表筛选够用，子分类通过 categoryId 直接命中后端展开 |
| F-002 | info | brandIds 上限 50（防 IN 过长） | 符合 task-design |

无 blocker / major 发现。

## 3. 检查项明细

| 项 | 结论 |
|----|------|
| 分页 size≤50 | MALL_MAX_PAGE_SIZE=50 |
| 子孙分类深度≤3 | collectDescendantCategoryIds 两轮展开 |
| brandIds 多选交集 | normalizeBrandIds 去重上限50 |
| 价区排序派生表 | ProductMapper.selectMallPage LEFT JOIN pr，ORDER BY pr.lo/pr.hi |
| sort 白名单防注入 | MyBatis choose 固定片段，无字符串拼接 |
| minPrice/maxPrice 非空 | long 原语，派生表保证存在 |
| query 唯一状态源 | route.query → replace → watch → 请求 |
| 竞态防护 | requestSeq 自增比对 |
| 三态 | StateView loading/empty/error |

## 4. Deviations

无。
