/**
 * 简易占位 tab 内容组件 - 用于 BlurTabBar 演示
 * 5 tab 路由: 发现/搜索/歌单/下载/设置
 */
@Component
export struct PlaceholderTab {
  @Prop title: string = ''
  @Prop icon: string = ''

  build() {
    Column() {
      Blank().height(120)
      Text(this.icon)
        .fontSize(96)
        .fontColor('#3F6BEA')
      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#171A21')
        .margin({ top: 16 })
      Text('这是 ' + this.title + ' tab 的占位内容')
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}