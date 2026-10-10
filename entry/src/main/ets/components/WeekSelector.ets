import { getColors, ColorPalette } from '../theme/Colors'
import { Radius } from '../theme/Radius'
import { Motion } from '../theme/Motion'

/**
 * WeekSelector - 横向周次选择胶囊条
 * 1-20 周次,可滚动,当前周高亮
 */
@Component
export struct WeekSelector {
  @Prop @Watch('revealCurrentWeek') currentWeek: number = 1
  @Prop totalWeeks: number = 20
  onWeekChange: (week: number) => void = () => {}
  private weekScroller: Scroller = new Scroller()
  private selectorReady: boolean = false

  revealCurrentWeek(): void {
    if (this.selectorReady) {
      this.weekScroller.scrollToIndex(Math.max(0, Math.min(this.currentWeek, this.totalWeeks) - 1), false, ScrollAlign.CENTER)
    }
  }

  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @StorageLink('reduceMotion') reduceMotion: boolean = false

  aboutToAppear(): void {
    this.palette = getColors(this.isDark)
  }

  onThemeChange(): void {
    this.palette = getColors(this.isDark)
  }

  @Builder
  WeekChip(week: number) {
    Button({ type: ButtonType.Normal }) {
      Text(`第${week}周`)
        .fontSize(this.currentWeek === week ? 13 : 12)
        .fontWeight(this.currentWeek === week ? 600 : 400)
        .fontColor(this.currentWeek === week ? this.palette.onPrimary : this.palette.onSurfaceVariant)
    }
    .height(44).padding({ left: 16, right: 16 })
    .backgroundColor(this.currentWeek === week ? this.palette.primary : Color.Transparent)
    .border({
      width: this.currentWeek === week ? 0 : 0.5,
      color: this.palette.outline,
    })
    .borderRadius(22)
    .animation({ duration: this.reduceMotion ? 0 : Motion.duration.fast, curve: Motion.curve.standard })
    .accessibilityText('第' + week + '周')
    .accessibilityDescription(this.currentWeek === week ? '已选中' : '查看这一周的课表')
    .onClick(() => { if (this.currentWeek !== week) this.onWeekChange(week) })
  }

  build() {
    List({ space: 8, initialIndex: Math.max(0, this.currentWeek - 2), scroller: this.weekScroller }) {
      ForEach(
        this.getWeekArray(),
        (week: number) => {
          ListItem() { this.WeekChip(week) }
        },
        (week: number): string => week.toString(),
      )
    }
    .listDirection(Axis.Horizontal)
    .height(52)
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .width('100%')
    .scrollBar(BarState.Off)
    .onAppear(() => { this.selectorReady = true })
    .onDisAppear(() => { this.selectorReady = false })
    .onAreaChange(() => { this.revealCurrentWeek() })
  }

  // ArkTS 兼容的周次数组生成
  private getWeekArray(): number[] {
    const weeks: number[] = []
    for (let i = 1; i <= this.totalWeeks; i++) {
      weeks.push(i)
    }
    return weeks
  }
}
