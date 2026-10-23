import { getColors, ColorPalette } from '../theme/Colors'
import { NativeGlass } from './NativeGlass'
import { Typography } from '../theme/Typography'
import { Motion } from '../theme/Motion'

/**
 * 浮动玻璃 Tab 栏。
 *
 * 整条栏是一枚悬浮在内容之上的玻璃胶囊（NativeGlass），里面三个格子各放
 * 一组「图标 + 文字」，纵向排列。
 *
 * 选中态不用背景色块，只让图标与文字变成品牌色。这是刻意的：
 *
 * - 一条玻璃轨道上再叠半透明色块，块和轨道是两层不同的半透明，叠出来的
 *   颜色既不等于品牌色也不等于玻璃色，在白玻璃背景上尤其像贴纸；
 * - 色块的圆角还要单独去配容器的圆角，配不齐就是"胶囊比整条栏矮一截"
 *   这种对不上的观感，配齐了也只是把整格染成另一块色，把胶囊切成几段；
 * - 只用颜色区分，选中态和未选中态共用同一套形状，任何屏宽、任何主题下
 *   都不会错位，也没有需要跟容器对齐的第二个圆角。
 *
 * 按压反馈仍然保留：按下的那一格出现一层极淡的底色、图标轻微放大，抬手即消。
 * 它只在手指按住时存在，不参与常态视觉，所以不会和上面的取舍冲突。
 *
 * 减少动效偏好下所有时长归零。
 */
const BAR_HEIGHT: number = 62
const ICON_SIZE: number = 24
const PRESS_SCALE: number = 1.06
const TABS_LABELS: string[] = ['首页', '课表', '我的']

@Component
export struct BlurTabBar {
  @Prop currentIndex: number = 0
  onTabChange: (index: number) => void = () => {}
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
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
  private tint(index: number): ResourceColor {
    return this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant
  }

  @Builder
  TabItem(index: number) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Image(this.icon(index)).width(ICON_SIZE).height(ICON_SIZE)
          .fillColor(this.tint(index))
          .scale({ x: this.reduceMotion || this.pressingIdx !== index ? 1 : PRESS_SCALE,
            y: this.reduceMotion || this.pressingIdx !== index ? 1 : PRESS_SCALE })
          .animation({ duration: this.reduceMotion ? 0 : Motion.duration.fast, curve: Motion.curve.standard })
        Text(this.label(index)).fontSize(Typography.caption.fontSize)
          .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.tint(index))
          .maxLines(1)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).height(BAR_HEIGHT)
    // 按压底色只在按住时出现；常态完全透明，选中与否都不靠它表达。
    .backgroundColor(this.pressingIdx === index && !this.reduceMotion
      ? (this.isDark ? '#12FFFFFF' : '#0F315EDA')
      : Color.Transparent)
    .borderRadius(16)
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
    // 容器本身就是胶囊：半径取内容高度的一半，内容高由 BAR_HEIGHT 与内边距决定。
    NativeGlass({ contentPadding: 5, radius: (BAR_HEIGHT + 10) / 2, interactive: true, prominent: true }) {
      Row() { this.TabItem(0); this.TabItem(1); this.TabItem(2) }
        .width('100%').height(BAR_HEIGHT)
    }
  }
}
