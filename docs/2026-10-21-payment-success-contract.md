# 支付成功契约核实

核实日期：2026-10-21
范围：校园一卡通充值、宿舍电费充值
核实方式：只读本机 SDK 声明文件与仓库代码，未联网，未发起任何支付或订单请求。

## 一、结论

**在当前契约下，应用侧无法判定支付是否成功。** 这不是实现遗漏，是能力缺失。

三个事实叠加导致这个结论：

1. 鸿蒙 SDK 里**没有任何系统级支付接口**。对 `ets/api` 全目录按 `*[Pp]ay*` 检索，零匹配文件。
2. 支付真实发生在校外 H5 或微信/支付宝 App 内，本应用只是承载容器。
3. 应用侧没有任何支付结果回调通道，`Web` 容器也没监听结果页。

因此 handoff 第 4 节那个支付成功浮层，**没有可靠的触发依据**。若强行接一个"看到某 URL 就弹"或"页面回到前台就弹"的判断，就是伪造成功，直接违反 4.3「尚无契约时不接假成功计时器」。

## 二、现有实现

### 接口

| 功能名 | 用途 | 代码位置 |
|---|---|---|
| `newcard.recharge.config` | 拉金额档位与支付方式 | `RechargePage.ets:83` |
| `newcard.recharge.create_order` | 创建订单，返回支付入口 | `RechargePage.ets:112` |
| `newcard.electricity.recharge.config` | 电费充值配置 | `ElectricityPage.ets:94` |
| `newcard.electricity.recharge.pay` | 电费支付 | `ElectricityPage.ets:130` |

### 创建订单请求体

`RechargePage.ets:104-108`：

```
amount:    选中的充值金额
payCode:   选中的支付方式编码
tradeType: 'WAP'
```

`tradeType: 'WAP'` 说明服务端走的是**网页支付**，不是原生 SDK 支付。

### 响应结构

`models/CardTypes.ets:105-119`：

```
PayResult {
  type: string
  payCode: string
  partnerJourno: string    // 合作方流水号
  h5Url: string
  htmlPost: string
  officialTransferUrl: string
}

RechargeOrderResult {
  amount: string
  payMethod: PayMethod
  partnerJourno: string
  payResult: PayResult
}
```

`ElecRechargePayResult`（L121-127）结构相同，多 `room` 与 `account`。

**`partnerJourno` 是交易唯一标识**，可用于去重——但仅用于去重，不能用于查询状态，因为没有状态查询接口。

### 支付入口的三种形态

`RechargePage.ets:116-136` 按优先级取用：

1. `payResult.htmlPost` → 转成 data URL，`Web` 加载，类型 `html`。这是一段自动提交到支付网关的表单。
2. `payResult.officialTransferUrl` → 直接作为 `Web` 的 URL。
3. `payResult.h5Url` → 直接作为 `Web` 的 URL。

三者皆空时，页面提示「订单已创建，但服务端没有返回支付入口，请到一卡通账户查询结果」（L134）。这句提示本身就已经承认了：应用不知道结果。

### 承载与跳转

`RechargePage.ets:178-184`：

```
Web({ src: this.payContent, controller: this.webController })
  .onLoadIntercept(...)   // 只拦 weixin:// alipays:// 等外部 scheme
```

`onLoadIntercept` 仅处理外部 scheme，通过 `startAbility({ uri })` 把 `weixin://` / `alipays://` 交给系统拉起对应 App（L155-168）。**同一 if 分支里非外部 scheme 一律 `return false` 放行，不做任何结果判定**。

`Web` 组件上**没有 `onPageEnd`、没有 URL 观察、没有注入 JS 桥**。也就是说支付页跳到哪里、是否跳到成功页，应用完全看不见。

### 降级路径

`utils/SchoolRoutes.ets:26-30` 把充值类功能映射到学校 H5 页面地址：

```
newcard.recharge.config / create_order  → SCHOOL_CARD + '/#/pages_plugins/recharge/recharge'
newcard.electricity.*                    → SCHOOL_CARD + '/#/pages_payment/electrictyFees/electrictyFees'
```

这是"在浏览器里打开"的降级路径，与支付结果判定无关，但说明这些能力在平台侧本来就是网页形态。

## 三、可用信号与不可用信号

### 绝对不能当成功依据

以下信号全部与"钱是否真的到账"无关，任何一条单独出现都不能触发成功：

- 创建订单接口返回 `ok: true`。这只说明**订单建好了**，钱还没动。
- `Web` 页面加载完成、页面跳转到某个 result 页。支付网关的失败页也会跳转。
- 页面回到前台、用户从微信/支付宝切回。
- `startAbility` 成功拉起微信/支付宝。这只说明装了 App。
- 网络请求返回 200。
- 余额变化。handoff 4.3 已明确排除，理由成立：余额可能因其他消费变动，且存在同步延迟。
- `partnerJourno` 非空。这只是流水号存在。

### 有条件可用，但需额外契约

- **`newcard.transactions` 交易记录查询**。这是唯一有原生适配的卡类接口（`SchoolRoutes.ets:17` 的 `hasNativeAdapter` 只覆盖 `jw.profile`、`newcard.balance`、`newcard.transactions`）。理论上可以在支付后拉取交易记录，按金额+时间窗匹配。
  但**是否包含充值类交易、字段能否区分充值与消费，未确认**。若无区分能力，这条路也不成立。

### 缺口

要让"支付成功浮层"真正可用，平台侧至少需要以下之一：

- 一个按 `partnerJourno` 查询订单状态的接口（如 `newcard.recharge.query_order`）。
- 交易记录接口能返回明确区分「充值」与「消费」的类型字段，且充值记录带 `partnerJourno`。

两者当前都不存在。

## 四、对浮层的影响

**浮层不应实现。** 理由不是工作量大，是**没有合法的触发条件**。

若现在实现，只有三种落法，全部不可接受：

- 接定时器假装成功 —— 伪造，明确禁止。
- 接页面返回当成功 —— 失败页也会返回，会给出错误结论。
- 永不触发 —— 那就是死代码，违反「删死组件」的既有要求。

正确做法是保持现状：订单创建后引导用户到一卡通账户自行核对，文案不出现「已确认到账」。当前 L134 的提示已经是这个口径，不需要改。

浮层的形态设计（深灰圆角方块 + 绿色圆环 + 绿色对勾）可以保留在文档里作为待用设计，但**在拿到订单状态查询能力之前不写进代码**。

## 五、已确认 / 未确认

### 已确认

- SDK 无系统级支付接口（`ets/api` 下 `*[Pp]ay*` 零匹配）。
- 充值走 `tradeType: 'WAP'` 网页支付。
- 支付入口有三种形态：`htmlPost`、`officialTransferUrl`、`h5Url`。
- 交易唯一标识是 `partnerJourno`。
- `Web` 容器无结果页监听，应用对支付结果零观测。
- 外部 scheme 通过 `startAbility` 交给系统，成功与否只反映 App 是否安装。

### 未确认

- `newcard.transactions` 返回的记录里是否含充值类交易、是否有区分字段——需要真实账号数据才能验证，不能在模拟器上凭空断言。
- 学校 H5 支付成功后是否有固定回跳地址——未联网核实学校 H5 实现，不猜测。
- 微信/支付宝是否对该商户提供了应用可接收的异步通知——属商户侧配置，SDK 与仓库内均无证据。

### 缺口

- 无订单状态查询接口。
- 无支付结果回调注册机制。
- 交易记录能否区分充值类型未确认，因此不能作为替代方案承诺。
