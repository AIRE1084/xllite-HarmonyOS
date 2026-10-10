
import window from '@ohos.window'
import { AppTheme } from '../../theme/AppTheme'

/**
 * 主题提供者组件，支持深色模式
 * 自动跟随系统主题
 */
@Component
export struct ThemeProvider {
  @BuilderParam children: () => void
  @State isDark: boolean = false

  aboutToAppear(): void {
    // 监听系统主题变化
    window.getLastWindow(this.getUIContext()).then((win) => {
      win.on('windowModeChange', (data) => {
        this.isDark = data.windowMode === window.WindowMode.DARK
      })
      this.isDark = win.getWindowProperties().windowMode === window.WindowMode.DARK
    })
  }

  build() {
    Stack() {
      this.children()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDark ? '#121212' : AppTheme.colors.background)
  }
}

