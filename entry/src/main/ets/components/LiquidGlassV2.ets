
import { getColors, ColorPalette } from '../theme/Colors'
import { Logger } from '../utils/Logger'

const TAG = 'LiquidGlassV2'

/**
 * LiquidGlassV2 - 优化版液态玻璃容器
 *
 * 优化点：
 * 1. 调整模糊参数，默认更自然的效果
 * 2. 优化高光效果，使用渐变更真实
 * 3. 调整阴影参数，更贴合真实玻璃质感
 * 4. 增加滚动场景优化，提升性能
 * 5. 更灵活的配置选项
 * 6. 更好的主题适配
 *
 * 完全兼容原有API，可以直接替换使用
 */
@Component
export struct LiquidGlassV2 {
  @Prop contentPadding: number | Length = 16
  @Prop radius: number = 16
  @Prop glassBlur: number = 20 // 降低默认模糊值，更自然
  @Prop elevation: number = 3 // 阴影强度
  @Prop highlightOpacity: number = 0.15
  @Prop borderWidth: number = 0.5
  @Prop enableScrollOptimization: boolean = true // 滚动时自动降低模糊
  @BuilderParam content: () => void

  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State currentBlur: number = 20

  aboutToAppear(): void {
    this.palette = getColors(this.isDark)
    this.currentBlur = this.glassBlur

    // 监听滚动事件，优化性能
    if (this.enableScrollOptimization) {
      this.setupScrollListener()
    }
  }

  onThemeChange(): void {
    this.palette = getColors(this.isDark)
  }

  /**
   * 滚动场景优化：当组件在Scroll中时，自动降低模糊值提升性能
   */
  private setupScrollListener(): void {
    try {
      const context = this.getUIContext()
      if (context && typeof context.subscribe === 'function') {
        context.subscribe('scroll', () => {
          this.currentBlur = Math.min(this.glassBlur, 10)
        })
        context.subscribe('scrollEnd', () => {
          this.currentBlur = this.glassBlur
        })
      }
    } catch (e) {
      Logger.warn(TAG, 'Failed to setup scroll listener', e)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 优化后的渐变高光条，更自然
      LinearGradient() {
        Column()
          .width('100%')
          .height(8)
          .opacity(this.highlightOpacity)
      }
      .width('100%')
      .height(8)
      .linearGradient({
        direction: GradientDirection.LeftToRight,
        colors: [
          { color: this.palette.glassHighlight, offset: 0 },
          { color: this.palette.glassHighlight + '80', offset: 0.5 },
          { color: this.palette.glassHighlight, offset: 1 }
        ]
      })
      .borderRadius(this.radius)
      .hitTestBehavior(HitTestMode.None)

      // 内容容器
      Column() {
        this.content()
      }
      .width('100%')
      .padding(this.contentPadding)
    }
    .width('100%')
    .borderRadius(this.radius)
    .backdropBlur(this.currentBlur)
    // 优化背景色：使用主题色的半透明版本
    .backgroundColor(this.isDark
      ? 'rgba(30, 30, 30, 0.75)'
      : 'rgba(255, 255, 255, 0.75)'
    )
    .border({
      width: this.borderWidth,
      color: this.palette.glassHighlight + (this.isDark ? '60' : '40'),
    })
    // 优化阴影：更真实的玻璃阴影
    .shadow({
      radius: this.elevation * 4,
      color: this.palette.glassShadow + (this.isDark ? 'CC' : '33'),
      offsetX: 0,
      offsetY: this.elevation * 2,
    })
  }
}

