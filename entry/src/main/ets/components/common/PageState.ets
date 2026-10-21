import { safePush } from '../../utils/RouterHelper'
import { getColors } from '../../theme/Colors'
import { Typography } from '../../theme/Typography'
import { Motion, motionDuration } from '../../theme/Motion'
import { CampusCard } from './CampusCard'

@Component
export struct PageState {
  @StorageLink('isDark') isDark: boolean = false
  @Prop kind: string = 'empty'
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop action: string = ''
  onAction: () => void = () => {}
  @Prop schoolFeature: string = ''
  build() {
    Scroll() {
      Column({ space: 20 }) {
        CampusCard({ contentPadding: 24, radius: 24 }) {
          Column({ space: 16 }) {
            if (this.kind === 'loading') {
              LoadingProgress().width(40).height(40).color(getColors(this.isDark).primary)
                .accessibilityText('正在加载')
            } else {
              Image(this.kind === 'error' ? $r('app.media.campus_exams') : $r('app.media.campus_schedule'))
                .width(32).height(32).fillColor(getColors(this.isDark).primary)
                .padding(14).constraintSize({ minWidth: 60, minHeight: 60 })
                .backgroundColor(getColors(this.isDark).primaryContainer).borderRadius(20)
                .accessibilityLevel('no')
            }
            Text(this.title).fontSize(Typography.title.fontSize).fontWeight(FontWeight.Bold)
              .fontColor(getColors(this.isDark).onSurface).textAlign(TextAlign.Center).width('100%')
            if (this.message.length > 0) {
              Text(this.message).fontSize(Typography.bodySm.fontSize)
                .fontColor(getColors(this.isDark).onSurfaceVariant).textAlign(TextAlign.Center).width('100%')
            }
            if (this.action.length > 0 && this.kind !== 'loading') {
              Button(this.action).height(48).width('100%').fontSize(Typography.body.fontSize)
                .fontColor(getColors(this.isDark).onPrimary).backgroundColor(getColors(this.isDark).primary)
                .borderRadius(16).onClick(() => this.onAction())
            }
            if (this.schoolFeature.length > 0 && this.kind !== 'loading') {
              Button('打开学校服务').height(48).width('100%').fontSize(Typography.body.fontSize)
                .fontColor(getColors(this.isDark).primary).backgroundColor(getColors(this.isDark).primaryContainer)
                .borderRadius(16).onClick(() => safePush(this.getUIContext(), { url: 'pages/SchoolServicePage',
                  params: { 'feature': this.schoolFeature } }))
            }
          }.width('100%')
        }
      }.width('100%').padding({ left: 20, right: 20, top: 32, bottom: 24 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      // 加载/空/错误状态入场上浮淡出旧态；减少动效时瞬时。
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
        .animation({ duration: motionDuration(Motion.duration.fast), curve: Motion.curve.decelerate }))
  }
}
