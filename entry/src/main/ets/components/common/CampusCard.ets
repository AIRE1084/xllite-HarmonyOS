import { getColors, ColorPalette } from '../../theme/Colors'

/**
 * Body card built as a liquid-glass surface.
 *
 * The blur is real backdrop sampling, not a flat fill: `saturation` above 1 is
 * what makes Apple's Liquid Glass read as glass instead of fog, so it lifts the
 * ambient blooms behind the card. The tint layer stays high-alpha on purpose so
 * dense content (grade tables, transaction lists) keeps its contrast.
 */
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
      .borderRadius(this.radius)
      .backgroundEffect({
        radius: 42,
        saturation: this.isDark ? 1.55 : 1.85,
        brightness: this.isDark ? 0.95 : 1.06,
        color: this.isDark ? '#B8121B2C' : '#C7FFFFFF',
        adaptiveColor: AdaptiveColor.AVERAGE,
      })
      .border({ width: 0.5, color: this.palette.outline })
  }
}
