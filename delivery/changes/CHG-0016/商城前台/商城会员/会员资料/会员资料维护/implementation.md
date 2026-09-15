# Implementation（跨仓实施汇总）— 会员资料维护 STORY-003-01-02-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story：STORY-003-01-02-01 会员资料维护
- 实施日期：2026-09-15
- 范围边界：mall-member 本人资料 GET/PUT /me、profile 缺失时 identity profile-seed 懒补偿、
  MinIO 头像上传（jpeg/png/webp 魔数、≤2MB、公开读 URL、503 隔离）；mall-web 个人中心资料页
  （回填/字段校验/diff 保存/头像预览上传）。不含：收货地址（STORY-003-01-03-01）、密码修改
  （归 mall-identity）、等级/积分/收藏。无新数据库迁移（member_profile 七列已由 DU-BE-601 V1 建好）。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-603 | repo-1（ai-platform-backend） | 完成并验证：mall-member 44/44（新增 34），全量 24 模块 276 例全绿（基线 242+34） |
| DU-FE-602 | repo-2（ai-platform-frontend / mall-web） | 完成并验证：vitest 9 文件 37/37（新增 15），vue-tsc 0 错误、eslint 0 errors、vite build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 8c5a1e690845b85e03ee839318d4bcdbce88893b | DU-BE-603 | repo-1 | feat(member): 会员资料 GET/PUT /me、MinIO 头像上传与 profile-seed 懒补偿（AvatarFormat 魔数、双道 2MB、懒建桶公开读、确定性 UUID 补偿事件、34 例测试） |
| c20c24c6230790a8bd5af70571e2165a1d67ff64 | DU-FE-602 | repo-2 | feat(mall-web): 个人中心资料页（member API、资料 store 三动作、同界校验、ProfileView 表单+头像预览、/member/profile 守卫，15 例测试） |

（两仓各另有 docs(sdd) implementation/evidence 与 chore(sdd) metadata 回填两个非代码提交，
详见各 DU evidence/commits.md，非代码提交不计入 code-change Evidence。）

基线说明（本 Change 累计代码提交链）：STORY-01 注册 DU-BE-601 代码提交 2f70309；
STORY-02 登录与会话 DU-BE-602 代码提交 f1367cb5617cae51a3de1c78256f6992915f5fa6、
DU-FE-601 代码提交 97b83107636fbf9051140d591f6addcb86aad0db。本 Story 构建于两仓
STORY-02 收尾态之上（其后仅有非代码的 SDD docs/chore 提交），无新数据库迁移。

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-BE-603/implementation.md`
  - DEV-1：profile-seed 契约只含 {memberId,username,status} 无 eventId → 懒补偿事件 ID
    采用 `UUID.nameUUIDFromBytes("member-profile-seed:"+memberId)` 确定性 UUID v3，同会员任意次
    补偿事件 ID 恒定，命中 provision 双幂等；昵称本地「会员+后6位」兜底。
  - DEV-2：MinIO 桶懒就绪（首次头像上传 ensureBucket）替代启动建桶，MinIO 离线不阻断启动与
    注册登录主链（requirement-design §7 风险裁决）。
  - DEV-3：multipart 2MB 双道限制（容器 max-file-size + 应用层字节显式校验，MockMvc 绕容器）；
    MaxUploadSizeExceededException 经 HIGHEST_PRECEDENCE advice 落 400，否则被 common-web 兜底成 500。
  - DEV-4：方法级 @PreAuthorize 拒绝在 DispatcherServlet 内被兜底 Exception 吞成 500 →
    补 `/api/mall/** hasRole MEMBER` 路径层收口 + advice 显式 AccessDeniedException→403。
  - DEV-5：覆盖上传不删旧对象（新 UUID key 原子切换 avatar_url，M3 不做 GC）。
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-FE-602/implementation.md`
  - DEV-1：「组件 vitest」落为 utils/api/store 三逻辑切片（沿用 DU-FE-601 无 DOM 挂载栈惯例，
    不新增依赖），真实点击链路归 M3 Test。
  - DEV-2：eslint flat config 对 **/*.vue 关闭 no-undef（SFC TS 由 vue-tsc 检查）。
  - DEV-3：PUT 仅发 diff 字段（空串显式清空）；头像失败保留本地预览与旧头像可重试。

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-016 | GET /me 返回 ProfileView（@StringId memberId 字符串 + username/nickname/avatarUrl/gender/phone/email）；memberId 只从 SecurityContextFacade.subjectId() 解析，无入参；profile 缺失懒补偿（seed+确定性 UUID v3 重建，幂等不重复）；seed 404/401 → 401 B0101；前端 memberId 仅来自视图、用户名只读 | passed（MemberProfileApiTest::getMeReturnsStringIdProfile、lazyCompensationRebuildsOnce、seedInconsistentReturns401；profile.spec/api member.spec；TC-001/TC-003） |
| AC-017 | PUT 部分更新（null=保留/空白=清空/trim）；昵称 1–32、手机 ^1[3-9]\d{9}$、邮箱宽松正则 ≤128、性别枚举；空昵称/33 字/坏手机/坏邮箱/坏 gender 全 400；接口无 memberId 入参；前端同界校验 + 字段错误 + diff 仅提交变更字段 | passed（updateMeValidationMatrix + MemberProfileUpdateTest 6 + ProfileApplicationServiceTest 合并/不落库 3；profile-form.spec 8；TC-002） |
| AC-018 | POST /me/avatar multipart part=file；jpeg/png/webp 魔数（服务端重算 contentType/扩展名，不信客户端）≤2MB → 200 公开读 URL 且库内 avatar_url 更新；伪装 GIF/非图片/2.1MB → 400 且存储零调用；putObject/桶故障 → 503 S0102 不写库；前端类型+大小预拦截、本地预览、成功刷新/失败保留旧头像并透传文案 | passed（avatarUploadSuccess、disguisedGifRejected、oversizedRejected、storageFailure503 + MinioAvatarStorageTest 5 + ProfileApplicationServiceTest 4；member.spec/avatar 校验/api FormData；TC-004/TC-005） |
| AC-025 | mall-web 个人中心资料查看/修改流程可用；vitest 37/37、type-check/lint/build 全绿；/member/profile 挂 requiresMember，布局增「个人中心」入口 | passed（TC-006：四检 + 15 新增切片用例；浏览器联调归 M3 Test） |

## 5. Fan-in 与验证结论

- 后端：repo-1 `mvn clean package` 24 模块 BUILD SUCCESS，全量 **276/276**（0 failures/0 errors/0 skipped，
  基线 242 + 本 Story 34）；mall-bom 新增 io.minio:minio 8.5.17（版本唯一登记于 BOM）后
  全仓依赖收敛成功，其余模块零改动零回归。
- 前端：repo-2 mall-web vitest 9 文件 **37/37**（基线 22 + 15）、vue-tsc 0 错误、
  eslint 0 errors（92 warnings 全为已降级样式规则）、vite build 成功（ProfileView 路由级分包 6.00 kB）；
  无新增依赖、未改 lockfile。
- 过程红基线：后端 AccessDeniedException 被兜底成 500、MockMvc 2.1MB 不触发容器限制、
  seed 契约无 eventId、ObjectWriteResponse 构造、邮箱边界夹具；前端邮箱 128/129 边界夹具、
  TS6133 未用 ref、SFC no-undef 四处——均在开发期闭环并留 red→green 证据。
- 跨仓契约两侧锁定：`/api/mall/members/me` GET/PUT 与 `/api/mall/members/me/avatar` multipart
  part=file 在后端 DTO（UnifyResult 包装、@StringId）与前端 types/api 逐一核对一致。
- 真实 MinIO 9000 对象上传/桶公开读与 9000 不通 503、真实浏览器资料编辑与头像链路，
  留待 M3 Test 五集成场景两进程联调。

## 6. 后续 Story 累计代码提交（repos-coverage 机检要求）

本 Story 完成后，同 Change 后续 Story 的代码提交（各提交正文在对应 Story implementation.md）：

| Commit | Story / DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| e6068a1bf813dacf353fd509ab0535563f868230 | STORY-003-01-03-01 / DU-BE-604 | repo-1 | 收货地址 V2 生成列默认唯一 + CRUD/设默认/上限20/归属404 |
| 6a10cdd2de3d5b317bdc1022cad8382e2e4b70b5 | STORY-003-01-03-01 / DU-FE-603 | repo-2 | mall-web 收货地址管理页（列表/弹层/删除确认/乐观设默认） |
