import { glassMaterial, supportsImmersiveMaterial } from '../theme/Materials'

@Component
export struct NativeGlass {
  @Prop contentPadding: Length = 16
  @Prop radius: number = 24
  @Prop interactive: boolean = false
  @Prop prominent: boolean = false
  @BuilderParam content: () => void
  @StorageLink('isDark') isDark: boolean = false
  @State nativeSupported: boolean = supportsImmersiveMaterial()
  aboutToAppear(): void { this.nativeSupported = supportsImmersiveMaterial() }
  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.nativeSupported) {
        Column() { this.content() }
          .width('100%').padding(this.contentPadding).borderRadius(this.radius)
          .systemMaterial(glassMaterial(this.isDark, this.interactive, this.prominent))
      } else {
        Column() { this.content() }
          .width('100%').padding(this.contentPadding).borderRadius(this.radius)
          .backgroundColor(this.isDark ? '#EC19283D' : '#F2F7FAFF')
      }
      Row().width('78%').height(1)
        .linearGradient({ angle: 90, colors: this.isDark
          ? [['#009EB8EA', 0], ['#B8D9E9FF', 0.5], ['#009EB8EA', 1]]
          : [['#00FFFFFF', 0], ['#FFFFFFFF', 0.5], ['#00FFFFFF', 1]] })
        .margin({ top: 1 }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }.width('100%').borderRadius(this.radius)
      // A separate shell keeps the native material node free of custom backgrounds.
      .linearGradient({ angle: 145, colors: this.isDark
        ? [['#702B4668', 0], ['#30142135', 0.55], ['#50284252', 1]]
        : [['#D9FFFFFF', 0], ['#72F5F9FF', 0.55], ['#AAF2FBF9', 1]] })
      .border({ width: 1, color: this.isDark ? '#507F9BBE' : '#E8FFFFFF' })
      .shadow({ radius: this.prominent ? 20 : 12, color: this.isDark ? '#28000000' : '#18364F78', offsetY: 8 })
  }
}
