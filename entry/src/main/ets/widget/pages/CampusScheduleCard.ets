const storage = new LocalStorage()

@Entry(storage)
@Component
struct CampusScheduleCard {
  @LocalStorageProp('heading') heading: string = '新理工 · 课表'
  @LocalStorageProp('status') status: string = '待同步'
  @LocalStorageProp('courseTitle') courseTitle: string = '打开 APP 同步课表'
  @LocalStorageProp('courseTime') courseTime: string = ''
  @LocalStorageProp('courseRoom') courseRoom: string = ''
  @LocalStorageProp('following') following: string = ''
  @LocalStorageProp('footer') footer: string = '点击查看课表'
  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.heading.replace('第 ', '第').replace(' 周', '周')).fontSize(10).fontColor('#526480')
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.status).fontSize(10).fontColor('#315FC4').maxLines(1)
      }.width('100%')
      Column({ space: 6 }) {
        Text(this.courseTitle).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172A46')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if (this.courseTime.length > 0) {
          Text(this.courseTime).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#315FC4').width('100%')
        }
        if (this.courseRoom.length > 0) {
          Text(this.courseRoom).fontSize(11).fontColor('#526480').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
      Text(this.following.length > 0 ? this.following : this.footer).fontSize(9).fontColor('#526480')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }.padding(14).width('100%').height('100%').backgroundColor('#EEF4FF').borderRadius(22)
      .onClick(() => {
        postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { campusRoute: 'schedule' } })
      })
  }
}
