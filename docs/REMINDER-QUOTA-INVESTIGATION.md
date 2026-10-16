# 提醒容量调查

## 已复现

API26验收模拟器，应用首条publishReminder返回1700002；getValidReminders成功返回0条。客户端在同步前调用cancelAllReminders，容量触顶时保留已经成功登记的记录、读取本应用有效记录数量；当前设备本轮成功数与系统返回数均为0。未验证提醒送达。

## 公开实现提供的线索

查阅OpenHarmony公开master，ReminderDataManager::CheckReminderLimitExceededLocked先比较totalCount_与系统上限，再遍历非过期记录检查同应用数量，两条路径均返回ERR_REMINDER_NUMBER_OVERLOAD。

- [容量检查实现](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/src/reminder_data_manager.cpp)
- [容量常量声明](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/include/reminder_data_manager.h)

本次读取的常量是：系统12000、系统应用10000、普通应用30。客户端最多24条，低于该公开版本的普通应用上限。系统上限检查在应用计数之前，因此“本应用0条”并不排除系统级容量路径。

这些是可变master分支的公开代码，不是当前HarmonyOS7模拟器的源码或配置证明。不能据此认定模拟器有12000条记录，也不能认定其普通应用上限一定是30。GitHub读取出现连接中断，随后Gitee公开镜像读取成功。

## 系统日志新线索

hilog以Reminder为关键词返回同一时刻两条记录（设备日志时间10-16 22:40:07.400；不把它当作主机时间）：

```text
E C05301/LIVE_VIEW: [ans_ctrl_config_manager.cpp(ReminderControl:134)]ReminderControl Invaild json param
W C01203/Ans: ReminderControl com.xjit.app.acceptance, notification not allowed.
```

这证明该包在系统提醒控制检查中出现配置解析/通知控制警告，但标签为LIVE_VIEW，尚未与publishReminder返回1700002对应到同一次调用。不能直接推断课程提醒容量错误就是此配置引起，也不能用普通isNotificationEnabled返回值排除所有系统侧控制。按小写reminder、overload和upper筛选未返回记录。

随后在已确认的提醒设置页关闭再开启课前提醒，关闭后设备date返回2026-10-16 22:43:42 CST；重新开启后立即读取日志，同包两条ReminderControl警告于22:43:43.262和22:43:43.264再次出现。单次操作与警告已建立秒级时间关联，但同一reconcile也会执行syncLive，因此尚不具备隔离因果证据；后续可关闭实况窗后仅重试课前提醒，将两个系统调用链分开。未修改系统控制配置或读取业务凭据。

## 仍需取得的证据

1. 目标系统对应版本、分支或厂商文档中的实际容量与模拟器限制。
2. 一次失败发布对应的ReminderAgent服务日志，区分system upper limit与application upper limit；只保留错误分类和计数，过滤其他应用及课程内容。
3. 在用户允许的独立测试设备上验证一条提醒登记与实际送达，不清理其他应用提醒、不扩大客户端批量配额。

现有hidumper服务帮助无输出，hilog按1700002过滤为空。后续可针对上述实现日志关键词查询，但日志文本及级别可能与公开版本不同；空日志不构成排除证据。
