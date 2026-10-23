import { DetailHeader } from '../components/common/DetailHeader'
import { FinanceTab } from './FinanceTab'
import { AmbientBackground } from '../components/AmbientBackground'
import { ThemeWash } from '../components/common/ThemeWash'
import { safeBack } from '../utils/RouterHelper'

/**
 * 财务系统的路由页。
 *
 * 业务与渲染全部在 `FinanceTab` 里，这里只做一层壳：同一条页面既能从
 * 首页「常用服务」进入，也是底部导航的一页，两边共用一份实现。
 */
@Entry
@Component
struct FinancePage {
  build() {
    Stack({ alignContent: Alignment.Top }) {
      AmbientBackground()
      Column() {
        DetailHeader({ title: '财务系统', subtitle: '学费 · 住宿费 · 缴费记录',
          onBack: () => safeBack(this.getUIContext()) })
        FinanceTab()
      }.width('100%').height('100%')
      ThemeWash()
    }.width('100%').height('100%')
  }
}
