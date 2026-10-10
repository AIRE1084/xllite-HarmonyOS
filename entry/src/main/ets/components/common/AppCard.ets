
import { AppTheme } from '../../theme/AppTheme'
import { Logger } from '../../utils/Logger'

const TAG = 'AppCard'

/**
 * 通用卡片组件
 * 支持多种样式，完全兼容现有代码
 */
@Component
export struct AppCard {
  @BuilderParam content?: () => void
  @BuilderParam header?: () => void
  @BuilderParam footer?: () => void
  padding: Length = { top: 16, bottom: 16, left: 16, right: 16 }
  backgroundColor: ResourceStr = AppTheme.colors.card
  borderRadius: Length = AppTheme.radius.lg
  onClick?: () => void
  shadow: boolean = true

  build() {
    Column() {
      if (this.header) {
        this.header()
      }

      if (this.content) {
        this.content()
      }

      if (this.footer) {
        this.footer()
      }
    }
    .padding(this.padding)
    .backgroundColor(this.backgroundColor)
    .borderRadius(this.borderRadius)
    .shadow(this.shadow ? { radius: 8, color: '#00000010', offsetX: 0, offsetY: 2 } : undefined)
    .onClick(() => {
      this.onClick?.()
      Logger.debug(TAG, 'Card clicked')
    })
  }
}

