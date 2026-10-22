import { glassMaterial, supportsImmersiveMaterial, loadImmersiveMaterial } from '../theme/Materials'

/**
 * Glass surface.
 *
 * Two rendering paths, chosen at runtime:
 *
 * - API 26+ (HarmonyOS 7.0): native `systemMaterial` with `uiMaterial.ImmersiveMaterial`,
 *   which refracts the real scene behind the window.
 * - API 23-25 (HarmonyOS 6.0 and below): ArkUI `backgroundEffect`, which is the only
 *   light-sensing blur available on those releases.
 *
 * The fallback is not a plain grey blur. `backgroundEffect` exposes `saturation`, and
 * saturation above 1 is what separates glass from frosted glass: it pushes the
 * refracted colours past their original vibrancy instead of merely washing them out.
 * Combined with the multi-hue ambient field behind the surface, that is what makes
 * the card read as glass rather than as a translucent grey slab.
 *
 * `adaptiveColor: AdaptiveColor.AVERAGE` makes the tint follow the averaged colour of
 * the content behind the surface, so a card over the indigo bloom tints indigo and a
 * card over the cyan bloom tints cyan.
 */
@Component
export struct NativeGlass {
  @Prop contentPadding: Length = 16
  @Prop radius: number = 24
  @Prop interactive: boolean = false
  @Prop prominent: boolean = false
  @BuilderParam content: () => void
  @StorageLink('isDark') isDark: boolean = false
  @State nativeSupported: boolean = supportsImmersiveMaterial()
  private appearance: number = 0
  aboutToAppear(): void {
    const revision = ++this.appearance
    this.nativeSupported = supportsImmersiveMaterial()
    loadImmersiveMaterial().then((supported: boolean) => {
      if (revision === this.appearance) this.nativeSupported = supported
    })
  }
  aboutToDisappear(): void { this.appearance++ }
  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.nativeSupported) {
        Column() { this.content() }
          .width('100%').padding(this.contentPadding).borderRadius(this.radius)
          .systemMaterial(glassMaterial(this.isDark, this.interactive, this.prominent))
      } else {
        Column() { this.content() }
          .width('100%').padding(this.contentPadding).borderRadius(this.radius)
          .backgroundEffect({
            radius: this.prominent ? 54 : 40,
            // Above 1 the refracted colours gain vibrancy instead of being flattened.
            saturation: this.prominent ? 2.2 : 1.8,
            brightness: 1.0,
            color: this.isDark ? '#3DFFFFFF' : '#CCFFFFFF',
            adaptiveColor: AdaptiveColor.AVERAGE,
          })
      }
      Row().width('78%').height(1)
        .linearGradient({ angle: 90, colors: this.isDark
          ? [['#009EB8EA', 0], ['#B8D9E9FF', 0.5], ['#009EB8EA', 1]]
          : [['#00FFFFFF', 0], ['#FFFFFFFF', 0.5], ['#00FFFFFF', 1]] })
        .margin({ top: 1 }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }.width('100%').borderRadius(this.radius)
      // A separate shell keeps the native material node free of custom backgrounds.
      .linearGradient({ angle: 145, colors: this.isDark
        ? [['#33161F30', 0], ['#1F0D1520', 0.55], ['#2A1A2733', 1]]
        : [['#4DFFFFFF', 0], ['#1FF5F9FF', 0.55], ['#33F2FBF9', 1]] })
      .border({ width: 1, color: this.isDark ? '#507F9BBE' : '#E8FFFFFF' })
      .shadow({ radius: this.prominent ? 20 : 12, color: this.isDark ? '#28000000' : '#18364F78', offsetY: 8 })
  }
}
