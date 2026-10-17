# 改造前公开契约复核

2026-10-17，未带用户凭据，仅GET公开文档；未调用业务run、未生成付款码、未创建订单或支付。

来源：
- https://xllite.sayqz.com/api/v1/openapi.json
- https://xllite.sayqz.com/api/v1/features/detail

## 账号

OpenAPI info版本0.1.0，15条路径。包含登录、会话、预热、刷新、退出、微信认证、功能查询及run。未列出忘记密码接口。此结论仅针对公开文档，不证明其他系统不存在找回密码能力。原生找回流程仍需补真实契约。

## 付款成功

newcard.campus_code.qrcode仅生成可消费凭证，含expiresInSeconds，不包含本次消费结果回调或付款状态查询。newcard.transactions有journo流水号，但缺少付款码与交易的关联契约，不能把某条新流水或余额变化直接归因为本次付款。

newcard.recharge.create_order返回支付入口，创建订单不等于支付成功。电费余额支付是另一业务，不应代替校园付款码消费的结果。浮层可先做待确认原型与组件回归，真实触发仍等待结果确认契约。

## 电费单位：修正概念图

newcard.electricity.account参数为roomQuery或location；返回remainingElectricity.value及unit，示例单位为“度”。因此实际页面应显示“剩余电量”和接口单位，而不是照搬生成图中的“¥56.80 剩余电费”。充值配置另有cardBalance（元）及price（元/度）。绑定持久化保存宿舍定位，不混淆电量、电价与余额；未知单位不硬编码为货币。

## 培养方案语义

公开详情确有jw.training，但标题是“教务培养/毕业完成情况”，示例字段为graduationYear、graduationType、graduationConclusion、graduationTime、certificateNo，且明确无数据返回空数组。这不是课程培养方案清单。用户指出现入口鸡肋有明确语义依据：从主路径收敛入口，避免将毕业信息宣称为完整培养方案；不声称该feature完全不存在。

## 后续

界面方向与动效仍待用户确认。契约核实不授权开始真实付款或提交账号数据。不因公开文档有示例，就称真实业务已验收通过。
