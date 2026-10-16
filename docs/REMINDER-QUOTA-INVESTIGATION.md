# 提醒容量调查

## 已复现

API26验收模拟器，应用首条publishReminder返回1700002；getValidReminders成功返回0条。客户端在同步前调用cancelAllReminders，容量触顶时保留已经成功登记的记录、读取本应用有效记录数量；当前设备本轮成功数与系统返回数均为0。未验证提醒送达。

## 公开实现提供的线索

查阅OpenHarmony公开master，ReminderDataManager::CheckReminderLimitExceededLocked先比较totalCount_与系统上限，再遍历非过期记录检查同应用数量，两条路径均返回ERR_REMINDER_NUMBER_OVERLOAD。

- [容量检查实现](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/src/reminder_data_manager.cpp)
- [容量常量声明](https://gitee.com/openharmony/notification_distributed_notification_service/blob/master/services/reminder/include/reminder_data_manager.h)

本次读取的常量是：系统12000、系统应用10000、普通应用30。客户端最多24条，低于该公开版本的普通应用上限。系统上限检查在应用计数之前，因此“本应用0条”并不排除系统级容量路径。

这些是可变master分支的公开代码，不是当前HarmonyOS7模拟器的源码或配置证明。不能据此认定模拟器有12000条记录，也不能认定其普通应用上限一定是30。GitHub读取出现连接中断，随后Gitee公开镜像读取成功。

## 仍需取得的证据

1. 目标系统对应版本、分支或厂商文档中的实际容量与模拟器限制。
2. 一次失败发布对应的ReminderAgent服务日志，区分system upper limit与application upper limit；只保留错误分类和计数，过滤其他应用及课程内容。
3. 在用户允许的独立测试设备上验证一条提醒登记与实际送达，不清理其他应用提醒、不扩大客户端批量配额。

现有hidumper服务帮助无输出，hilog按1700002过滤为空。后续可针对上述实现日志关键词查询，但日志文本及级别可能与公开版本不同；空日志不构成排除证据。
