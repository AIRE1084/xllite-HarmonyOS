import webview from '@ohos.web.webview'
import { getColors } from '../theme/Colors'
import { safeBack, safeReplace, safeClear } from '../utils/RouterHelper'
import { isSchoolHttps, isSuperappUrl, isCardUrl, schoolLoginUrl, schoolFeatureUrl } from '../utils/SchoolRoutes'
import { acceptSchoolLogin, acceptSchoolCardLogin } from '../services/SchoolNativeApi'
import { getUsername } from '../services/AuthManager'
import { getCacheEpoch } from '../services/MemoryCache'
import { Motion, motionDuration } from '../theme/Motion'

interface SchoolPageParams { mode?: string; feature?: string; title?: string; forgot?: string }
// Fixed script, evaluated only on the exact school service origin. No passwords/cookies are read.
const PORTAL_SESSION_SCRIPT: string = '(function(){try{if(typeof uni==="undefined")return "";return JSON.stringify({token:uni.getStorageSync("idToken")||""});}catch(e){return "";}})()'
const CARD_SESSION_SCRIPT: string = '(function(){try{if(typeof uni==="undefined")return "";return JSON.stringify({token:uni.getStorageSync("accessToken")||"",expiresAt:Number(uni.getStorageSync("expirationTime"))+Number(uni.getStorageSync("accessTokenExpire"))*1000});}catch(e){return "";}})()'

@Entry
@Component
struct SchoolServicePage {
  @StorageLink('isDark') isDark: boolean = false
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('appActive') @Watch('onActiveChange') appActive: boolean = true
  @State sourceUrl: string = ''
  @State title: string = '学校服务'
  @State loading: boolean = true
  @State errorMsg: string = ''
  @State connected: boolean = false
  private controller: webview.WebviewController = new webview.WebviewController()
  private loginMode: boolean = false
  private cardMode: boolean = false
  private forgotMode: boolean = false
  private alive: boolean = false
  private visible: boolean = true
  private inspecting: boolean = false
  private epoch: number = 0
  private owner: string = ''
  private timer: number = -1
  private lastToken: string = ''
  private retryAt: number = 0
  private retryCount: number = 0
  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as SchoolPageParams
    this.loginMode = params?.mode === 'login'
    this.forgotMode = params?.forgot === '1'
    const feature = params?.feature || ''
    this.cardMode = feature.startsWith('newcard.')
    this.title = this.loginMode ? (this.forgotMode ? '找回密码' : '学校统一身份认证') : params?.title || '学校服务'
    this.sourceUrl = this.loginMode ? schoolLoginUrl() : schoolFeatureUrl(feature)
    this.epoch = getCacheEpoch(); this.owner = getUsername(); this.alive = true
  }
  onPageShow(): void { this.visible = true; this.startInspecting() }
  onPageHide(): void { this.visible = false; this.stopInspecting() }
  aboutToDisappear(): void { this.alive = false; this.lastToken = ''; this.stopInspecting() }
  onActiveChange(): void { if (this.appActive) this.startInspecting(); else this.stopInspecting() }
  private valid(): boolean { return this.alive && this.visible && this.appActive && this.epoch === getCacheEpoch() }
  private stopInspecting(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1 } }
  private startInspecting(): void {
    if (!this.valid() || this.timer >= 0 || (!this.loginMode && !this.cardMode)) return
    this.timer = setInterval(() => { this.inspectSession() }, 1200)
  }
  async inspectSession(): Promise<void> {
    if (!this.valid() || this.inspecting) return
    this.inspecting = true
    try {
      const url = this.controller.getUrl()
      if (!(this.loginMode ? isSuperappUrl(url) : this.cardMode && isCardUrl(url))) return
      const raw = await this.controller.runJavaScript(this.loginMode ? PORTAL_SESSION_SCRIPT : CARD_SESSION_SCRIPT)
      if (!this.valid() || this.controller.getUrl() !== url || raw.length > 32768) return
      let decoded: Object | string = JSON.parse(raw) as Object | string
      if (typeof decoded === 'string') { if (decoded.length === 0) return; decoded = JSON.parse(decoded) as Object }
      if (typeof decoded !== 'object' || decoded === null || Array.isArray(decoded)) return
      const value = decoded as Record<string, Object>
      const token = typeof value['token'] === 'string' ? value['token'] as string : ''
      if (token.length === 0 || token === this.lastToken || Date.now() < this.retryAt) return
      const result = this.loginMode ? await acceptSchoolLogin(token, this.epoch) :
        await acceptSchoolCardLogin(token, Number(value['expiresAt']), this.epoch, this.owner)
      if (!this.valid()) return
      if (result.ok) {
        this.lastToken = token; this.retryCount = 0; this.retryAt = 0
        if (this.loginMode) {
          this.stopInspecting()
          safeClear(this.getUIContext())
          safeReplace(this.getUIContext(), { url: 'pages/MainTabs' })
        } else { this.connected = true }
      } else {
        this.errorMsg = result.error; this.retryCount++
        this.retryAt = this.retryCount >= 3 ? Number.POSITIVE_INFINITY : Date.now() + 5000
      }
    } catch (_e) { /* Pages may not have completed their own session initialization yet. */ }
    finally { this.inspecting = false }
  }
  build() {
    Column() {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(26).fontWeight(FontWeight.Medium)
            .fontColor(getColors(this.isDark).primary).offset({ y: -1 })
        }
        .width(40).height(44).backgroundColor(Color.Transparent)
        .accessibilityText('返回上一页').onClick(() => safeBack(this.getUIContext()))
        Column({ space: 3 }) {
          Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(getColors(this.isDark).onSurface)
          Text(this.loginMode ? '新疆理工学院 · 统一认证' : '新疆理工学院 · 学校服务')
            .fontSize(11).fontColor(getColors(this.isDark).onSurfaceVariant)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.connected) { Text('已连接').fontSize(12).fontColor(getColors(this.isDark).primary) }
      }.width('100%').padding({ left: 8, right: 16, top: this.safeAreaTop, bottom: 8 })
      if (this.loading) { Progress({ value: 35, total: 100, type: ProgressType.Linear }).width('100%').height(2).color(getColors(this.isDark).primary) }
      if (this.errorMsg.length > 0) {
        Row({ space: 8 }) {
          Text(this.errorMsg).fontSize(12).fontColor(getColors(this.isDark).error).layoutWeight(1)
          Button('重试').height(44).fontSize(12).onClick(() => { this.errorMsg = ''; this.lastToken = ''; this.retryAt = 0; this.retryCount = 0; this.controller.refresh() })
        }.width('100%').padding({ left: 16, right: 16 })
      }
      if (this.sourceUrl.length > 0) {
        Web({ src: this.sourceUrl, controller: this.controller, incognitoMode: true })
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).mixedMode(MixedMode.None)
          .onOverrideUrlLoading((request: WebResourceRequest): boolean => {
            const allowed = isSchoolHttps(request.getRequestUrl())
            if (!allowed) { this.errorMsg = '跳转地址超出学校服务范围，已停止跳转' }
            return !allowed
          })
          .onPageBegin(() => { this.loading = true })
          .onPageEnd(() => { this.loading = false; this.startInspecting(); this.inspectSession() })
          .onErrorReceive((event) => { if (event?.request.isMainFrame()) { this.loading = false; this.errorMsg = '学校页面暂时无法加载，请重试' } })
          .onHttpErrorReceive((event) => { if (event?.request.isMainFrame()) { this.loading = false; this.errorMsg = '学校页面暂时不可用，请重试' } })
          .layoutWeight(1).width('100%')
      }
    }.height('100%').width('100%').padding({ bottom: this.safeAreaBottom }).backgroundColor(getColors(this.isDark).surface)
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
