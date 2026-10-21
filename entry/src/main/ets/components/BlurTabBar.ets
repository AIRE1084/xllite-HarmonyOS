import { getColors, ColorPalette } from '../theme/Colors'
import { NativeGlass } from './NativeGlass'
import { Typography } from '../theme/Typography'
import { Motion } from '../theme/Motion'
import curves from '@ohos.curves'

@Component
export struct BlurTabBar {
  @Prop currentIndex: number = 0
  onTabChange: (index: number) => void = () => {}
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State itemWidth: number = 0
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
      Column({ space: 3 }) {
        Image(this.icon(index)).width(24).height(24)
          .scale({ x: this.reduceMotion || this.currentIndex !== index ? 1 : 1.08,
            y: this.reduceMotion || this.currentIndex !== index ? 1 : 1.08 })
          .fillColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
        Text(this.label(index)).fontSize(Typography.caption.fontSize)
          .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.currentIndex === index ? this.palette.primary : this.palette.onSurfaceVariant)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1).height(58).borderRadius(29)
    .backgroundColor(Color.Transparent)
    .animation({ duration: this.reduceMotion ? 0 : Motion.duration.fast, curve: Motion.curve.standard })
    .accessibilityText(this.label(index))
    .accessibilityDescription(this.currentIndex === index ? '已选中' : '切换到' + this.label(index))
    .onClick(() => { if (this.currentIndex !== index) this.onTabChange(index) })
  }

  build() {
    NativeGlass({ contentPadding: 5, radius: 36, interactive: true, prominent: true }) {
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width(this.itemWidth).height(58).borderRadius(29)
          .backgroundColor(this.isDark ? '#263B59' : '#E5EDFF')
          .translate({ x: this.currentIndex * this.itemWidth })
          .animation({ duration: this.reduceMotion ? 0 : 320,
            curve: this.reduceMotion ? Curve.Linear : curves.springMotion(0.32, 0.86, 0.12) })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Row() { this.TabItem(0); this.TabItem(1); this.TabItem(2) }
          .width('100%')
      }.width('100%').height(58)
        .onAreaChange((_oldArea: Area, area: Area) => {
          const width = Number(area.width)
          if (Number.isFinite(width) && width > 0) this.itemWidth = width / 3
        })
    }
  }
}
