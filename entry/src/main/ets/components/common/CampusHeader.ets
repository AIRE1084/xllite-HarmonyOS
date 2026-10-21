import { getColors } from '../../theme/Colors'
import { Typography } from '../../theme/Typography'

@Component
export struct CampusHeader {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('isDark') isDark: boolean = false
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop action: string = ''
  @Prop loading: boolean = false
  onAction: () => void = () => {}
  build() {
    Row({ space: 12 }) {
      Column({ space: 7 }) {
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(Typography.bodySm.fontSize).fontColor(getColors(this.isDark).onSurfaceVariant)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.title.length > 0) {
          Text(this.title).fontSize(25).fontWeight(FontWeight.Bold)
            .fontColor(getColors(this.isDark).onSurface)
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.action.length > 0) {
        Button({ type: ButtonType.Circle }) {
          if (this.loading) {
            LoadingProgress().width(20).height(20).color(getColors(this.isDark).primary)
          } else {
            // 缺口圆环，形状即“转圈”语义，点击后换成真实旋转进度
            Progress({ value: 78, total: 100, type: ProgressType.Ring })
              .width(20).height(20).color(getColors(this.isDark).primary)
              .style({ strokeWidth: 2.4 })
          }
        }
        .width(40).height(40).backgroundColor(getColors(this.isDark).primaryContainer)
        .enabled(!this.loading).accessibilityText(this.loading ? '正在刷新' : '刷新')
        .onClick(() => this.onAction())
      }
    }.width('100%').padding({ left: 20, right: 20, top: this.safeAreaTop + 12, bottom: 16 })
  }
}
