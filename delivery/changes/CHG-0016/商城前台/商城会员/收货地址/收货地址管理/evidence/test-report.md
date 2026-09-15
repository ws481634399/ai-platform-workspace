# Test Report — 收货地址管理 STORY-003-01-03-01

> 阶段：sdd-test 产物（独立验证：按 test-design.md 的 11 条 TC 逐条核对，证据取自 DU-BE-604/
> DU-FE-603 evidence，不在此重复实现正文）。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story ID：STORY-003-01-03-01
- 执行时间：2026-09-21（后端）/ 2026-09-15（前端）
- 覆盖：AC-019~025（TC-001~011；TC-001~010 后端、TC-011 前端）
- 测试基线：repo-1 `mvn clean package`（24 模块全量 311 例；mall-member 单模块 79/79）。
  repo-2 mall-web vitest 12 文件 58/58、vue-tsc 0 错误、eslint 0 errors、vite build 成功。
- 测试环境：
  - 后端：JDK 21、Spring Boot Test + MockMvc、H2 内存库（MODE=MySQL；
    DATABASE_TO_LOWER/CASE_INSENSITIVE_IDENTIFIERS；Flyway 开 V1+V2 干净库迁移）、
    @ActiveProfiles("test") 真实安全链（ApiTestSecurityConfig 真实 JWT，多会员 fixture
    73001111/73002222/73003333/73004444）；并发用例双线程 CountDownLatch 真实 H2。
  - 前端：Node 22 / pnpm 10 / vitest 4（node 环境逻辑切片，不挂载组件，DU-FE-601 惯例）、
    vi.mock('@/api/address'|'@/api/http')、pinia 每例 setActivePinia(createPinia())。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | 新增合法地址 201；会员首条 isDefault=true | MockMvc POST 201 + 响应全字段（id textual、无 memberId）；首条默认由应用层 count=0 强制 + 库断言；第二会员首条同样独立默认 | passed | ShippingAddressApiTest::firstAddressAutoDefault；AddressApplicationServiceTest 首条强制默认；be-member-test-run1.log |
| TC-002 | 列表仅本人地址，is_default DESC, updated_at DESC | MockMvc 双会员交叉建址：列表项归属过滤 + 顺序 SQL 断言；响应信封 {items,defaultId} | passed | ShippingAddressApiTest::listOrderedAndScoped |
| TC-003 | PUT 自己地址成功；A 改 B 的 addressId → 404 且 B 数据不变 | MockMvc：本人 200 且字段更新；跨会员 PUT 404 B0201 并重查 B 地址原值；不存在 id 同样 404 | passed | ShippingAddressApiTest::updateOthersAddress404、updateMissingAddress404 |
| TC-004 | DELETE 他人地址 404；自己地址 204 | MockMvc 越权矩阵：跨会员 DELETE 404 且行仍在；本人 DELETE 204 后再 GET 列表不含 | passed | ShippingAddressApiTest::deleteMatrix |
| TC-005 | setDefault 后该会员全表仅一条 is_default=1，旧默认复位 | MockMvc PUT /{id}/default 200 + 直接查库断言该会员默认计数=1、旧标复位、defaultId 切换；同事务 clear+mark InOrder | passed | ShippingAddressApiTest::setDefaultClearsOld；AddressApplicationServiceTest markDefault InOrder（Mockito） |
| TC-006 | 并发两请求设不同地址为默认 → 其一 409，最终仅一个默认 | 双线程 CountDownLatch 同时打真实 H2：最终默认计数必须为 1；若出现拒绝则必须为 B0203（H2 可能串行化成两成功，DEV-4 已说明；MySQL 真实并发放大留 M3 Test） | passed（MySQL 复验随 M3 Test） | AddressDefaultConcurrencyTest 1 例 |
| TC-007 | 删除默认地址后 GET /default 返回 {item:null} | MockMvc：删默认 204（不重选）→ GET /default 200 且 item=null；有默认时返回该视图 | passed | ShippingAddressApiTest::deleteDefaultThenEmpty |
| TC-008 | 手机号非法、必填缺失、detail 超长、postalCode 非 6 位 → 400 | MockMvc 参数化矩阵（聚合规则 + Bean Validation 双道：空收货人/33 字、坏手机、空白省市区、129 字详址、5 位/含字母邮编全 400，合法 200）+ 领域 18 例 | passed | ShippingAddressApiTest::validationMatrix400；ShippingAddressTest 18 例 |
| TC-009 | 已有 20 条后第 21 条 → 409 ADDRESS_LIMIT | MockMvc 连建 20 条全 201，第 21 条 409 B0202 且库内仍 20 行；应用层 count≥20 拦截 Mockito 例 | passed | ShippingAddressApiTest::limit20Conflict；AddressApplicationServiceTest 上限 409 |
| TC-010 | V2 建表 + default_member_flag 生成列与 uk 存在 | Flyway 干净库迁移后查 INFORMATION_SCHEMA：列存在（COLUMNS）；唯一索引 INDEX_TYPE_NAME LIKE '%UNIQUE%' 且名前缀 UK_ADDRESS_DEFAULT（H2 自动加 _INDEX_2 后缀，DEV-5）；冲突插入异常含 uk_address_default | passed | ShippingAddressApiTest::migrationGeneratedColumnAndUnique |
| TC-011 | 前端：地址列表/新增/编辑/删除/设默认全流程与错误提示；三检通过 | vitest 三切片 21 例（api 契约 6 + 表单矩阵 9 + store 编排 6：乐观时点/409 回滚重拉/409 不污染/强拉次数）；SFC 由 vue-tsc + build 锁定；四检全绿 | passed（点击链路归 M3 Test 浏览器联调，DU-FE-603 DEV-1） | address.spec、address-form.spec、stores/address.spec；fe-test-run2/typecheck/lint/build-run1.log |

附加安全矩阵：ShippingAddressApiTest::anonymous401AndAdmin403——匿名 401、ADMIN 403，
类级 @PreAuthorize MEMBER + /api/mall/** 路径层规则（DU-BE-602/603 预置）双保险，本 Story 零网关改动。

合计：11 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| repo-1 Maven 全量（24 模块全部测试） | 311 | 311 | 0 | 0 |
| └ mall-member（其中本 Story 新增 35 例：领域 18 + 应用 5 + 并发 1 + API 11） | 79 | 79 | 0 | 0 |
| └ 既有套件（identity 79/gateway 19/注册资料链路回归面） | 232 | 全绿 | 0 | 0 |
| repo-2 mall-web vitest（本 Story 新增 3 切片文件） | 58 | 58 | 0 | 0 |
| └ address-form 校验矩阵 / api address 契约 / address store 编排 | 21 | 21 | 0 | 0 |
| └ DU-FE-601/602 既有 9 文件（登录态/资料链路回归面） | 37 | 37 | 0 | 0 |

静态门禁：repo-2 vue-tsc 双 tsconfig 0 错误；eslint 0 errors（133 warnings 为已降级样式规则，
基线 92 + 新页 41）；vite build 成功（AddressListView 路由分包 10.19 kB/gzip 3.33 kB）。
日志：
- repo-1 `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-BE-604/evidence/logs/`（be-member-test-run1.log、backend-full-package-run1.log）。
- repo-2 `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/收货地址/收货地址管理/DU-FE-603/evidence/logs/`（fe-test-run1/run2、fe-typecheck-run1、fe-lint-run1、fe-build-run1）。

## 3. 验证中发现并闭环的问题

1. **V2 DDL 在 H2 双不兼容（dev 内闭环，DEV-1）**：story-design DDL 的
   `IF(is_default=1,member_id,NULL) STORED` 在 H2 MODE=MySQL 两处报错——IF() 方言函数不认、
   计算列 STORED 关键字不认。改标准 CASE WHEN 表达式并省略 STORED 后迁移通过；
   MySQL 8 默认 VIRTUAL 但 UNIQUE 索引物化键值，唯一性等价（真实 MySQL 复验留 M3 Test）。
2. **H2 元数据视图与 MySQL 命名差异（dev 内闭环，DEV-5）**：H2 2.x INDEXES 无 IS_UNIQUE
   列、约束支持索引被自动改名 uk_address_default_INDEX_2；TC-010 断言改 INDEX_TYPE_NAME
   LIKE '%UNIQUE%' + 索引名前缀匹配；assertj 无 hasMessageContainingIgnoringCase，
   冲突文案按实测小写名断言。
3. **ECJ 增量桩类（dev 内闭环，RED-5）**：testCompile 失败后未 clean，错误桩类致整类
   11 例 Error；统一 `mvn clean test` 后消失，后续验证全部走 clean。
4. 另两项为参数化注解非常量 repeat()/注解顺序（RED-2）与 Instant.now 夹具时间（RED-4）；
   前端两处（表单夹具对象展开顺序覆盖、mock 实现 Promise<void> 返回类型）均在开发期闭环，
   无遗留到独立验证阶段的未决缺陷。

## 4. 跨服务集成验证边界

- 默认唯一性的最终防线 uk_address_default 基于生成列，H2 已验证冲突异常路径；
  MySQL 8 真实 DDL（VIRTUAL 生成列 + UNIQUE 物化）与双进程并发设默认必现其一 409 的复验，
  纳入 M3 Test 五集成场景（requirement-design §6/§7）。
- 前端以 vi.mock 切片锁定合同，未起浏览器；「登录→收货地址→新增（首条默认徽标）→编辑→
  设默认即时置顶→删除确认→双会员越权 404 toast 数据不变→第 21 条 409 提示」真实链路
  随 M3 Test 浏览器联调（网关 8080/member 8102，data-testid 已预埋）。

## 5. 结论

AC-019~025 全部通过，11 条 TC 无遗留失败；identity/gateway 与注册/登录/资料既有链路、
DU-FE-601/602 前端套件零回归；前后端四检/全量构建全绿。本 Story 具备进入 review 的条件。
