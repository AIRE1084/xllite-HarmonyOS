
import { AppTheme } from '../../theme/AppTheme'
import { Logger } from '../../utils/Logger'

const TAG = 'AppButton'

/**
 * 通用按钮组件
 * 支持多种样式和状态
 */
@Component
export struct AppButton {
  @Prop text: string = ''
  @Prop loading: boolean = false
  @Prop enabled: boolean = true
  @Prop type: 'primary' | 'secondary' | 'text' = 'primary'
  @Prop icon?: string
  onButtonClick?: () => void

  private getBackgroundColor(): ResourceStr {
    if (!this.enabled) return '#CCCCCC'
    switch (this.type) {
      case 'primary': return AppTheme.colors.primary
      case 'secondary': return '#F0F2F5'
      case 'text': return 'transparent'
      default: return AppTheme.colors.primary
    }
  }

  private getTextColor(): ResourceStr {
    if (!this.enabled) return '#999999'
    switch (this.type) {
      case 'primary': return '#FFFFFF'
      case 'secondary': return AppTheme.colors.textPrimary
      case 'text': return AppTheme.colors.primary
      default: return '#FFFFFF'
    }
  }

  build() {
    Button() {
      if (this.loading) {
        LoadingProgress()
          .color(this.getTextColor())
          .size({ width: 20, height: 20 })
      } else {
        Row() {
          if (this.icon) {
            Text(this.icon)
              .fontSize(20)
              .margin({ right: this.text ? 8 : 0 })
          }
          if (this.text) {
            Text(this.text)
              .fontSize(AppTheme.fontSize.md)
              .fontWeight(FontWeight.Medium)
          }
        }
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(AppTheme.radius.md)
    .enabled(this.enabled && !this.loading)
    .onClick(() => {
      if (!this.loading && this.enabled) {
        this.onButtonClick?.()
        Logger.debug(TAG, `Button clicked: ${this.text}`)
      }
    })
  }
}

