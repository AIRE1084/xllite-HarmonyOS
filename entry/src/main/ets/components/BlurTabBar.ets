import { getColors, ColorPalette } from '../theme/Colors'
import { NativeGlass } from './NativeGlass'
import { Typography } from '../theme/Typography'
import { Motion } from '../theme/Motion'
import curves from '@ohos.curves'

/**
 * 浮动胶囊 Tab 栏。
 *
 * 整条栏是一个定宽的圆角胶囊，悬浮在内容之上，底子是 NativeGlass 的玻璃。
 * 选中态不是与 tab 等宽的实心色块，而是一个明显窄于 tab 的高亮胶囊：
 * 四周留白让它看起来像玻璃轨道上滑动的一颗珠子，而不是把整格染成另一种
 * 底色——后者压在深色玻璃上会割出一条生硬的直边，把胶囊切成一格一格的。
 *
 * 指示器宽度钉死、位置按 itemWidth 重算，所以横竖屏切换或分屏时不会与
 * 底下的 tab 错位。宽度不随选中态变化：一个会伸缩的指示器在连续切换两次
 * 时会出现"刚撑开又缩回"的抖动。
 *
 * 按压反馈分两层：按下的那一格有一层极淡的白色高光，图标同时放大 6%，
 * 抬手即消。只有选中态放大则按在未选中的格子上毫无反馈。
 *
 * 减少动效偏好下所有时长归零，弹簧曲线换成线性。只把时长设 0 而保留弹簧，
 * 曲线仍会被求值一次，在部分机型上表现为一次 1 帧的跳动。
 */
const INDICATOR_WIDTH: number = 64
const INDICATOR_HEIGHT: number = 44
const INDICATOR_RADIUS: number = 22
const INDICATOR_LIFT: number = 7
const PRESS_SCALE: number = 1.06
const TABS_LABELS: string[] = ['首页', '课表', '我的']

@Component
export struct BlurTabBar {
  @Prop currentIndex: number = 0
  onTabChange: (index: number) => void = () => {}
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State itemWidth: number = 0
  @State indicatorX: number = 0
  @State pressingIdx: number = -1
  @StorageLink('reduceMotion') reduceMotion: boolean = false
  aboutToAppear(): void { this.onThemeChange() }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  private icon(index: number): Resource {
    if (index === 0) return $r('app.media.nav_home')
    if (index === 1) return $r('app.media.nav_calendar')
    return $r('app.media.nav_profile')
  }
  private label(index: number): string { return TABS_LABELS[index] }

  private recalcIndicator(): void {
    if (this.itemWidth <= 0) return
    this.indicatorX = this.currentIndex * this.itemWidth + (this.itemWidth - INDICATOR_WIDTH) / 2
  }

  // 指示器玻璃：顶部一层极淡白色收向中段，底部转暗，形成"被光照到"的弧度；
  // 描边只给顶部一丝高光，四圈等宽描边会让胶囊显得像贴纸。
  private indicatorColors(): Array<[ResourceColor, number]> {
    if (this.isDark) return [['#3DA9C4EA', 0], ['#1FA9C4EA', 0.52], ['#0A0B1220', 1]]
    return [['#F2FFFFFF', 0], ['#C7E4EDFF', 0.5], ['#8CFFFFFF', 1]]
  }

  private indicatorBorder(): string { return this.isDark ? '#3DA9C4EA' : '#D9FFFFFF' }

  private indicatorGlow(): ShadowOptions {
    return { radius: this.isDark ? 12 : 8, color: this.isDark ? '#33000000' : '#1F315EDA', offsetY: 2 }
  }

  @Builder
  TabItem(index: number) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 3 }) {
        Image(this.icon(index)).width(24).height(24)
          .scale({ x: this.reduceMotion || this.pressingIdx !== index ? 1 : PRESS_SCALE,
            y: this.reduceMotion || this.pressingIdx !== index ? 1 : PRESS_SCALE })
          .fillColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
          .animation({ duration: this.reduceMotion ? 0 : Motion.duration.fast, curve: Motion.curve.standard })
        Text(this.label(index)).fontSize(Typography.caption.fontSize)
          .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
          .maxLines(1)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).height(58).borderRadius(29)
    .backgroundColor(this.pressingIdx === index && !this.reduceMotion
      ? (this.isDark ? '#12FFFFFF' : '#0F315EDA')
      : Color.Transparent)
    .animation({ duration: this.reduceMotion ? 0 : Motion.duration.instant, curve: Motion.curve.standard })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) { this.pressingIdx = index }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressingIdx = -1 }
    })
    .onClick(() => { if (this.currentIndex !== index) this.onTabChange(index) })
    .accessibilityText(this.label(index))
    .accessibilityDescription(this.currentIndex === index ? '已选中' : '切换到' + this.label(index))
  }

  build() {
    NativeGlass({ contentPadding: 5, radius: 36, interactive: true, prominent: true }) {
      Stack({ alignContent: Alignment.Start }) {
        // 指示器比 tab 窄，四边留白；它在 tab 之下、玻璃之上，所以必须让出点击。
        Column()
          .width(INDICATOR_WIDTH).height(INDICATOR_HEIGHT)
          .borderRadius(INDICATOR_RADIUS)
          .linearGradient({ angle: 165, colors: this.indicatorColors() })
          .border({ width: 1, color: this.indicatorBorder() })
          .shadow(this.indicatorGlow())
          .translate({ x: this.indicatorX, y: INDICATOR_LIFT })
          .animation({ duration: this.reduceMotion ? 0 : 320,
            curve: this.reduceMotion ? Curve.Linear : curves.springMotion(0.32, 0.86, 0.12) })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Row() { this.TabItem(0); this.TabItem(1); this.TabItem(2) }
          .width('100%')
      }.width('100%').height(58)
        .onAreaChange((_oldArea: Area, area: Area) => {
          const width = Number(area.width)
          if (Number.isFinite(width) && width > 0) {
            this.itemWidth = width / TABS_LABELS.length
            this.recalcIndicator()
          }
        })
    }
  }
}
