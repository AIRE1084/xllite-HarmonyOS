import { NativeGlass } from './NativeGlass'

/** API 26 material; legacy layout parameters remain source compatible. */
@Component
export struct LiquidGlass {
  @Prop contentPadding: Length = 16
  @Prop radius: number = 24
  @Prop interactive: boolean = false
  @BuilderParam content: () => void

  build() {
    NativeGlass({ contentPadding: this.contentPadding, radius: this.radius,
      interactive: this.interactive, prominent: false }) {
      this.content()
    }
  }
}
