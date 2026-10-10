
import { AppTheme } from '../../theme/AppTheme'
import { safePush } from '../../utils/RouterHelper'

interface NavItem {
  icon: string
  title: string
  route: string
}

/**
 * 通用底部导航组件
 * 适配现有项目的导航结构
 */
@Component
export struct BottomNavigation {
  @State selectedIndex: number = 0
  items: NavItem[] = []

  build() {
    Column() {
      Row() {
        ForEach(this.items, (item: NavItem, index: number) => {
          Column() {
            Text(item.icon)
              .fontSize(24)
              .margin({ bottom: 4 })
              .opacity(this.selectedIndex === index ? 1 : 0.6)

            Text(item.title)
              .fontSize(AppTheme.fontSize.xs)
              .opacity(this.selectedIndex === index ? 1 : 0.6)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.selectedIndex = index
            safePush(this.getUIContext(), { url: item.route })
          })
        }, (item: NavItem) => item.route)
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.card)
      .shadow({ radius: 4, color: '#00000010', offsetX: 0, offsetY: -2 })
    }
    .width('100%')
  }
}

// 别名导出,修复 MainTabsV2.ets 引用
export { BottomNavigation as AppBottomNavigation }

