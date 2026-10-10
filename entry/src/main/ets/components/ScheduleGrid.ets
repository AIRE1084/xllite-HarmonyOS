import { getColors, ColorPalette } from '../theme/Colors'
import { Course } from '../models/JwTypes'
import { ALL_TIMES, ClassTime, classStatus } from '../utils/ClassTime'
import { scheduleBlocks, ScheduleBlock } from '../utils/ScheduleLayout'
import { localDateText } from '../utils/CourseCalendar'

@Component
export struct ScheduleGrid {
  @Prop @Watch('refreshBlocks') courses: Course[] = []
  @Prop @Watch('refreshBlocks') currentWeek: number = 1
  @Prop @Watch('refreshBlocks') totalWeeks: number = 20
  @Prop actualWeek: number = 1
  @Prop weekKnown: boolean = false
  onCourseTap: (c: Course) => void = (_: Course) => {}
  onCourseLongPress: (c: Course) => void = (_: Course) => {}
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State blocks: ScheduleBlock[] = []
  private readonly rowHeight: number = 64
  private readonly dayWidth: number = 112

  aboutToAppear(): void { this.palette = getColors(this.isDark); this.refreshBlocks() }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  refreshBlocks(): void { this.blocks = scheduleBlocks(this.courses, this.currentWeek, this.totalWeeks) }
  private isActualWeek(): boolean { return this.weekKnown && this.currentWeek === this.actualWeek }
  private isToday(day: number): boolean { return this.isActualWeek() && day === (new Date().getDay() + 6) % 7 }
  private status(block: ScheduleBlock): number {
    return this.isToday(block.day) ? classStatus(ALL_TIMES[block.first - 1].startMinutes, ALL_TIMES[block.last - 1].endMinutes) : 0
  }
  private color(course: Course): string {
    let hash = 0
    for (let i = 0; i < course.title.length; i++) hash = (hash * 31 + course.title.charCodeAt(i)) | 0
    return this.palette.courseColors[Math.abs(hash) % this.palette.courseColors.length]
  }
  private dayDate(day: number): string {
    if (!this.weekKnown) return ''
    const date = new Date()
    date.setDate(date.getDate() - (date.getDay() + 6) % 7 + day + (this.currentWeek - this.actualWeek) * 7)
    return (date.getMonth() + 1) + '/' + date.getDate()
  }
  @Builder
  DayColumn(day: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        ForEach(ALL_TIMES, (time: ClassTime, row: number) => {
          Column().width(this.dayWidth).height(this.rowHeight)
            .border({ width: { bottom: 0.5 }, color: this.palette.outline })
            .backgroundColor(this.isToday(day) ? this.palette.primaryContainer : Color.Transparent)
        })
      }.width(this.dayWidth)
      ForEach(this.blocks.filter((item: ScheduleBlock): boolean => item.day === day), (block: ScheduleBlock) => {
        Column({ space: 6 }) {
          Text(block.course.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.isDark ? '#0B0E14' : '#FFFFFF')
            .maxLines(block.last > block.first ? 4 : 2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          if (block.last > block.first) {
            Text(block.course.location).fontSize(11).fontColor(this.isDark ? '#0B0E14' : '#FFFFFF').maxLines(2).width('100%')
            Text((this.status(block) === 2 ? '已结束 · ' : '') + block.first + '–' + block.last + ' 节').fontSize(10).fontColor(this.isDark ? '#0B0E14' : '#FFFFFF').width('100%')
          }
          if (block.lanes > 1 && block.last > block.first) { Text('时间冲突').fontSize(10).fontColor(this.isDark ? '#0B0E14' : '#FFFFFF').width('100%') }
        }.alignItems(HorizontalAlign.Start).padding(8)
          .width(this.dayWidth / block.lanes - 6).height((block.last - block.first + 1) * this.rowHeight - 6)
          .backgroundColor(this.color(block.course)).borderRadius(12)
          .border({ width: this.status(block) === 1 ? 2 : 0, color: this.palette.primary })
          .position({ x: block.lane * this.dayWidth / block.lanes + 3, y: (block.first - 1) * this.rowHeight + 3 })
          .accessibilityGroup(true)
          .accessibilityText(block.course.title + '，' + block.course.location + '，第' + block.first + '至' + block.last + '节' + (block.lanes > 1 ? '，时间冲突' : ''))
          .accessibilityDescription('点击查看完整课程详情')
          .onClick(() => this.onCourseTap(block.course))
          .gesture(LongPressGesture().onAction(() => this.onCourseLongPress(block.course)))
      }, (block: ScheduleBlock): string => block.key)
    }.width(this.dayWidth).height(ALL_TIMES.length * this.rowHeight)
  }
  build() {
    Column({ space: 10 }) {
      Row() {
        Text('整周课表').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
        Blank()
        Text('左右滑动 · 点击查看详情').fontSize(11).fontColor(this.palette.onSurfaceVariant)
      }.width('100%')
      Scroll() {
        Column() {
          Row() {
            Text('节次').width(48).fontSize(11).fontColor(this.palette.onSurfaceVariant).textAlign(TextAlign.Center)
            ForEach(['周一', '周二', '周三', '周四', '周五', '周六', '周日'], (label: string, day: number) => {
              Column({ space: 4 }) {
                Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.isToday(day) ? this.palette.primary : this.palette.onSurface)
                Text(this.dayDate(day)).fontSize(11).fontColor(this.palette.onSurfaceVariant)
              }.width(this.dayWidth).height(52).justifyContent(FlexAlign.Center)
                .backgroundColor(this.isToday(day) ? this.palette.primaryContainer : Color.Transparent)
            })
          }.width(832).backgroundColor(this.palette.surface)
          Row() {
            Column() {
              ForEach(ALL_TIMES, (time: ClassTime, row: number) => {
                Column({ space: 5 }) {
                  Text(String(row + 1)).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
                  Text(time.label.split(' - ')[0]).fontSize(10).fontColor(this.palette.onSurfaceVariant)
                }.width(48).height(this.rowHeight).justifyContent(FlexAlign.Center)
                  .border({ width: { bottom: 0.5 }, color: this.palette.outline })
              })
            }.width(48)
            ForEach([0, 1, 2, 3, 4, 5, 6], (day: number) => { this.DayColumn(day) })
          }.alignItems(VerticalAlign.Top).width(832)
        }.width(832)
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').borderRadius(16)
    }.width('100%')
  }
}
