import { getColors, ColorPalette } from '../theme/Colors'
import { NativeGlass } from './NativeGlass'
import { Typography } from '../theme/Typography'
import { Motion } from '../theme/Motion'

@Component
export struct BlurTabBar {
  @Prop currentIndex: number = 0
  onTabChange: (index: number) => void = () => {}
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @StorageLink('reduceMotion') reduceMotion: boolean = false
  aboutToAppear(): void { this.onThemeChange() }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  private icon(index: number): Resource {
    if (index === 0) return $r('app.media.nav_home')
    if (index === 1) return $r('app.media.nav_calendar')
    return $r('app.media.nav_profile')
  }
  private label(index: number): string { return ['首页', '课表', '我的'][index] }

  @Builder
  TabItem(index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        Image(this.icon(index)).width(21).height(21)
          .fillColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
        Text(this.label(index)).fontSize(Typography.caption.fontSize)
          .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).height(48).borderRadius(24)
    .backgroundColor(this.currentIndex === index ? (this.isDark ? '#D92A4168' : '#D9E5EDFF') : Color.Transparent)
    .animation({ duration: this.reduceMotion ? 0 : Motion.duration.fast, curve: Motion.curve.standard })
    .accessibilityText(this.label(index))
    .accessibilityDescription(this.currentIndex === index ? '已选中' : '切换到' + this.label(index))
    .onClick(() => { if (this.currentIndex !== index) this.onTabChange(index) })
  }

  build() {
    NativeGlass({ contentPadding: 6, radius: 32, interactive: true, prominent: true }) {
      Row({ space: 4 }) { this.TabItem(0); this.TabItem(1); this.TabItem(2) }
        .width('100%')
    }
  }
}
