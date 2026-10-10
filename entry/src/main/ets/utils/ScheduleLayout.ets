import { Course } from '../models/JwTypes'
import { courseSectionGroups, weekdayIndex } from './CourseCalendar'
import { isCourseInWeek } from './WeekParser'
export interface ScheduleBlock {
  key: string
  course: Course
  day: number
  first: number
  last: number
  lane: number
  lanes: number
}
export function scheduleBlocks(courses: Course[], week: number, total: number): ScheduleBlock[] {
  const blocks: ScheduleBlock[] = []
  const keys: string[] = []
  for (const course of courses) {
    const day = weekdayIndex(course.day)
    if (day < 0 || !isCourseInWeek(course.weeks, week, total)) continue
    for (const group of courseSectionGroups(course)) {
      const key = day + '|' + course.title + '|' + course.location + '|' + group.join(',')
      if (keys.includes(key)) continue
      keys.push(key)
      blocks.push({ key: key, course: course, day: day, first: group[0], last: group[group.length - 1], lane: 0, lanes: 1 })
    }
  }
  blocks.sort((a: ScheduleBlock, b: ScheduleBlock): number => a.day - b.day || a.first - b.first || a.last - b.last)
  let cluster: ScheduleBlock[] = []
  let clusterEnd = 0
  let clusterDay = -1
  const assign = (): void => {
    const ends: number[] = []
    for (const block of cluster) {
      let lane = ends.findIndex((end: number): boolean => end < block.first)
      if (lane < 0) { lane = ends.length; ends.push(block.last) } else ends[lane] = block.last
      block.lane = lane
    }
    for (const block of cluster) block.lanes = ends.length
  }
  for (const block of blocks) {
    if (block.day !== clusterDay || block.first > clusterEnd) {
      assign(); cluster = []; clusterEnd = 0; clusterDay = block.day
    }
    cluster.push(block); clusterEnd = Math.max(clusterEnd, block.last)
  }
  assign()
  return blocks
}
