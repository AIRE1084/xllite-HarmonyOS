// 学期名与周次由 CampusCompanionService.publishWeek 统一写入 AppStorage，
// 这里只保留读取入口。曾经的 getCurrentWeek / getTotalWeeks 已移除：
// 它们让同一份数据多出第二个真相源，且默认值 1 / 20 会掩盖"尚未同步"的状态。
export function getTerm(): string { return AppStorage.get<string>('term') ?? '' }
