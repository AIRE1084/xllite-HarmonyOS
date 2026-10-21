import { safeReplace } from '../utils/RouterHelper'
import { gatewayLogin, acceptGatewayLogin } from '../services/XlliteGateway'
import { getCacheEpoch } from '../services/MemoryCache'
import { loadSession, clearSession } from '../services/AuthManager'
import { getColors, ColorPalette } from '../theme/Colors'
import { ThemeWash } from '../components/common/ThemeWash'
import { Motion, motionDuration } from '../theme/Motion'

@Entry
@Component
struct LoginPage {
  @State username: string = ''
  @State password: string = ''
  @State captcha: string = ''
  @State captchaRequired: boolean = false
  @State restoring: boolean = true
  @State loading: boolean = false
  @State forgotLoading: boolean = false
  @State errorMsg: string = ''
  @State showForgot: boolean = false
  @State showDisclosure: boolean = false
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @State palette: ColorPalette = getColors(false)
  private alive: boolean = false
  async aboutToAppear(): Promise<void> {
    this.alive = true; this.onThemeChange()
    try {
      const hasSession = await loadSession()
      if (!this.alive) return
      // Already signed in: skip the login screen entirely, no redirect.
      if (hasSession) safeReplace(this.getUIContext(), { url: 'pages/MainTabs' })
      else this.restoring = false
    } catch (_e) { if (this.alive) { this.restoring = false; this.errorMsg = '登录状态读取失败，请重新认证' } }
  }
  aboutToDisappear(): void { this.alive = false; this.password = ''; this.captcha = ''; this.captchaRequired = false }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  async handleLogin(): Promise<void> {
    if (this.loading || this.restoring || this.showForgot) return
    if (this.username.trim().length === 0 || this.password.length === 0) {
      this.errorMsg = '请输入学号和统一身份认证密码'; return
    }
    this.loading = true; this.errorMsg = ''
    const username: string = this.username.trim()
    const password: string = this.password
    const captcha: string = this.captcha.trim()
    try {
      await clearSession()
      if (!this.alive) return
      const epoch: number = getCacheEpoch()
      const response = await gatewayLogin(username, password, captcha)
      if (!this.alive || epoch !== getCacheEpoch()) return
      if (!response.ok) {
        this.errorMsg = response.error
        if (response.error.includes('验证码')) this.captchaRequired = true
        return
      }
      const saved = await acceptGatewayLogin(username, response.data, epoch)
      if (!this.alive || epoch !== getCacheEpoch()) return
      if (!saved.ok) { this.errorMsg = saved.error; return }
      this.password = ''; this.captcha = ''
      safeReplace(this.getUIContext(), { url: 'pages/MainTabs' })
    } catch (_e) { if (this.alive) this.errorMsg = '登录未完成，请稍后重试' }
    finally { if (this.alive) this.loading = false }
  }
  async handleForgot(): Promise<void> {
    if (this.loading) return
    this.password = ''; this.captcha = ''; this.showForgot = true
  }
  toggleDisclosure(): void { this.showDisclosure = !this.showDisclosure }
  build() {
    Stack() {
      if (this.restoring) {
        Column({ space: 16 }) {
          LoadingProgress().width(32).height(32).color(this.palette.primary)
          Text('正在进入校园').fontSize(14).fontColor(this.palette.onSurfaceVariant)
        }
      } else if (!this.showForgot) {
        Scroll() {
          Column({ space: 22 }) {
            Column({ space: 12 }) {
              Image($r('app.media.icon')).width(60).height(60).borderRadius(18)
                .accessibilityText('新理之山，山脊与书页')
              Text('掌上新理工').fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
            }.width('100%').alignItems(HorizontalAlign.Center)
              Column({ space: 18 }) {
                TextInput({ placeholder: '学号 / 校园账号', text: this.username })
                  .height(52).fontColor(this.palette.onSurface).placeholderColor(this.palette.onSurfaceVariant)
                  .backgroundColor(this.palette.surfaceVariant).borderRadius(16).enabled(!this.loading)
                  .onChange((value: string): void => { this.username = value })
                  .accessibilityText('校园账号')
                TextInput({ placeholder: '统一身份认证密码', text: this.password })
                  .type(InputType.Password).height(52).fontColor(this.palette.onSurface)
                  .placeholderColor(this.palette.onSurfaceVariant).backgroundColor(this.palette.surfaceVariant)
                  .borderRadius(16).enabled(!this.loading)
                  .onChange((value: string): void => { this.password = value })
                  .accessibilityText('统一身份认证密码')
                if (this.captchaRequired) {
                TextInput({ placeholder: '验证码（仅在学校要求时填写）', text: this.captcha })
                  .height(48).fontColor(this.palette.onSurface).placeholderColor(this.palette.onSurfaceVariant)
                  .backgroundColor(this.palette.surfaceVariant).borderRadius(16).enabled(!this.loading)
                  .onChange((value: string): void => { this.captcha = value })
                }
                if (this.errorMsg.length > 0) { Text(this.errorMsg).fontSize(12).fontColor(this.palette.error).width('100%') }
                Button(this.loading ? '正在连接…' : '登录').width('100%').height(52)
                  .backgroundColor(this.palette.primary).fontColor(this.palette.onPrimary).fontSize(16)
                  .fontWeight(FontWeight.Medium).borderRadius(16).enabled(!this.loading)
                  .onClick(() => this.handleLogin())
                Button('忘记密码')
                  .width('100%').height(44).backgroundColor(Color.Transparent)
                  .fontColor(this.palette.onSurfaceVariant).fontSize(13)
                  .enabled(!this.forgotLoading).onClick(() => this.handleForgot())
              }.width('100%')
            Button(this.showDisclosure ? '收起登录与数据说明' : '登录与数据说明')
              .backgroundColor(Color.Transparent).fontColor(this.palette.onSurfaceVariant).fontSize(12)
              .onClick(() => this.toggleDisclosure())
            if (this.showDisclosure) {
              Text('登录数据将通过 HTTPS 提交至 https://xllite.sayqz.com 网关，由网关连接学校服务。服务器可能为续登保留凭据；保存期限与删除方式尚待服务运营方确认。密码不保存在本机，不代表服务器不处理或保留密码。')
                .fontSize(12).fontColor(this.palette.onSurfaceVariant).lineHeight(20).width('100%')
            }
          }.width('100%').padding({ left: 24, right: 24, top: this.safeAreaTop + 28, bottom: this.safeAreaBottom + 24 })
            .constraintSize({ maxWidth: 520 })
        }.width('100%').height('100%').align(Alignment.Center).scrollBar(BarState.Off)
      } else {
        Column({ space: 20 }) {
          Text('找回密码').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
          Text('密码由学校统一身份认证平台管理。请联系学校信息服务部门重置密码，完成后在这里重新登录。')
            .fontSize(13).fontColor(this.palette.onSurfaceVariant).lineHeight(22)
          Button('重新登录').width('100%').height(44).backgroundColor(Color.Transparent)
            .fontColor(this.palette.onSurfaceVariant).fontSize(14)
            .onClick((): void => { this.showForgot = false; this.forgotLoading = false })
        }.width('100%').padding({ left: 24, right: 24, top: this.safeAreaTop + 48, bottom: this.safeAreaBottom + 32 })
          .constraintSize({ maxWidth: 460 }).alignItems(HorizontalAlign.Center)
      }
      ThemeWash()
    }.width('100%').height('100%').backgroundColor(this.palette.background)
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
