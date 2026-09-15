# Review Report — STORY-003-02-01-02 公开分类与品牌查询

## 审查范围

- DU-BE-702：公开分类树与品牌查询接口 + 网关白名单

## 审查结论

**通过。** 实现与 story-design 一致，无阻塞问题。

## 检查项

| 项 | 结论 |
|----|------|
| 接口契约与设计一致 | categories/tree → List<CategoryNode{id,name,sort,children}>；brands → BrandPageView{items,total,page,size} |
| 仅启用数据 | 分类树禁用父整枝剪除；品牌强制 status=ENABLED |
| 安全 | 匿名白名单仅限 categories/brands/home/skus；internal denyAll 不变 |
| 分页上限 | size≤200（MALL_MAX_PAGE_SIZE），区别于管理端 100 |
| 注入防护 | keyword LIKE 通配符 %/_/! 转义，ESCAPE '!' |
| ID 字符串 | @StringId 注解，long→String 序列化 |
| 测试覆盖 | 5 例新增覆盖剪枝/空态/关键字/上限/转义 |

## Deviations

- DEV-1：BrandRepositoryImpl.page() 链式 `.eq(boolean,...)` 改 if 块（ECJ 重载推断限制，非设计偏离）
