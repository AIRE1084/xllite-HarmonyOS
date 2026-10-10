import { getColors, ColorPalette } from '../theme/Colors'

/**
 * GlassCard - 通用玻璃容器(基础层)
 *
 * 玻璃 UI(NextClassCard / QuickAccessCard 等)基于此扩展。
 * 浅深色自动跟随(Q5=A)。
 *
 * 用法:
 *   GlassCard({ contentPadding: 16, radius: 16, glassBlur: 30 }) {
 *     Text('内容')
 *   }
 */
@Component
export struct GlassCard {
  @Prop contentPadding: number = 16
  @Prop radius: number = 16
  @Prop glassBlur: number = 30
  @BuilderParam content: () => void

  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)

  aboutToAppear(): void {
    this.palette = getColors(this.isDark)
  }

  onThemeChange(): void {
    this.palette = getColors(this.isDark)
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.contentPadding)
    .borderRadius(this.radius)
    .backdropBlur(Math.max(this.glassBlur, 44))
    .backgroundColor(this.palette.glassBase)
    .border({
      width: 0.8,
      color: this.palette.glassHighlight,
    })
    .shadow({
      radius: 22,
      color: this.palette.glassShadow,
      offsetX: 0,
      offsetY: 8,
    })
  }
}
