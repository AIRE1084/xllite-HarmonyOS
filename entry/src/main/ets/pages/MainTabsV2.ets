
import { AppBottomNavigation } from '../components/common/BottomNavigation'
import { HomePageV2 } from './HomePageV2'
import { ProfilePage } from './ProfilePage'
import { TodoPage } from './TodoPage'
import { AppTheme } from '../theme/AppTheme'

interface TabItem {
  icon: string
  title: string
  page: () => void
}

@Entry
@Component
struct MainTabsV2 {
  @State selectedIndex: number = 0

  private tabs: TabItem[] = [
    { icon: '🏠', title: '首页', page: () => HomePageV2 },
    { icon: '📋', title: '待办', page: () => TodoPage },
    { icon: '👤', title: '我的', page: () => ProfilePage },
  ]

  build() {
    Stack() {
      // 页面内容
      this.tabs[this.selectedIndex].page()
        .width('100%')
        .height('100%')

      // 底部导航
      Column() {
        AppBottomNavigation({
          items: this.tabs.map((tab, index) => ({
            icon: tab.icon,
            title: tab.title,
            route: tab.page.name
          })),
          selectedIndex: this.selectedIndex,
          onSelect: (index) => {
            this.selectedIndex = index
          }
        })
      }
      .width('100%')
      .alignContent(Alignment.Bottom)
    }
    .width('100%')
    .height('100%')
  }
}

