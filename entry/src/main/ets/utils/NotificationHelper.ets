import notificationManager from '@ohos.notificationManager'
import { Course } from '../models/JwTypes'
import { getCourseMinutes } from './ClassTime'
import { getCurrentWeek, getTotalWeeks } from './SemesterService'
import { isCourseInWeek } from './WeekParser'

const REMIND_BEFORE_MINUTES: number = 10

export async function publishNotification(title: string, content: string): Promise<void> {
  try {
    const normal: notificationManager.NotificationBasicContent = {
      title: title,
      text: content,
    }
    const body: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: normal,
    }
    const request: notificationManager.NotificationRequest = {
      id: Date.now(),
      content: body,
    }
    await notificationManager.publish(request)
  } catch (e) {
    console.warn('publishNotification failed: ' + JSON.stringify(e))
  }
}

export function scheduleClassReminders(courses: Course[]): number[] {
  const now = new Date()
  const dayMap: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  const todayStr: string = dayMap[now.getDay()]
  const currentWeek: number = getCurrentWeek()
  const totalWeeks: number = getTotalWeeks()
  const todayCourses: Course[] = courses.filter(c =>
    c.day === todayStr && isCourseInWeek(c.weeks, currentWeek, totalWeeks),
  )
  const timerIds: number[] = []
  const nowSec: number = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
  const remindWindowSec: number = REMIND_BEFORE_MINUTES * 60

  todayCourses.forEach(c => {
    const range: number[] = getCourseMinutes(c.sections)
    const startSec: number = range[0] * 60
    const delayMs: number = (startSec - nowSec - remindWindowSec) * 1000
    if (delayMs > 0) {
      const tid: number = setTimeout(() => {
        publishNotification(
          `${REMIND_BEFORE_MINUTES} 分钟后上课`,
          `${c.title} · ${c.teacher} · ${c.location}`,
        )
      }, delayMs)
      timerIds.push(tid)
    }
  })

  return timerIds
}

export function cancelReminders(timerIds: number[]): void {
  timerIds.forEach(t => clearTimeout(t))
}
