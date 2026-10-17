const todoStorage = new LocalStorage()

@Entry(todoStorage)
@Component
struct CampusTodoCard {
  @LocalStorageProp('openCount') openCount: number = 0
  @LocalStorageProp('overdueCount') overdueCount: number = 0
  @LocalStorageProp('firstTitle') firstTitle: string = '打开应用同步待办'
  @LocalStorageProp('secondTitle') secondTitle: string = ''
  @LocalStorageProp('thirdTitle') thirdTitle: string = ''
  build() {
    Column({ space: 8 }) {
      Row() {
        Text('待办任务').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#526480').layoutWeight(1)
        Text(this.openCount.toString()).fontSize(15).fontColor('#315FC4')
      }.width('100%')
      Column({ space: 8 }) {
        Text(this.firstTitle).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#172A46')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if (this.secondTitle.length > 0) {
          Text(this.secondTitle).fontSize(13).fontColor('#526480').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
        if (this.thirdTitle.length > 0) {
          Text(this.thirdTitle).fontSize(13).fontColor('#526480').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
      Text(this.overdueCount > 0 ? this.overdueCount.toString() + ' 项已过期 · 点击管理' : '点击管理任务')
        .fontSize(10).fontColor('#526480').maxLines(1).width('100%')
    }.padding(14).width('100%').height('100%').backgroundColor('#EEF4FF').borderRadius(22)
      .onClick(() => {
        postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { campusRoute: 'todo' } })
      })
  }
}
