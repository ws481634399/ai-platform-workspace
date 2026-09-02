# 前端代码规范

> 版本：v0.1  
> 类型：前端工程规范  
> 作用域：OpenSpec Workspace


# 1. 文档目的


本文档定义前端项目代码开发规范。


目标：

- 保证前端代码质量；
- 提升代码可读性；
- 降低维护成本；
- 保证 AI Coding Agent 生成代码符合项目工程要求。


---

# 2. 基本原则


## 2.1 可读性优先


代码应该优先考虑维护人员的理解成本。


要求：

- 使用明确的变量名称；
- 避免复杂逻辑；
- 避免隐藏行为。


推荐：

```typescript
const userProfile = await getUserProfile();
```


避免：

```typescript
const data = await get();
```


---

## 2.2 类型安全优先


前端项目应优先使用 TypeScript 类型约束。


推荐：

```typescript
interface User {
  id: string;
  name: string;
}
```


避免：

```typescript
const user: any = {};
```


---

## 2.3 单一职责


一个文件、组件、函数应该具有明确职责。


避免：

- 一个组件包含大量业务逻辑；
- 一个文件承担多个功能；
- 公共工具包含无关方法。


---

# 3. 文件命名规范


## 3.1 组件文件


组件名称应该表达业务含义。


推荐：

```
UserProfile.vue

OrderList.tsx
```


避免：

```
Comp1.vue

Test.vue
```


---

## 3.2 工具文件


工具文件应该表达用途。


推荐：

```
date-utils.ts

request-helper.ts
```


避免：

```
utils1.ts

common.ts
```


---

## 3.3 常量文件


推荐：

```
constants.ts

route-config.ts
```


---

# 4. 目录结构规范


前端项目应该按照职责组织。


推荐：


```
src/

├── api/

├── assets/

├── components/

├── hooks/

├── layouts/

├── pages/

├── router/

├── stores/

├── utils/

└── types/
```


---

## 4.1 components


存放可复用组件。


要求：

- 通用组件独立；
- 避免绑定具体业务。


---

## 4.2 pages


存放页面级组件。


页面负责：

- 页面组合；
- 数据加载；
- 页面流程。


不应该：

- 包含大量底层逻辑。


---

## 4.3 hooks


存放可复用逻辑。


例如：

```
useUser.ts

usePermission.ts
```


---

## 4.4 utils


存放通用工具方法。


要求：

- 无业务依赖；
- 输入输出明确。


---

# 5. 组件代码规范


## 5.1 组件职责


组件应该关注：

- UI展示；
- 用户交互；
- 数据绑定。


复杂业务逻辑应该拆分。


---

## 5.2 Props设计


Props应该明确类型。


推荐：

```typescript
interface Props {
  userId: string;
  disabled?: boolean;
}
```


避免：

```typescript
props: Object
```


---

## 5.3 Emit事件


事件名称应该表达行为。


推荐：

```
submit

cancel

change
```


避免：

```
click1

eventA
```


---

# 6. 状态管理规范


## 6.1 状态分类


状态应该明确归属。


包括：

- 页面状态；
- 组件状态；
- 全局状态；
- 服务端数据状态。


---

## 6.2 避免滥用全局状态


以下情况不应该进入全局状态：


- 临时表单数据；
- 单页面展示状态；
- 组件内部状态。


---

## 6.3 状态命名


状态名称应该表达业务含义。


推荐：

```typescript
isLoggedIn

orderStatus
```


避免：

```typescript
flag

status1
```


---

# 7. 异步处理规范


## 7.1 统一错误处理


接口请求需要处理：

- 成功；
- 失败；
- 加载状态。


示例：


```typescript
try {

} catch(error) {

}
```


---

## 7.2 避免重复请求


需要考虑：

- 请求缓存；
- 防重复提交；
- 加载状态控制。


---

# 8. 样式规范


## 8.1 样式隔离


组件样式应该避免污染全局。


推荐：

- Scoped Style；
- CSS Modules；
- 设计系统。


---

## 8.2 避免大量内联样式


不推荐：

```html
<div style="color:red">
```


推荐：

```html
<div class="error-message">
```


---

# 9. 前端代码质量要求


代码提交前检查：


```
[ ] 类型定义完整

[ ] 组件职责明确

[ ] 无明显重复代码

[ ] 命名清晰

[ ] 无无意义any

[ ] 错误处理完整

[ ] 代码格式统一
```


---

# 10. AI Coding Agent 修改规则


AI 修改前端代码时必须：


## 修改前


读取：


```
delivery/

design.md

+

frontend standards

+

existing implementation
```


确认：

- 页面影响；
- 组件关系；
- 数据来源。


---

## 修改中


遵守：

- 项目已有技术栈；
- 组件设计规范；
- 类型约束。


---

## 修改后


输出：

- 修改文件列表；
- 影响范围；
- 测试结果；
- 风险说明。


---

# 11. 禁止行为


AI 不应该：


## 11.1 随意新增依赖


新增依赖需要说明：

- 使用原因；
- 维护成本；
- 项目影响。


---

## 11.2 大规模重构


未经 Change：

禁止：

- 重写页面结构；
- 修改整体目录；
- 替换技术方案。


---

## 11.3 绕过已有组件


已有公共组件能够满足需求时：

不要重复创建。


---

# 12. 总结


前端代码规范用于保证：


```
页面实现

+

组件设计

+

类型安全

+

工程质量
```


保持一致。


通过统一规范，使 AI Coding Agent 能够生成：

- 可维护；
- 可理解；
- 可扩展；

的前端代码。

---

# 13. 前端工具链版本配套约定（CHG-0004 晋升）


## 13.1 ESLint 10 flat config 配套


ESLint 10 不再随附 @eslint/js，采用 flat config（eslint.config.js）的项目必须在 devDependencies 显式声明 @eslint/js。


已验证版本组合（mall-web / mall-admin 实测通过，全链路 lint 0 error）：

| 包 | 版本 |
|----|------|
| eslint | ^10.9.1 |
| eslint-plugin-vue | ^10.10.0 |
| typescript-eslint | ^8.69.0 |
| @eslint/js | ^10.0.1 |


来源：CHG-0004 review-report.md §1.5（DU-FE-002 DEV-4 / DU-FE-003 DEV-5）


## 13.2 TypeScript 版本固定


TypeScript 7 与 typescript-eslint 8 的 peerDependencies 范围冲突，需显式固定 `typescript@5`（当前锁定 5.9.x），禁止使用 latest 或 7.x。


来源：CHG-0004 review-report.md §1.5（DU-FE-002/003 Deviations）


## 13.3 双 tsconfig 串联 type-check


app/node 双 tsconfig（无 references 组合）场景下，类型门禁命令必须串联两个 project：


```bash
vue-tsc --noEmit -p tsconfig.json && vue-tsc --noEmit -p tsconfig.node.json
```


package.json 的 type-check script 按此约定声明。


来源：CHG-0004 review-report.md §1.5


---

# 14. 多应用镜像文件对齐约定（CHG-0004 晋升）


同一 Workspace 内多个前端应用（如 mall-web 与 mall-admin）的工程配置文件应保持镜像一致：


- 单一事实源：工程配置模板（http.ts、tsconfig×2、eslint.config.js、.prettierrc.json、.npmrc、.env.example 等）从模板目录复制实例化；
- 镜像清单：维护镜像文件清单，清单内文件在应用间应逐行一致；
- 复核方式：评审阶段对镜像清单执行 diff 复核，任何差异必须有 Deviations 记录说明。


该策略替代 frontend-common 公共包方案，在保持各应用独立可构建（独立 main/package.json/lockfile）的同时获得配置统一性。


来源：CHG-0004 review-report.md §1.5
