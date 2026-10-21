# 小艺意图框架契约核实

核实日期：2026-10-21
最低支持版本：API 23（6.1.0）
核实对象：本机 SDK `D:\data\devecostudionext\DevEco Studio\sdk\default\openharmony`
核实方式：只读 SDK 声明文件与仓库代码，未联网，未编造接口。

## 一、结论摘要

小艺接入的技术通道存在，且**大部分能力在 API 23 上可用**——最低线不构成阻碍。

决定性的限制不在框架，而在**标准意图清单里没有任何"创建待办 / 创建提醒"意图**。101 个标准意图全部核对完毕，教育域只有 `ViewSchoolTimetable`（查看课程表）与 `ViewSchoolCalendar`（查看校历）两项，都是"查看"而非"创建"。

这意味着"对小艺说一句『明晚八点提醒我复习数据库』就生成一条学习任务"这个场景，**平台侧没有对应的标准意图可挂**。应用无法凭自己的意愿凭空获得这个入口。

当前仓库 `entry/src/main/module.json5` 里没有任何 intent 配置，小艺接入处于**完全未开始**状态。

## 二、平台能力清单

全部路径以 `ets/api/` 为前缀。

| 能力 | 文件 | 关键声明 | @since |
|---|---|---|---|
| 意图执行器基类 | `@ohos.app.ability.InsightIntentExecutor.d.ts` | `declare class InsightIntentExecutor`（L37） | **11** |
| 入口意图执行器 | `@ohos.app.ability.InsightIntentEntryExecutor.d.ts` | `declare class InsightIntentEntryExecutor<T>`（L32），含 `executeMode`（L42）、`context`（L52）、`onExecute()`（L82） | **20** |
| 意图上下文 | `@ohos.app.ability.InsightIntentContext.d.ts` | 绑定 `@InsightIntentEntry` 装饰的基类 | 11 |
| 结果回传 | `@ohos.app.ability.insightIntentProvider.d.ts` | `sendExecuteResult(instanceId, result)`（L43）、`sendIntentResult<T>(instanceId, result)`（L58） | **23** |
| 装饰器 | `@ohos.app.ability.InsightIntentDecorator.d.ts` | 五个装饰器，见下 | **20** |
| 类型命名空间 | `@ohos.app.ability.insightIntent.d.ts` | `ExecuteResult`、`IntentResult<T>`、`ExecuteMode` | 11 / 18 |

### 装饰器（全部 @since 20）

- `InsightIntentLink(intentInfo: LinkIntentDecoratorInfo)` — L310
- `InsightIntentPage(intentInfo: PageIntentDecoratorInfo)` — L378
- `InsightIntentFunctionMethod(intentInfo: FunctionIntentDecoratorInfo)` — L407
- `InsightIntentFunction()` — L420
- `InsightIntentEntry(intentInfo: EntryIntentDecoratorInfo)` — L473

`IntentDecoratorInfo` 必填字段（L78-126）：`intentName`、`domain`、`intentVersion`、`displayName`；可选 `displayDescription`、`schema`（标准意图名，接标准意图时必填）。

`EntryIntentDecoratorInfo` 额外必填（L432-451）：`abilityName`（字符串）、`executeMode`（`insightIntent.ExecuteMode[]`）。

`@InsightIntentEntry` 的硬性约束（L459-466 原文注释）：
- 类必须 `export default`
- 类属性只能是基本类型或意图实体
- 返回值必须是意图实体
- 接标准意图时，标准 schema 里的所有必填参数都必须实现且类型匹配

### 版本分界

API 23 ≥ 20，所以**上述装饰器与执行器全部可在最低版本上使用**，不需要动态导入门控。

`insightIntent.d.ts` 里 `@since 26.0.0` 的部分（L150-226：`QueryType`、`QueryEntityParam` 等意图实体查询能力）属于高版本增强，**在 API 23 上不可用**，若使用必须走 `api >= 26` 的动态导入。

`insightIntentProvider` 恰好是 @since 23，正好落在最低线上——这是唯一一个"卡线"能力，没有余量，不能下探。

## 三、标准意图清单

位置：`ets/build-tools/ets-loader/insight_intents/schema/`，共 **101** 个 JSON。

教育域（`EducationDomain`）相关项只有两个：

**`ViewSchoolTimetable_1.0.1.json`**
```
intentName:   ViewSchoolTimetable
intentVersion: 1.0.1
llmDescription: 查看课程表
domain:       EducationDomain
parameters:   空对象（properties: {}）
result:       { code: number, result: object }，两者必填
```

**`ViewSchoolCalendar_1.0.1.json`** — 查看校历，同域，结构相同。

通用跳转项：

**`JumpFunctionPage_1.0.1.json`**
```
intentName:   JumpFunctionPage
llmDescription: 跳转app功能页面
domain:       ToolsDomain
parameters:   { pageId: string }（必填）
result:       { code: number, result: object }
```

### 全清单检索结论

对 101 个文件名按 `Todo|Reminder|Schedule|Task|Note|Calendar|Alarm|Memo|Meeting` 检索，只命中三项：

- `StartMeeting`（发起会议）
- `ViewSchoolCalendar`（查看校历）
- `ViewStockIssuedCalendar`（查看股票发行日历）

**没有任何一项是"创建待办"或"创建提醒"。** 最接近的 `PunchIn` 是打卡，语义不同。

`ViewSchoolTimetable` 的 `parameters` 是空对象，说明平台对这个意图已经定义完整——调用方不给参数，应用直接展示课表。这是掌上新理工**唯一一个可以直接对接、且对接后立刻有真实数据返回**的标准意图。

## 四、可落地路径

### 路径 A：接 `ViewSchoolTimetable`（推荐）

应用有真实课表数据，参数为空，结果结构 `{code, result}` 由应用填充。落地点明确。

接入需要：
1. 新建一个继承 `InsightIntentEntryExecutor<T>` 的类，`export default`
2. 用 `@InsightIntentEntry({ intentName: 'ViewSchoolTimetable', domain: 'EducationDomain', intentVersion: '1.0.1', displayName: '查看课表', abilityName: 'EntryAbility', executeMode: [...] })` 装饰
3. 实现 `onExecute(): Promise<insightIntent.IntentResult<T>>`，返回 `{ code: 0, result: ... }`
4. 结果数据从现有 `ClassTime.ets` + 课表服务读取

### 路径 B：`JumpFunctionPage` 跳待办页

传 `pageId` 让小艺跳到应用功能页。但用户仍需手动输入任务内容——**这不是"一句话建任务"，只是"一句话打开页面"**。价值有限，但成本也低。

### 路径 C：自定义意图

框架允许不接标准意图、自定义 `intentName`。但自定义意图**如何被小艺发现和触发**，属于平台分发侧规则，SDK 声明文件里没有任何说明。这一条**未确认**，不做承诺。

## 五、已确认 / 未确认 / 缺口

### 已确认

- 意图框架执行器 `@since 11`，装饰器全套 `@since 20`，`insightIntentProvider` `@since 23`，均在 API 23 最低线上可用。
- 标准意图清单实为 101 个，装在 `ets-loader/insight_intents/schema/`。
- 其中**无任何创建待办 / 创建提醒类意图**。
- 教育域只有 `ViewSchoolTimetable` 与 `ViewSchoolCalendar`，均为查看型、无入参。
- `JumpFunctionPage` 接受 `pageId: string`，可作页面跳转通道。
- `insightIntent.d.ts` 中 `QueryType` / `QueryEntityParam` 为 `@since 26.0.0`，不能用于 API 23。
- 当前 `module.json5` 无任何 intent 配置，小艺接入未开始。

### 未确认

- 自定义意图能否被小艺主动识别、以何种话术触发——SDK 声明文件无相关说明。
- 意图上架是否需要额外资质审核、是否与 AGC 应用市场分发强绑定——SDK 内无证据。
- `domain` 字段的合法取值全集——注释指向一个在线文档链接（`developer.huawei.com/.../intents-ai-distribution-characteristic-...`），离线无法核实，只能确认清单里实际出现过 `EducationDomain` 与 `ToolsDomain`。
- `executeMode` 枚举的全部取值——`insightIntent.d.ts` 里 `ExecuteMode` 的成员未逐项读出。

### 缺口

- **"一句话创建学习任务"无法用标准意图实现。** 这是平台清单缺口，不是实现缺口。任何声称已支持的说法都不成立。
- 待办提醒若要被小艺触发，只能走自定义意图，而自定义意图的可发现性未确认。
- `ViewSchoolTimetable` 的 `result` 内部字段结构平台未定义，由应用自定——跨应用一致性无保证。

## 六、对当前计划的影响

小艺接入不应作为待办功能的依赖项推进。待办能力的价值不来自于能否被小艺唤起。

若要做小艺，唯一证据充分、收益确定的是 `ViewSchoolTimetable`——课表是本应用真实拥有的数据，语义完全吻合，参数为空，落地成本低。

`JumpFunctionPage` 可作补充，但要说清楚它只到"打开页面"，不到"完成动作"。
