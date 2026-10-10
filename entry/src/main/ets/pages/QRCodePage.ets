import { DetailScaffold } from '../components/common/DetailScaffold'
import { PageState } from '../components/common/PageState'
import { RefreshNotice } from '../components/common/RefreshNotice'
import { getCacheEpoch } from '../services/MemoryCache'
import { getColors } from '../theme/Colors'
import { safeBack } from '../utils/RouterHelper'
import { callFeature, CallResult } from '../services/ApiService'
import { getUsername, getPassword } from '../services/AuthManager'

@Entry
@Component
struct QRCodePage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @StorageLink('appActive') @Watch('onAppActiveChange') appActive: boolean = true
  private alive: boolean = false
  private pageActive: boolean = true
  private requestBusy: boolean = false
  private expiresAt: number = 0
  @State qrcode: string = ''
  @State balance: string = ''
  @State userName: string = ''
  @State idSerial: string = ''
  @State countdown: number = 30
  @State loading: boolean = true
  @State errorMsg: string = ''
  @State displayBalance: boolean = true
  private refreshTimer: number = -1
  private countTimer: number = -1

  aboutToAppear(): void { this.alive = true; this.fetchCode() }
  aboutToDisappear(): void { this.alive = false; this.stopTimers() }
  onPageShow(): void { this.pageActive = true; this.resume() }
  onPageHide(): void { this.pageActive = false; this.stopTimers() }
  onAppActiveChange(): void { if (this.appActive) this.resume(); else this.stopTimers() }
  private resume(): void {
    if (!this.alive || !this.pageActive || !this.appActive) return
    if (Date.now() >= this.expiresAt) this.qrcode = ''
    this.fetchCode()
  }
  private stopTimers(): void {
    if (this.refreshTimer >= 0) clearTimeout(this.refreshTimer)
    if (this.countTimer >= 0) clearInterval(this.countTimer)
    this.refreshTimer = -1
    this.countTimer = -1
  }
  private startTimers(): void {
    this.stopTimers()
    if (!this.alive || !this.pageActive || !this.appActive) return
    this.countTimer = setInterval(() => {
      this.countdown = Math.max(0, Math.ceil((this.expiresAt - Date.now()) / 1000))
      if (this.countdown === 0) this.qrcode = ''
    }, 1000)
    this.refreshTimer = setTimeout(() => { this.fetchCode() }, Math.max(1, this.expiresAt - Date.now()))
  }
  async fetchCode(): Promise<void> {
    if (!this.alive || !this.pageActive || !this.appActive || this.requestBusy) return
    this.requestBusy = true
    this.loading = true
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
      const empty: Record<string, Object> = {}
      const res: CallResult = await callFeature('newcard.campus_code.qrcode', username, getPassword(), empty)
      if (!this.alive || epoch !== getCacheEpoch() || username !== getUsername()) return
      if (res.ok) {
        const d = res.data
        this.qrcode = d['qrcode'] as string
        this.balance = d['balance'] as string
        this.userName = d['userName'] as string
        this.idSerial = d['idSerial'] as string
        const db = d['displayBalance']
        this.displayBalance = typeof db === 'boolean' ? db : true
        const exp = d['expiresInSeconds']
        this.countdown = typeof exp === 'number' && Number.isFinite(exp) && exp > 0 ? Math.ceil(exp) : 30
        this.expiresAt = Date.now() + this.countdown * 1000
        this.errorMsg = ''
        this.startTimers()
      } else {
        this.errorMsg = res.error
        if (Date.now() >= this.expiresAt) this.qrcode = ''
      }
    } catch (_error) {
      if (this.alive && epoch === getCacheEpoch() && username === getUsername()) {
        this.errorMsg = '付款码暂时无法更新，请稍后重试'
        if (Date.now() >= this.expiresAt) this.qrcode = ''
      }
    } finally {
      this.requestBusy = false
      if (this.alive) this.loading = false
    }
  }

  build() {
    Stack() {
      DetailScaffold({ title: '校园付款码', subtitle: '出示付款码，轻松完成校园支付', busy: this.loading,
        onBack: () => safeBack(this.getUIContext()), onAction: () => this.fetchCode() }) {
        if (this.loading && this.qrcode.length === 0) {
          PageState({ kind: 'loading', title: '正在生成付款码', message: '请稍候，付款码即将准备好' })
        } else if (this.qrcode.length === 0) {
          PageState({ kind: 'error', schoolFeature: 'newcard.campus_code.qrcode', title: '付款码暂不可用', message: this.errorMsg || '付款码已过期，请刷新后使用',
            action: '重新获取', onAction: () => this.fetchCode() })
        } else {
          if (this.errorMsg.length > 0) {
            RefreshNotice({ message: '更新失败，当前付款码到期后将自动隐藏', busy: this.loading, onRetry: () => this.fetchCode() })
          }
          Scroll() {
            Column({ space: 12 }) {
              Column() {
                QRCode(this.qrcode).color('#FF000000').backgroundColor('#FFFFFFFF').width(220).height(220)
              }.padding(36).backgroundColor('#FFFFFFFF').borderRadius(24)
              Text('有效期剩余 ' + this.countdown + ' 秒').fontSize(14).fontColor(getColors(this.isDark).onSurfaceVariant)
              if (this.displayBalance) {
                Text('¥ ' + this.balance).fontSize(32).fontWeight(FontWeight.Bold).fontColor(getColors(this.isDark).onSurface)
                Text('校园卡余额').fontSize(12).fontColor(getColors(this.isDark).onSurfaceVariant)
              }
              Text(this.userName + '  ' + this.idSerial).fontSize(14).fontColor(getColors(this.isDark).onSurfaceVariant)
              Text('付款码自动更新，请勿向他人分享').fontSize(12).fontColor(getColors(this.isDark).onSurfaceVariant).margin({ top: 8 })
            }.width('100%').padding({ top: 24, bottom: 32 })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
      }
    }.width('100%').height('100%')
  }
}
