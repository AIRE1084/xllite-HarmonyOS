import { Course } from '../models/JwTypes'
import { getCourseMinutes, nextClassIndex } from './ClassTime'
import { getCurrentWeek, getTotalWeeks } from './SemesterService'
import { isCourseInWeek } from './WeekParser'
import { publishNotification } from './NotificationHelper'

interface TimedCourse {
  startMinutes: number
  endMinutes: number
  course: Course
}

const TRIGGER_BEFORE_MIN: number = 10
let currentCourseId: string = ''
let intervalId: number = -1

export function startScheduler(courses: Course[]): void {
  if (intervalId >= 0) clearInterval(intervalId)
  tickScheduler(courses)
  intervalId = setInterval(() => tickScheduler(courses), 60 * 1000)
}

export function stopScheduler(): void {
  if (intervalId >= 0) clearInterval(intervalId)
  intervalId = -1
  cleanup()
}

async function tickScheduler(courses: Course[]): Promise<void> {
  const now = new Date()
  const dayMap: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  const today: string = dayMap[now.getDay()]
  const currentWeek: number = getCurrentWeek()
  const totalWeeks: number = getTotalWeeks()

  const todayCourses: TimedCourse[] = courses
    .filter(c => c.day === today && isCourseInWeek(c.weeks, currentWeek, totalWeeks))
    .map(c => {
      const range: number[] = getCourseMinutes(c.sections)
      const item: TimedCourse = {
        startMinutes: range[0],
        endMinutes: range[1],
        course: c,
      }
      return item
    })
    .sort((a, b) => a.startMinutes - b.startMinutes)

  const idx: number = nextClassIndex(todayCourses)
  if (idx < 0) {
    cleanup()
    return
  }

  const next: TimedCourse = todayCourses[idx]
  const nowMin: number = now.getHours() * 60 + now.getMinutes()
  const diff: number = next.startMinutes - nowMin

  if (diff > TRIGGER_BEFORE_MIN || next.endMinutes < nowMin) {
    cleanup()
    return
  }

  const courseId: string = next.course.day + next.course.slot + next.course.title
  if (currentCourseId === courseId) return
  currentCourseId = courseId

  if (diff >= 0) {
    await publishNotification(
      `${TRIGGER_BEFORE_MIN} 分钟后上课`,
      `${next.course.title} · ${next.course.teacher} · ${next.course.location}`,
    )
  }
}

function cleanup(): void {
  currentCourseId = ''
}
