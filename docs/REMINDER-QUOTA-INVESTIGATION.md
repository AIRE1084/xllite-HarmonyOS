# 提醒容量调查

## 已复现

API26验收模拟器，应用首条publishReminder返回1700002；getValidReminders成功返回0条。客户端在同步前调用cancelAllReminders，容量触顶时保留已经成功登记的记录、读取本应用有效记录数量；当前设备本轮成功数与系统返回数均为0。未验证提醒送达。

## 公开实现提供的线索

查阅OpenHarmony公开master，ReminderDataManager::CheckReminderLimitExceededLocked先比较totalCount_与系统上限，再遍历非过期记录检查同应用数量，两条路径均返回ERR_REMINDER_NUMBER_OVERLOAD。

- [容量检查实现](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/src/reminder_data_manager.cpp)
- [容量常量声明](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/include/reminder_data_manager.h)

本次读取的常量是：系统12000、系统应用10000、普通应用30。客户端最多24条，低于该公开版本的普通应用上限。系统上限检查在应用计数之前，因此“本应用0条”并不排除系统级容量路径。

这些是可变master分支的公开代码，不是当前HarmonyOS7模拟器的源码或配置证明。不能据此认定模拟器有12000条记录，也不能认定其普通应用上限一定是30。GitHub读取出现连接中断，随后Gitee公开镜像读取成功。

## 零配额控制路径

进一步读取[ReminderAgentService::PublishReminder](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/src/reminder_agent_service.cpp)发现：调用NotificationHelper::AllowUseReminder(bundleName, isAllowUseReminder)后，若结果为false，直接记录“The number of reminders exceeds the limit[0].”并返回ERR_REMINDER_NUMBER_OVERLOAD。该判断先于普通通知开关和ReminderDataManager数量检查。因此同一个超限错误还可能表示系统不允许该应用使用提醒，而非实际登记数过多。

这为当前0条且伴随ReminderControl警告提供更强的解释路径，但公开master不等同于目标系统构建；尚需目标日志或对应版本实现证明。产品提示应保留原错误码，并同时提示容量或系统提醒限制，避免只承诺等待容量释放即可恢复。

## 系统日志新线索

hilog以Reminder为关键词返回同一时刻两条记录（设备日志时间10-16 22:40:07.400；不把它当作主机时间）：

```text
E C05301/LIVE_VIEW: [ans_ctrl_config_manager.cpp(ReminderControl:134)]ReminderControl Invaild json param
W C01203/Ans: ReminderControl com.xjit.app.acceptance, notification not allowed.
```

这证明该包在系统提醒控制检查中出现配置解析/通知控制警告，但标签为LIVE_VIEW，尚未与publishReminder返回1700002对应到同一次调用。不能直接推断课程提醒容量错误就是此配置引起，也不能用普通isNotificationEnabled返回值排除所有系统侧控制。按小写reminder、overload和upper筛选未返回记录。

随后在已确认的提醒设置页关闭再开启课前提醒，关闭后设备date返回2026-10-16 22:43:42 CST；重新开启后立即读取日志，同包两条ReminderControl警告于22:43:43.262和22:43:43.264再次出现。单次操作与警告已建立秒级时间关联，但同一reconcile也会执行syncLive，因此尚不具备隔离因果证据；后续可关闭实况窗后仅重试课前提醒，将两个系统调用链分开。未修改系统控制配置或读取业务凭据。

隔离重试：临时关闭课程实况窗，关闭再开启课前提醒，设备date为22:45:25 CST，警告于22:45:25.945/.946再次出现。随后截图确认实况窗关闭、课前提醒开启，仍为本轮0条/系统0条及容量触顶。因而警告不依赖实况窗开启，可将调查重点收窄至提醒/通知系统控制；这仍不证明解析失败直接映射1700002。测试结束已点击恢复原先实况窗开启偏好，未变更系统配置。

## 目标系统零配额路径已观察

随后使用limit和ReminderControl分别筛选，得到同秒、同进程903、同线程1165的三条记录：

```text
10-16 23:34:23.905 E C05301/LIVE_VIEW: ReminderControl Invaild json param
10-16 23:34:23.905 W C01203/Ans: ReminderControl com.xjit.app.acceptance, notification not allowed.
10-16 23:34:23.905 W C01203/ANS_REMINDER: The number of reminders exceeds the limit[0].
```

目标设备确实出现了与公开AllowUseReminder失败分支完全相同的limit[0]日志，与同包系统控制警告同毫秒同线程关联。当前证据支持“系统提醒使用控制未放行/零配额路径”，而非本应用已登记记录过多；客户端降低24条上限或清理本应用0条记录不解决此路径。系统控制配置为何无效、是否与镜像或包资格有关仍未查明，不修改系统配置绕过控制，不推断普通通知授权足以解决。

## 仍需取得的证据

1. 目标系统对应版本、分支或厂商文档中的实际容量与模拟器限制。
2. 一次失败发布对应的ReminderAgent服务日志，区分system upper limit与application upper limit；只保留错误分类和计数，过滤其他应用及课程内容。
3. 在用户允许的独立测试设备上验证一条提醒登记与实际送达，不清理其他应用提醒、不扩大客户端批量配额。

现有hidumper服务帮助无输出，hilog按1700002过滤为空。后续可针对上述实现日志关键词查询，但日志文本及级别可能与公开版本不同；空日志不构成排除证据。
