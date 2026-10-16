import { getColors } from '../../theme/Colors'
import { Motion } from '../../theme/Motion'

/**
 * 主题切换过渡：深浅色翻转时，先用旧背景色盖住整屏，再在约 320ms 内淡出，
 * 让新主题"洗"出来，避免生硬的瞬间跳变。减少动效偏好下不播放。
 */
@Component
export struct ThemeWash {
  @StorageLink('isDark') @Watch('onFlip') isDark: boolean = false
  @State washColor: string = getColors(false).background
  @State washOpacity: number = 0
  private revealTimer: number = -1
  onFlip(): void {
    if (this.revealTimer >= 0) clearTimeout(this.revealTimer)
    this.revealTimer = -1
    if (AppStorage.get<boolean>('reduceMotion') === true) {
      this.washOpacity = 0
      return
    }
    this.washColor = getColors(!this.isDark).background
    this.washOpacity = 1
    // 等一帧让不透明覆盖层完成渲染，再开始淡出，保证旧色先盖住再揭示新主题。
    this.revealTimer = setTimeout(() => {
      this.revealTimer = -1
      this.getUIContext().animateTo({ duration: Motion.duration.base, curve: Motion.curve.decelerate }, (): void => {
        this.washOpacity = 0
      })
    }, 16)
  }
  aboutToDisappear(): void {
    if (this.revealTimer >= 0) clearTimeout(this.revealTimer)
    this.revealTimer = -1
    this.washOpacity = 0
  }
  build() {
    Rect()
      .width('100%').height('100%')
      .fill(this.washColor)
      .opacity(this.washOpacity)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}
