# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商城会员 > 会员资料 > 会员资料维护
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：GET /me 返回 memberId(字符串)/username/昵称/头像/手机/邮箱；无 memberId 入参 | AC-016 | DU-BE-603 | |
| TC-002 | API：PUT /me 昵称 1–32 字成功；空/超长 → 400；手机邮箱格式校验 | AC-017 | DU-BE-603 | |
| TC-003 | 懒补偿：手动删 profile 后 GET /me → seed 拉取并重建，返回 200；再次调用不重复建 | AC-016 | DU-BE-603 | 补偿幂等 |
| TC-004 | API：POST /me/avatar 上传 jpeg/png/webp ≤2MB → 200 可访问 URL，库内 avatar_url 更新 | AC-018 | DU-BE-603 | MinIO mock/容器 |
| TC-005 | API：上传 .gif 伪装/非图片、2.1MB 文件 → 400，无对象写入 | AC-018 | DU-BE-603 | |
| TC-006 | 前端组件：ProfileView 表单改/存、头像预览上传成功/失败提示；build/lint/type-check | AC-025 | DU-FE-602 | 个人中心流程 |

## 2. 测试策略

- Unit：资料字段校验矩阵；MinioStorageClient key 生成与拒绝逻辑（mock SDK）。
- Integration：MinIO Testcontainer（不可用时退 mock 并留证）；seed 404 → 401 异常路径。
- Frontend：vitest 组件测试 + 三检。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-601/602；本地 MinIO 9000 运行（TC-004）。
