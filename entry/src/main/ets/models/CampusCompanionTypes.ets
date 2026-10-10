import { Course } from './JwTypes'

export interface ScheduleSnapshot {
  account: string
  term: string
  courses: Course[]
  currentWeek: number
  totalWeeks: number
  weekKnown: boolean
  anchorDate: string
  updatedAt: number
  widgetEnabled: boolean
}
export interface CourseOccurrence {
  key: string
  course: Course
  startTime: number
  endTime: number
  week: number
}
export interface CampusWidgetData {
  heading: string
  status: string
  courseTitle: string
  courseTime: string
  courseRoom: string
  following: string
  footer: string
}
