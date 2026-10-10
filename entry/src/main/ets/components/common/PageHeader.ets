
import { AppTheme } from '../../theme/AppTheme'
import { safeBack } from '../../utils/RouterHelper'

/**
 * 页面头部组件
 * 统一所有页面的头部样式
 */
@Component
export struct PageHeader {
  @Prop title: string = ''
  @Prop showBack: boolean = true
  @BuilderParam actions?: () => void

  build() {
    Row() {
      if (this.showBack) {
        Icon({ src: $r('app.media.ic_back') })
          .size({ width: 24, height: 24 })
          .onClick(() => {
            safeBack(this.getUIContext())
          })
          .margin({ right: 12 })
      }

      Text(this.title)
        .fontSize(AppTheme.fontSize.lg)
        .fontWeight(FontWeight.Bold)
        .flexGrow(1)

      if (this.actions) {
        this.actions()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.colors.card)
    .shadow({ radius: 2, color: '#00000008', offsetX: 0, offsetY: 1 })
  }
}

