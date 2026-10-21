import { getColors } from '../../theme/Colors'
import { Motion, motionDuration } from '../../theme/Motion'

@Component
export struct RefreshNotice {
  @StorageLink('isDark') isDark: boolean = false
  @Prop message: string = ''
  @Prop busy: boolean = false
  onRetry: () => void = () => {}
  build() {
    Row({ space: 12 }) {
      Text(this.message).fontSize(13).fontColor(getColors(this.isDark).onSurfaceVariant).layoutWeight(1)
      Button('重试').height(44).fontSize(13).fontColor(getColors(this.isDark).primary)
        .backgroundColor(getColors(this.isDark).primaryContainer).borderRadius(14)
        .enabled(!this.busy).onClick(() => this.onRetry())
    }.width('100%').padding({ left: 20, right: 20, bottom: 12 })
      // 刷新失败提示从顶部滑入；减少动效时瞬时。
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 }))
        .animation({ duration: motionDuration(Motion.duration.fast), curve: Motion.curve.decelerate }))
  }
}
