import { getColors } from '../theme/Colors'
import { Typography } from '../theme/Typography'
import { safeBack } from '../utils/RouterHelper'
import { callFeature } from '../services/ApiService'
import { getUsername, getCardSessionEpoch } from '../services/AuthManager'
import { getCacheEpoch } from '../services/MemoryCache'
import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { CampusCard } from '../components/common/CampusCard'
import { AccountBalance } from '../models/CardTypes'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct BalancePage {
  @StorageLink('isDark') isDark: boolean = false
  @State cardAccount: string = ''
  private cardEpoch: number = -1
  onPageShow(): void { if (this.alive) this.load(true) }
  @State accounts: AccountBalance[] = []

  @State loading: boolean = false
  @State loaded: boolean = false
  @State errorMsg: string = ''
  private alive: boolean = false
  private requestVersion: number = 0
  aboutToAppear(): void { this.alive = true; this.load() }
  aboutToDisappear(): void { this.alive = false; this.requestVersion++; this.loading = false }
  async load(force: boolean = false): Promise<void> {
    if (this.loading || !this.alive) return
    this.syncCardSession()
    this.loading = true
    this.errorMsg = ''
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const cardEpoch = getCardSessionEpoch()
    const username = getUsername()
    try {
      const res = await callFeature('newcard.balance', username, { '_forceRefresh': force })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || cardEpoch !== getCardSessionEpoch() || username !== getUsername()) return
      if (res.ok) {
        const data = res.data['accounts'] as AccountBalance[]
        this.accounts = Array.isArray(data) ? data : []
        this.cardAccount = typeof res.data['schoolCardName'] === 'string' ? res.data['schoolCardName'] as string : ''
        this.loaded = true
      } else { this.errorMsg = res.error || '暂时无法更新，请稍后重试' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && cardEpoch === getCardSessionEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) { this.syncCardSession(); this.loading = false }
    }
  }

  private syncCardSession(): void {
    if (this.cardEpoch === getCardSessionEpoch()) return
    this.accounts = []
    this.loaded = false; this.cardAccount = ''; this.errorMsg = ''; this.cardEpoch = getCardSessionEpoch()
  }

  build() {
    Stack() {
    DetailScaffold({ title: '校园卡余额', subtitle: '校园生活的每一天，心中有数', busy: this.loading,
      onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
      if (!this.loaded && this.loading) {
        PageState({ kind: 'loading', title: '正在获取账户信息', message: '马上就好，请稍候' })
      } else if (!this.loaded && this.errorMsg.length > 0) {
        PageState({ kind: 'error', schoolFeature: 'newcard.balance', title: '账户信息暂未更新', message: this.errorMsg,
          action: '重新加载', onAction: () => this.load(true) })
      } else {
        if (this.errorMsg.length > 0) {
          RefreshNotice({ message: '更新失败，已保留上次数据', busy: this.loading, onRetry: () => this.load(true) })
        }
        if (this.accounts.length === 0) {
          PageState({ title: '暂无账户信息', message: '暂时没有可显示的校园卡账户', action: '刷新看看', onAction: () => this.load(true) })
        } else {
          Scroll() {
            Column({ space: 16 }) {
              if (this.cardAccount.length > 0) {
                Text('校园卡账户 · ' + this.cardAccount).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant).width('100%')
              }
              ForEach(this.accounts, (item: AccountBalance) => {
                CampusCard({ contentPadding: 24, radius: 24 }) {
                  Column({ space: 12 }) {
                    Text(item.typeName).fontSize(Typography.bodyLg.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
                    Text('¥ ' + item.balance).fontSize(Typography.display.fontSize).fontWeight(FontWeight.Bold)
                      .fontColor(getColors(this.isDark).onSurface)
                    Text(item.unit).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
                  }.width('100%').alignItems(HorizontalAlign.Start)
                }
              }, (item: AccountBalance): string => item.typeCode)
            }.width('100%').padding({ left: 20, right: 20, bottom: 24 })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
      }
    }
    }.width('100%').height('100%')
  }

  // 统一页面过渡：前进时新页右侧 30% 淡入、底层静止；返回时镜像右出淡出。
  // 减少动效偏好下时长为 0（同时禁用设备默认页面动画，保持瞬时切换）。
  pageTransition(): void {
    PageTransitionEnter({ type: RouteType.Push, duration: motionDuration(Motion.duration.base), curve: Motion.curve.decelerate })
      .translate({ x: motionDuration(Motion.duration.base) > 0 ? '30%' : '0%' }).opacity(motionDuration(Motion.duration.base) > 0 ? 0 : 1)
    PageTransitionExit({ type: RouteType.Push, duration: motionDuration(Motion.duration.base) })
    PageTransitionEnter({ type: RouteType.Pop, duration: motionDuration(Motion.duration.base) })
    PageTransitionExit({ type: RouteType.Pop, duration: motionDuration(Motion.duration.base), curve: Motion.curve.accelerate })
      .translate({ x: motionDuration(Motion.duration.base) > 0 ? '30%' : '0%' }).opacity(motionDuration(Motion.duration.base) > 0 ? 0 : 1)
  }

}
