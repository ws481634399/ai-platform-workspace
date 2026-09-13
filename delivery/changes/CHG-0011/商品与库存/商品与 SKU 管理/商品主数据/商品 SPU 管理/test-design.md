# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0011/.../商品 SPU 管理/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 11

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：携带 product:product:create，POST 合法 Product（名称+分类+品牌+主图）→ 200，status=DRAFT | AC-001 | DU-BE-304 | 创建≠可见 |
| TC-002 | API 集成测试：categoryId 指向不存在/禁用分类 → INVALID_ARGUMENT；brandId 同理 | AC-002 | DU-BE-304 | 引用合法 |
| TC-003 | API 集成测试：创建 Product 含主图+2 张图集；查询详情 images 中仅一条 mainFlag=1 | AC-007 | DU-BE-304 | 主图唯一 |
| TC-004 | API 集成测试：创建后 PUT 修改名称/属性/图片；GET 返回最新值 | AC-008 | DU-BE-304 | 一致性 |
| TC-005 | 静态检查+迁移断言：product_spu/product_sku 表无 stock 列 | AC-009 | DU-BE-304 | 领域边界 |
| TC-006 | API 集成测试：创建 Product 后 status=DRAFT；状态枚举含 DRAFT/ON_SALE/OFF_SALE/DISABLED | AC-010 | DU-BE-304 | 生命周期 |
| TC-007 | API 集成测试：创建 Product 含 2 个属性；修改后属性集合正确 | AC-012 | DU-BE-304 | 属性 |
| TC-008 | 安全切片：无 product:product:create/update → 403 且无写入；有权限 → 200 | AC-013 | DU-BE-304 | RBAC |
| TC-009 | 领域单测：Product.create 注册 ProductCreatedDomainEvent；update 注册 ProductUpdatedDomainEvent | AC-014 | DU-BE-304 | 领域事件 |
| TC-010 | API 集成测试：禁用 Product（status=DISABLED）后尝试发布（归 REQ-M2-003，断言聚合行为拒绝） | AC-015 | DU-BE-304 | 状态流转 |
| TC-011 | E2E：mall-admin 商品列表/创建/编辑/查看页基本信息+图片+属性区块操作成功 | AC-011 | DU-FE-303 | 前端 |

## 2. 测试策略

- Unit：Product 聚合不变量（主图唯一、状态流转、领域事件注册）。
- API 集成：@SpringBootTest + MockMvc + H2，安全切片注入 authorities。
- E2E：本地联调人工验证前端页面，留存截图。
- 数据准备：复用 CHG-0010 分类/品牌测试数据构造。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-304 权限码 V3 先执行；分类/品牌表由 CHG-0010 V1 提供。
- TC-010 的发布动作在聚合层断言，不暴露对外接口。
