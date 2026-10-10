import { safeReplace, safePush } from '../utils/RouterHelper'
import { loadSession, clearSession } from '../services/AuthManager'
import { getColors, ColorPalette } from '../theme/Colors'
import { AmbientBackground } from '../components/AmbientBackground'
import { NativeGlass } from '../components/NativeGlass'

@Entry
@Component
struct LoginPage {
  @State restoring: boolean = true
  @State loading: boolean = false
  @State forgotLoading: boolean = false
  @State errorMsg: string = ''
  @State showForgot: boolean = false
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
  aboutToDisappear(): void { this.alive = false }
  onThemeChange(): void { this.palette = getColors(this.isDark) }
  async handleLogin(): Promise<void> {
    if (this.loading || this.restoring || this.showForgot) return
    this.loading = true; this.errorMsg = ''
    try {
      await clearSession()
      if (this.alive) safePush(this.getUIContext(), { url: 'pages/SchoolServicePage', params: { 'mode': 'login' } })
    } catch (_e) { if (this.alive) this.errorMsg = '认证页面准备失败，请重试' }
    finally { if (this.alive) this.loading = false }
  }
  async handleForgot(): Promise<void> {
    if (this.forgotLoading || this.showForgot) return
    this.forgotLoading = true
    try {
      // School CAS password reset entry; opens the school service flow, returns to login.
      if (this.alive) safePush(this.getUIContext(), { url: 'pages/SchoolServicePage', params: { 'mode': 'login', 'forgot': '1' } })
    } catch (_e) { if (this.alive) this.errorMsg = '找回入口准备失败，请重试' }
    finally { if (this.alive) this.forgotLoading = false }
  }
  build() {
    Stack() {
      AmbientBackground()
      if (this.restoring) {
        Column({ space: 16 }) {
          LoadingProgress().width(32).height(32).color(this.palette.primary)
          Text('正在进入校园').fontSize(14).fontColor(this.palette.onSurfaceVariant)
        }
      } else if (!this.showForgot) {
        Scroll() {
          Column({ space: 32 }) {
            Column({ space: 12 }) {
              Image($r('app.media.campus_schedule')).width(44).height(44).fillColor(this.palette.primary)
              Text('掌上新理工').fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
              Text('课程、校园卡与每日安排，一处掌握').fontSize(13).fontColor(this.palette.onSurfaceVariant)
            }.width('100%').alignItems(HorizontalAlign.Start)
            NativeGlass({ contentPadding: 24, radius: 28, prominent: true }) {
              Column({ space: 18 }) {
                Text('连接你的校园').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface).width('100%')
                Text('使用新疆理工学院统一身份认证。账号、密码与验证码在学校登录页中填写。')
                  .fontSize(14).fontColor(this.palette.onSurfaceVariant).lineHeight(24).width('100%')
                Text('cas.xjit.edu.cn').fontSize(13).fontColor(this.palette.primary).width('100%')
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
            }
            Text('登录后直接连接学校服务，无需重定向').fontSize(12).fontColor(this.palette.onSurfaceVariant)
          }.width('100%').padding({ left: 24, right: 24, top: this.safeAreaTop + 64, bottom: this.safeAreaBottom + 32 })
            .constraintSize({ maxWidth: 520 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
      } else {
        Column({ space: 20 }) {
          Text('找回密码').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
          Text('请通过学校统一身份认证入口重置 CAS 密码，完成后返回本应用重新登录。')
            .fontSize(13).fontColor(this.palette.onSurfaceVariant).lineHeight(22)
          Button(this.forgotLoading ? '正在打开…' : '前往学校找回').width('100%').height(52)
            .backgroundColor(this.palette.primary).fontColor(this.palette.onPrimary).fontSize(15)
            .fontWeight(FontWeight.Medium).borderRadius(16).enabled(!this.forgotLoading)
            .onClick(() => this.handleForgot())
          Button('返回登录').width('100%').height(44).backgroundColor(Color.Transparent)
            .fontColor(this.palette.onSurfaceVariant).fontSize(14)
            .onClick((): void => { this.showForgot = false; this.forgotLoading = false })
        }.width('100%').padding({ left: 24, right: 24, top: this.safeAreaTop + 96, bottom: this.safeAreaBottom + 48 })
          .constraintSize({ maxWidth: 460 }).alignItems(HorizontalAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
