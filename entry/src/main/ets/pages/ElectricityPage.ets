import { DetailScaffold } from '../components/common/DetailScaffold'
import { getCacheEpoch } from '../services/MemoryCache'
import { getColors } from '../theme/Colors'
import { safeBack } from '../utils/RouterHelper'
import { callFeature, CallResult } from '../services/ApiService'
import { getUsername, getPassword } from '../services/AuthManager'
import { ElectricityAccount, ElecRechargeConfig, ElecRechargePayResult, AmountOption, PayMethod } from '../models/CardTypes'

@Entry
@Component
struct ElectricityPage {
  @StorageLink('safeAreaTop') safeAreaTop: number = 0
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0
  @StorageLink('isDark') isDark: boolean = false
  private alive: boolean = false
  private requestVersion: number = 0
  aboutToAppear(): void { this.alive = true }
  aboutToDisappear(): void { this.alive = false; this.requestVersion++; this.loading = false; this.paymentPassword = '' }
  @State step: number = 1
  @State roomQuery: string = ''
  @State electricity: ElectricityAccount | null = null
  @State rechargeConfig: ElecRechargeConfig | null = null
  @State selectedAmount: string = ''
  @State selectedPayCode: string = ''
  @State paymentPassword: string = ''
  @State showPasswordInput: boolean = false
  @State loading: boolean = false
  @State paying: boolean = false
  @State errorMsg: string = ''
  @State resultMsg: string = ''

  async queryElectricity(): Promise<void> {
    if (!this.alive || this.loading || this.paying) return
    if (this.roomQuery.trim().length === 0) {
      this.errorMsg = '请输入宿舍号'
      return
    }
    this.loading = true
    this.errorMsg = ''
    const params: Record<string, Object> = { 'roomQuery': this.roomQuery.trim() }
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
    const res: CallResult = await callFeature('newcard.electricity.account', username, getPassword(), params)
    if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
    if (res.ok) {
      this.electricity = res.data as Object as ElectricityAccount
      this.step = 2
    } else {
      this.errorMsg = res.error
    }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) {
        this.errorMsg = '连接未完成，请稍后重试'
      }
    } finally { if (this.alive && version === this.requestVersion) this.loading = false }
  }
  async loadRechargeConfig(): Promise<void> {
    if (!this.alive || this.loading || this.paying) return
    this.loading = true
    this.errorMsg = ''
    const params: Record<string, Object> = { 'roomQuery': this.roomQuery.trim() }
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
    const res: CallResult = await callFeature('newcard.electricity.recharge.config', username, getPassword(), params)
    if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
    if (res.ok) {
      this.rechargeConfig = res.data as Object as ElecRechargeConfig
      this.showPasswordInput = this.rechargeConfig.needPaymentPassword
      this.step = 3
    } else {
      this.errorMsg = res.error
    }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) {
        this.errorMsg = '连接未完成，请稍后重试'
      }
    } finally { if (this.alive && version === this.requestVersion) this.loading = false }
  }
  async handlePay(): Promise<void> {
    if (!this.alive || this.loading || this.paying) return
    if (this.selectedAmount.length === 0) return
    if (this.showPasswordInput && this.paymentPassword.length === 0) {
      this.errorMsg = '请输入支付密码'
      return
    }
    this.paying = true
    this.errorMsg = ''
    const params: Record<string, Object> = {
      'roomQuery': this.roomQuery.trim(),
      'amount': this.selectedAmount,
      'payCode': this.selectedPayCode.length > 0 ? this.selectedPayCode : '06',
    }
    if (this.showPasswordInput) {
      params['paymentPassword'] = this.paymentPassword
    }
    const version = ++this.requestVersion
    const epoch = getCacheEpoch()
    const username = getUsername()
    try {
    const res: CallResult = await callFeature('newcard.electricity.recharge.pay', username, getPassword(), params)
    if (!this.alive || version !== this.requestVersion || epoch !== getCacheEpoch() || username !== getUsername()) return
    if (res.ok) {
      const order: ElecRechargePayResult = res.data as Object as ElecRechargePayResult
      this.resultMsg = '充值成功！金额: ¥' + order.amount
      this.step = 4
    } else {
      this.errorMsg = res.error
    }
    } catch (_error) {
      if (this.alive && version === this.requestVersion && epoch === getCacheEpoch() && username === getUsername()) {
        this.errorMsg = '支付请求未完成，请先查询电量与交易结果再尝试'
      }
    } finally { if (this.alive && version === this.requestVersion) this.paying = false }
  }
  back(): void {
    if (this.paying) return
    this.requestVersion++
    this.loading = false
    if (this.step === 1) {
      safeBack(this.getUIContext())
    } else if (this.step === 2) {
      this.step = 1
      this.electricity = null
    } else if (this.step === 3) {
      this.step = 2
      this.rechargeConfig = null
      this.selectedAmount = ''
      this.selectedPayCode = ''
      this.paymentPassword = ''
    } else if (this.step === 4) {
      safeBack(this.getUIContext())
    }
  }

  build() {
    Stack() {
      DetailScaffold({ title: this.step === 4 ? '充值完成' : '电费服务', subtitle: '查询宿舍电量与充值', action: '',
        onBack: () => this.back() }) {
        Scroll() {
          Column() {
      if (this.step === 1) {
        Column() {
          Text('输入宿舍号').fontColor(getColors(this.isDark).onSurface).fontSize(15).margin({ top: 24, bottom: 12 }).alignSelf(ItemAlign.Start).width('90%')
          TextInput({ placeholder: '如 9#312', text: this.roomQuery })
            .fontColor(getColors(this.isDark).onSurface).placeholderColor(getColors(this.isDark).onSurfaceVariant)
            .caretColor(getColors(this.isDark).primary).backgroundColor(getColors(this.isDark).surfaceVariant)
            .onChange((v: string) => { this.roomQuery = v })
            .height(48)
            .width('90%')

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg).fontColor(getColors(this.isDark).error).fontSize(14).margin({ top: 8 }).alignSelf(ItemAlign.Start).width('90%')
          }

          Button(this.loading ? '查询中...' : '查询电费')
            .width('90%').height(48).backgroundColor(getColors(this.isDark).primary).borderRadius(16)
            .margin({ top: 16 })
            .enabled(!this.loading)
            .onClick(() => { this.queryElectricity() })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else if (this.step === 2 && this.electricity) {
        Column() {
          Column() {
            Text('剩余电量').fontSize(14).fontColor(getColors(this.isDark).onSurfaceVariant)
            Text(this.electricity.remainingElectricity.value + ' ' + this.electricity.remainingElectricity.unit)
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor(Number(this.electricity.remainingElectricity.value) < 10 ? getColors(this.isDark).error : getColors(this.isDark).primary)
              .margin({ top: 8 })
            Text(this.electricity.room.buildingName + ' ' + this.electricity.room.roomName)
              .fontSize(13).fontColor(getColors(this.isDark).onSurfaceVariant).margin({ top: 8 })
          }
          .width('90%')
          .padding(24)
          .backgroundColor(getColors(this.isDark).primaryContainer)
          .borderRadius(16)
          .margin({ top: 24 })
          .alignItems(HorizontalAlign.Center)

          Row() {
            Button('去充值')
              .height(48).layoutWeight(1).backgroundColor(getColors(this.isDark).primary).borderRadius(16)
              .fontColor(getColors(this.isDark).onPrimary)
              .margin({ right: 8 })
              .enabled(!this.loading && !this.paying)
              .onClick(() => { this.loadRechargeConfig() })
            Button('重新查询')
              .height(48).layoutWeight(1).backgroundColor(getColors(this.isDark).surfaceVariant).borderRadius(16)
              .fontColor(getColors(this.isDark).onSurface)
              .onClick(() => {
                this.step = 1
                this.electricity = null
                this.errorMsg = ''
              })
          }
          .width('90%')
          .margin({ top: 24 })

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg).fontColor(getColors(this.isDark).error).fontSize(12).margin({ top: 12 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else if (this.step === 3 && this.rechargeConfig) {
        Column() {
          Column() {
            Text('电费充值').fontColor(getColors(this.isDark).onSurface).fontSize(16).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)
            Text('当前电量: ' + this.rechargeConfig.remainingElectricity.value + this.rechargeConfig.remainingElectricity.unit)
              .fontSize(13).fontColor(getColors(this.isDark).onSurfaceVariant).margin({ top: 6 })
            Text('账户余额: ¥' + this.rechargeConfig.cardBalance.value)
              .fontSize(13).fontColor(getColors(this.isDark).onSurfaceVariant).margin({ top: 2 })
            Text('电价: ' + this.rechargeConfig.price.value + ' 元/' + this.rechargeConfig.price.unit)
              .fontSize(13).fontColor(getColors(this.isDark).onSurfaceVariant).margin({ top: 2 })
          }
          .width('90%')
          .padding(16)
          .backgroundColor(getColors(this.isDark).surface)
          .borderRadius(12)
          .margin({ top: 16 })
          .alignItems(HorizontalAlign.Start)

          Text('选择充值金额').fontColor(getColors(this.isDark).onSurface).fontSize(15).fontWeight(FontWeight.Medium)
            .margin({ top: 20, bottom: 12 }).width('90%')
          Row() {
            ForEach(this.rechargeConfig.amountOptions, (opt: AmountOption) => {
              Button(opt.name)
                .height(48)
                .layoutWeight(1)
                .backgroundColor(this.selectedAmount === opt.amount ? getColors(this.isDark).primary : getColors(this.isDark).surfaceVariant)
                .fontColor(this.selectedAmount === opt.amount ? getColors(this.isDark).onPrimary : getColors(this.isDark).onSurface)
                .borderRadius(16)
                .margin({ right: 8 })
                .onClick(() => { this.selectedAmount = opt.amount })
            }, (opt: AmountOption): string => opt.id)
          }
          .width('90%')

          if (this.showPasswordInput) {
            Text('支付密码').fontColor(getColors(this.isDark).onSurface).fontSize(15).fontWeight(FontWeight.Medium)
              .margin({ top: 20, bottom: 8 }).width('90%')
            TextInput({ placeholder: '请输入一卡通支付密码', text: this.paymentPassword })
              .fontColor(getColors(this.isDark).onSurface).placeholderColor(getColors(this.isDark).onSurfaceVariant)
              .caretColor(getColors(this.isDark).primary).backgroundColor(getColors(this.isDark).surfaceVariant)
              .type(InputType.Password)
              .onChange((v: string) => { this.paymentPassword = v })
              .height(48).width('90%')
          }

          if (this.errorMsg.length > 0) {
            Text(this.errorMsg).fontColor(getColors(this.isDark).error).fontSize(12).margin({ top: 12 }).width('90%')
          }

          Button(this.paying ? '支付中...' : '确认支付')
            .width('90%').height(48).backgroundColor(getColors(this.isDark).primary).borderRadius(16)
            .fontColor(getColors(this.isDark).onPrimary)
            .margin({ top: 20 })
            .enabled(this.selectedAmount.length > 0 && !this.paying)
            .onClick(() => { this.handlePay() })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else if (this.step === 4) {
        Column() {
          Text(this.resultMsg)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(getColors(this.isDark).success)
            .margin({ top: 60 })
          Button('返回首页')
            .width('90%').height(48).backgroundColor(getColors(this.isDark).primary).borderRadius(16)
            .fontColor(getColors(this.isDark).onPrimary)
            .margin({ top: 32 })
            .onClick(() => { safeBack(this.getUIContext()) })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

          }.width('100%').padding({ bottom: 28 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%')
  }
}
