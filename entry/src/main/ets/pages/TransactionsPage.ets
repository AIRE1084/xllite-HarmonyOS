import { getColors } from '../theme/Colors'
import { Typography } from '../theme/Typography'
import { safeBack } from '../utils/RouterHelper'
import { callFeature } from '../services/ApiService'
import { getUsername, getPassword, getCardSessionEpoch, getCardAccountLabel } from '../services/AuthManager'
import { getCacheEpoch } from '../services/MemoryCache'
import { loadUiState, saveUiState } from '../services/UiStateCache'
import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { CampusCard } from '../components/common/CampusCard'
import { Transaction } from '../models/CardTypes'
import { ListDataSource } from '../utils/ListDataSource'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct TransactionsPage {
  @StorageLink('isDark') isDark: boolean = false
  @State cardAccount: string = ''
  @State totalPages: number = 1
  @State nextPage: number = 1
  private cardEpoch: number = -1
  onPageShow(): void { if (this.alive) this.load(true) }
  @State items: Transaction[] = []
  private readonly rows: ListDataSource<Transaction> = new ListDataSource<Transaction>()

  @State loading: boolean = false
  @State loaded: boolean = false
  @State errorMsg: string = ''
  private alive: boolean = false
  private requestVersion: number = 0
  aboutToAppear(): void {
    this.alive = true
    // 会话内恢复上次浏览的列表与分页位置（带卡片会话隔离，换卡/登出后自动失效）。
    const saved: Record<string, Object> | null = loadUiState('transactions', getCardSessionEpoch())
    if (saved !== null && Array.isArray(saved['items'])) {
      this.items = saved['items'] as Transaction[]
      this.rows.replace(this.items)
      this.nextPage = Number(saved['nextPage']) || 1
      this.totalPages = Number(saved['totalPages']) || 1
      this.loaded = true
    }
    this.load()
  }
  aboutToDisappear(): void { this.alive = false; this.requestVersion++; this.loading = false }
  async load(force: boolean = false, append: boolean = false): Promise<void> {
    if (this.loading || !this.alive) return
    this.syncCardSession()
    this.cardAccount = getCardAccountLabel()
    this.loading = true
    this.errorMsg = ''
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const cardEpoch = getCardSessionEpoch()
    const username = getUsername()
    try {
      const res = await callFeature('newcard.transactions', username, getPassword(), { '_forceRefresh': force, 'pageNo': append ? this.nextPage : 1 })
      if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || cardEpoch !== getCardSessionEpoch() || username !== getUsername()) return
      if (res.ok) {
        const data = res.data['transactions'] as Transaction[]
        this.items = append ? this.items.concat(Array.isArray(data) ? data : []) : Array.isArray(data) ? data : []
        this.totalPages = Number(res.data['totalPages']) || 1
        this.nextPage = (Number(res.data['pageNo']) || 1) + 1
        this.rows.replace(this.items)
        this.loaded = true
        saveUiState('transactions', getCardSessionEpoch(), {
          'items': this.items, 'nextPage': this.nextPage, 'totalPages': this.totalPages,
        } as Record<string, Object>)
      } else { this.errorMsg = res.error || '暂时无法更新，请稍后重试' }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && cardEpoch === getCardSessionEpoch() && username === getUsername()) this.errorMsg = '连接未完成，请稍后重试'
    } finally {
      if (this.alive && version === this.requestVersion) { this.syncCardSession(); this.loading = false }
    }
  }

  private syncCardSession(): void {
    if (this.cardEpoch === getCardSessionEpoch()) return
    this.items = []; this.rows.replace([]); this.nextPage = 1; this.totalPages = 1
    this.loaded = false; this.cardAccount = ''; this.errorMsg = ''; this.cardEpoch = getCardSessionEpoch()
  }

  build() {
    Stack() {
    DetailScaffold({ title: '交易流水', subtitle: this.cardAccount.length > 0 ? '校园卡账户 · ' + this.cardAccount : '本月校园收支，清楚可查', busy: this.loading,
      onBack: () => safeBack(this.getUIContext()), onAction: () => this.load(true) }) {
      if (!this.loaded && this.loading) {
        PageState({ kind: 'loading', title: '正在获取交易记录', message: '马上就好，请稍候' })
      } else if (!this.loaded && this.errorMsg.length > 0) {
        PageState({ kind: 'error', schoolFeature: 'newcard.transactions', title: '交易记录暂未更新', message: this.errorMsg,
          action: '重新加载', onAction: () => this.load(true) })
      } else {
        if (this.errorMsg.length > 0) {
          RefreshNotice({ message: '更新失败，已保留上次数据', busy: this.loading, onRetry: () => this.load(true) })
        }
        if (this.items.length === 0) {
          PageState({ title: '暂无交易记录', message: '新的交易会在这里显示', action: '刷新看看', onAction: () => this.load(true) })
        } else {
          List({ space: 12 }) {
            LazyForEach(this.rows, (t: Transaction) => {
              ListItem() {
                CampusCard({ contentPadding: 18 }) {
                  Row({ space: 12 }) {
                    Column({ space: 6 }) {
                      Text(t.summary || '校园卡交易').fontSize(Typography.bodyLg.fontSize).fontWeight(FontWeight.Medium)
                        .fontColor(getColors(this.isDark).onSurface).width('100%')
                      if (t.merchantName.length > 0) {
                        Text(t.merchantName).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
                      }
                      Text(t.date).fontSize(Typography.caption.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text(t.amount).fontSize(Typography.title.fontSize).fontWeight(FontWeight.Bold)
                      .fontColor(t.isRefund ? getColors(this.isDark).success : getColors(this.isDark).onSurface)
                  }.width('100%')
                }
              }
            }, (t: Transaction, index: number): string => t.journo + '|' + t.date + '|' + index)
            ListItem() {
              Text(this.loading ? '正在更新记录…' : '已显示 ' + this.items.length + ' 笔本月交易').fontSize(Typography.caption.fontSize)
                .fontColor(getColors(this.isDark).onSurfaceVariant).width('100%').textAlign(TextAlign.Center).padding(12)
            }
          }.layoutWeight(1).width('100%').padding({ left: 20, right: 20, bottom: 24 }).scrollBar(BarState.Off)
            .onReachEnd(() => { if (!this.loading && this.nextPage <= this.totalPages) this.load(false, true) })
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
