@Component
export struct CampusIcon {
  @Prop source: ResourceStr = $r('app.media.campus_home')
  @Prop iconSize: number = 44
  @Prop badgeColor: ResourceColor = '#EEF2FF'

  build() {
    Row() {
      Image(this.source)
        .width(this.iconSize * 0.52)
        .height(this.iconSize * 0.52)
        .objectFit(ImageFit.Contain)
    }
      .width(this.iconSize)
      .height(this.iconSize)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.badgeColor)
      .borderRadius(this.iconSize * 0.30)
      .hitTestBehavior(HitTestMode.None)
  }
}
