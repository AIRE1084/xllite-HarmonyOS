import { Course } from '../models/JwTypes'
import { CourseOccurrence, ScheduleSnapshot, CampusWidgetData } from '../models/CampusCompanionTypes'
import { sectionNumbers, ALL_TIMES, formatMinutes } from './ClassTime'
import { isCourseInWeek } from './WeekParser'

export function weekdayIndex(day: string): number {
  const names: string[] = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日']
  const aliases: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
  const english: string[] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const n = Number(day)
  if (Number.isInteger(n) && n >= 1 && n <= 7) return n - 1
  if (day === '周天' || day === '星期天') return 6
  return Math.max(names.indexOf(day), aliases.indexOf(day), english.indexOf(day))
}
export function localDateText(date: Date): string {
  return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0')
}
export function parseLocalDate(text: string): Date | null {
  const m = text.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/)
  if (m === null) return null
  const date = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  return localDateText(date) === m[1] + '-' + m[2].padStart(2, '0') + '-' + m[3].padStart(2, '0') ? date : null
}
function mondaySerial(date: Date): number {
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  monday.setDate(monday.getDate() - (monday.getDay() + 6) % 7)
  return Date.UTC(monday.getFullYear(), monday.getMonth(), monday.getDate()) / 86400000
}
export function weekOnDate(snapshot: ScheduleSnapshot, date: Date): number {
  const anchor = parseLocalDate(snapshot.anchorDate)
  if (!snapshot.weekKnown || anchor === null) return 0
  return snapshot.currentWeek + Math.round((mondaySerial(date) - mondaySerial(anchor)) / 7)
}
// Discontinuous sections produce separate lessons, never reminders across an unrelated gap.
export function courseSectionGroups(course: Course): number[][] {
  const groups: number[][] = []
  for (const section of sectionNumbers(course.sections)) {
    const last = groups.length > 0 ? groups[groups.length - 1] : []
    if (last.length > 0 && last[last.length - 1] + 1 === section) last.push(section)
    else groups.push([section])
  }
  return groups
}
export function buildOccurrences(snapshot: ScheduleSnapshot, now: Date = new Date(), days: number = 7): CourseOccurrence[] {
  const result: CourseOccurrence[] = []
  const keys: string[] = []
  for (let offset = 0; offset < days; offset++) {
    const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset)
    const week = weekOnDate(snapshot, date)
    if (week < 1 || week > snapshot.totalWeeks) continue
    for (const course of snapshot.courses) {
      if (weekdayIndex(course.day) !== (date.getDay() + 6) % 7 ||
        course.weeks.length === 0 || !isCourseInWeek(course.weeks, week, snapshot.totalWeeks)) continue
      for (const group of courseSectionGroups(course)) {
        const start = ALL_TIMES[group[0] - 1].startMinutes
        const end = ALL_TIMES[group[group.length - 1] - 1].endMinutes
        const startTime = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(start / 60), start % 60).getTime()
        const endTime = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(end / 60), end % 60).getTime()
        const key = localDateText(date) + '|' + course.title + '|' + course.location + '|' + start
        if (keys.includes(key)) continue
        keys.push(key)
        result.push({ key: key, course: course, startTime: startTime, endTime: endTime, week: week })
      }
    }
  }
  return result.sort((a: CourseOccurrence, b: CourseOccurrence): number => a.startTime - b.startTime)
}
export function widgetData(snapshot: ScheduleSnapshot | null, now: Date = new Date()): CampusWidgetData {
  const empty: CampusWidgetData = { heading: '新理工 · 课表', status: '待同步', courseTitle: '打开 APP 同步课表',
    courseTime: '', courseRoom: '', following: '', footer: '点击查看课表' }
  if (snapshot === null || snapshot.account.length === 0) return empty
  if (!snapshot.widgetEnabled) {
    empty.status = '已暂停'; empty.courseTitle = '课表已暂停'; empty.footer = '可在 APP 内重新开启'; return empty
  }
  if (!snapshot.weekKnown) {
    empty.status = '待校准'; empty.courseTitle = '请先确认当前教学周'; return empty
  }
  const week = weekOnDate(snapshot, now)
  if (week < 1 || week > snapshot.totalWeeks) {
    empty.status = '待更新'; empty.courseTitle = '请同步新学期课表'; return empty
  }
  const items = buildOccurrences(snapshot, now, 1).filter((item: CourseOccurrence): boolean => item.endTime > now.getTime())
  empty.heading = '新理工 · 第 ' + week + ' 周'
  empty.status = items.length > 0 ? (items[0].startTime > now.getTime() ? '下一节课' : '上课中') : '今日课程已结束'
  empty.courseTitle = items.length > 0 ? items[0].course.title : '今天没有待上课程'
  if (items.length > 0) {
    const start = new Date(items[0].startTime); const end = new Date(items[0].endTime)
    empty.courseTime = formatMinutes(start.getHours() * 60 + start.getMinutes()) + ' – ' + formatMinutes(end.getHours() * 60 + end.getMinutes())
    empty.courseRoom = items[0].course.location
  }
  empty.following = items.length > 1 ? '接下来 · ' + items[1].course.title : ''
  empty.footer = '课表同步于 ' + localDateText(new Date(snapshot.updatedAt))
  return empty
}
