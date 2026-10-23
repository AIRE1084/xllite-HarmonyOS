import { AmbientBackground } from '../components/AmbientBackground'
import { getColors, ColorPalette } from '../theme/Colors'
import { SCHOOL_FINANCE } from '../utils/Constants'
import { safeToast } from '../utils/ToastHelper'
import webview from '@ohos.web.webview'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 财务系统（底部导航的一页）。
 *
 * 预加载：这一页在 App 启动后约两秒被挂载（`MainTabs` 里控制），此时 WebView
 * 已经开始拉取页面与资源，用户再点「财务」时通常已经就绪，不会再看到长时间白屏。
 * 挂载时机刻意延后，避免和首页首屏抢带宽与主线程。
 *
 * 地址集中在 `Constants.SCHOOL_FINANCE`，拿到财务系统直连后只改那一处。
 */
@Component
export struct FinanceTab {
  @StorageLink('isDark') @Watch('onThemeChange') isDark: boolean = false
  @State palette: ColorPalette = getColors(false)
  @State loading: boolean = true
  @State failed: boolean = false
  private controller: webview.WebviewController = new webview.WebviewController()
  private alive: boolean = false

  onThemeChange(): void { this.palette = getColors(this.isDark) }
  aboutToAppear(): void { this.alive = true; this.onThemeChange() }
  aboutToDisappear(): void { this.alive = false }
  private reload(): void {
    this.failed = false
    this.loading = true
    try {
      this.controller.loadUrl(SCHOOL_FINANCE)
    } catch (_error) {
      this.failed = true; this.loading = false
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      AmbientBackground()
      Column() {
        Row() {
          Text('财务系统').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.palette.onSurface)
          Blank()
          if (this.failed) {
            Text('重新加载').fontSize(13).fontColor(this.palette.primary)
              .onClick(() => this.reload())
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 10 })

        Stack() {
          Web({ src: SCHOOL_FINANCE, controller: this.controller })
            .width('100%').height('100%')
            .darkMode(this.isDark ? WebDarkMode.On : WebDarkMode.Off)
            .onPageEnd(() => { if (this.alive) this.loading = false })
            .onErrorReceive((event: OnErrorReceiveEvent) => {
              // 主文档加载失败才提示；子资源失败不该把整页判成不可用。
              if (event && event.request && event.request.isMainFrame()) {
                if (this.alive) { this.loading = false; this.failed = true }
                safeToast(this.getUIContext(), '财务系统暂时打不开，请稍后重试')
              }
            })
          if (this.loading) {
            Column({ space: 12 }) {
              LoadingProgress().width(32).height(32).color(this.palette.primary)
              Text('正在打开财务系统').fontSize(13).fontColor(this.palette.onSurfaceVariant)
            }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          }
        }
        .layoutWeight(1).width('100%').borderRadius(16).clip(true)
        .margin({ left: 16, right: 16, bottom: 16 })
      }.width('100%').height('100%')
    }.width('100%').height('100%')
  }
}
