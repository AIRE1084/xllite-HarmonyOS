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
 * The fallback is not a plain grey blur. `backgroundEffect` exposes `saturation`,
 * and saturation above 1 is what separates glass from frosted glass: it pushes
 * the refracted colours past their original vibrancy instead of merely washing
 * them out. `backdropBlur` and `backgroundBlurStyle` only expose a radius, so
 * they cannot produce this effect at all.
 *
 * The parameters below follow the recipe that was verified by sampling pixels on
 * the emulator; `components/common/CampusCard.ets` uses the same values for body
 * cards:
 *
 * - `brightness` stays at exactly 1.0. Raising it lifts the surface far more
 *   than linearly and turns the card into a white sheet; the sense of solidity
 *   comes from the alpha of `color` instead.
 * - `adaptiveColor` stays `DEFAULT`. `AVERAGE` replaces the mask colour with the
 *   average colour of the content behind the surface, so the card converges on
 *   the background and its edge disappears; the measured contrast against the
 *   backdrop drops from 1.78:1 to roughly 1.5:1.
 * - `saturation` carries the vibrancy and must stay above 1.
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
            radius: 42,
            // A prominent surface sits over more content, so it needs a little
            // more saturation to stay distinct. Both values are above 1, which is
            // the requirement for a glass read rather than a grey blur.
            saturation: this.prominent
              ? (this.isDark ? 1.7 : 2.1)
              : (this.isDark ? 1.5 : 1.9),
            brightness: 1.0,
            color: this.isDark ? '#2EFFFFFF' : '#B8FFFFFF',
            adaptiveColor: AdaptiveColor.DEFAULT,
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
