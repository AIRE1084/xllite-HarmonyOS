import { getColors, ColorPalette } from '../../theme/Colors'

/** 正文卡片以可读性为主，系统原生材质由导航容器负责。 */
@Component
export struct CampusCard {
  @Prop contentPadding: number = 18
  @Prop radius: number = 20
  @BuilderParam content: () => void
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)

  aboutToAppear(): void { this.palette = getColors(this.isDark) }
  onThemeChange(): void { this.palette = getColors(this.isDark) }

  build() {
    Column() { this.content() }
      .width('100%')
      .padding(this.contentPadding)
      .backgroundColor(this.palette.surface)
      .borderRadius(this.radius)
      .border({ width: 0.5, color: this.palette.outline })
  }
}
