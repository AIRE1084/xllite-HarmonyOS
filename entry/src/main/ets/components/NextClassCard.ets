import { getColors, ColorPalette } from '../theme/Colors'
import { CampusCard } from './common/CampusCard'
import { Course } from '../models/JwTypes'
import { getCourseMinutes, nextClassIndex } from '../utils/ClassTime'
import { Radius } from '../theme/Radius'

interface EnrichedItem {
  startMinutes: number
  endMinutes: number
  course: Course
}

/**
 * NextClassCard - 下一节课大卡(液态玻璃,粘性顶部)
 *
 * 实时倒计时 + 课名 + 教师 + 教室 + 导航按钮
 * 没课时显示"今天没课啦"
 */
@Component
export struct NextClassCard {
  @Prop @Watch('onActivityChange') active: boolean = true
  @Prop @Watch('onCoursesChange') courses: Course[] = []
  onTapNavigate: (location: string) => void = (_: string) => {}

  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State countDownText: string = '--:--'
  @State nextCourse: Course | null = null

  private enriched: EnrichedItem[] = []
  private alive: boolean = false
  private timerId: number = -1

  aboutToAppear(): void {
    this.alive = true
    this.palette = getColors(this.isDark)
    this.onCoursesChange()
    this.onActivityChange()
  }
  aboutToDisappear(): void {
    this.alive = false
    if (this.timerId >= 0) clearInterval(this.timerId)
    this.timerId = -1
  }
  onActivityChange(): void {
    if (this.timerId >= 0) clearInterval(this.timerId)
    this.timerId = -1
    if (!this.alive || !this.active) return
    this.refresh()
    this.timerId = setInterval(() => { this.refresh() }, 1000)
  }
  onCoursesChange(): void {
    this.enriched = this.courses.map((c: Course): EnrichedItem => {
      const range = getCourseMinutes(c.sections)
      return { startMinutes: range[0], endMinutes: range[1], course: c }
    }).sort((a: EnrichedItem, b: EnrichedItem): number => a.startMinutes - b.startMinutes)
    this.refresh()
  }

  onThemeChange(): void {
    this.palette = getColors(this.isDark)
  }

  refresh(): void {
    const idx: number = nextClassIndex(this.enriched)
    this.nextCourse = idx >= 0 ? this.enriched[idx].course : null

    if (this.nextCourse !== null) {
      const se2: number[] = getCourseMinutes(this.nextCourse.sections)
      const s: number = se2[0]
      const now = new Date()
      const nowSec: number = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
      const targetSec: number = s * 60
      const remain: number = targetSec - nowSec
      if (remain > 0) {
        const h: number = Math.floor(remain / 3600)
        const m: number = Math.floor((remain % 3600) / 60)
        const ss: number = remain % 60
        this.countDownText = h > 0
          ? `${h}:${m.toString().padStart(2, '0')}:${ss.toString().padStart(2, '0')}`
          : `${m.toString().padStart(2, '0')}:${ss.toString().padStart(2, '0')}`
      } else {
        this.countDownText = '进行中'
      }
    } else {
      this.countDownText = '今天没课'
    }
  }

  build() {
    CampusCard({ contentPadding: 18, radius: 20 }) {
      if (this.nextCourse === null) {
        Column() {
          Text('今天没有待上的课')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette.onSurface)
          Text('查看整周课表，提前安排下一天。')
            .fontSize(12)
            .fontColor(this.palette.onSurfaceVariant)
            .margin({ top: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Row() {
          Column() {
            Text('下一节课')
              .fontSize(11)
              .fontColor(this.palette.onSurfaceVariant)
            Text(this.countDownText)
              .fontSize(28)
              .fontWeight(700)
              .fontColor(this.palette.primary)
              .margin({ top: 2 })
            Text(this.nextCourse.title)
              .fontSize(15)
              .fontWeight(600)
              .fontColor(this.palette.onSurface)
              .margin({ top: 8 })
            Text(`${this.nextCourse.teacher} · ${this.nextCourse.location}`)
              .fontSize(12)
              .fontColor(this.palette.onSurfaceVariant)
              .margin({ top: 2 })
            Text(this.nextCourse.day + ' · ' + (this.nextCourse.sections || this.nextCourse.slot))
              .fontSize(11)
              .fontColor(this.palette.onSurfaceVariant)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('导航')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette.primary)
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .backgroundColor(this.palette.primaryContainer)
            .borderRadius(Radius.md)
            .onClick(() => { this.onTapNavigate(this.nextCourse!.location) })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
  }
}
