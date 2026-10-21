export interface QRCodeData {
  mode: string
  qrcode: string
  qrcodeType: string
  expiresInSeconds: number
  balance: string
  idSerial: string
  userName: string
  displayInfo: boolean
  displayBalance: boolean
}

export interface AccountBalance {
  typeCode: string
  typeName: string
  balance: string
  unit: string
}

export interface AmountOption {
  id: string
  amount: string
  name: string
}

export interface PayMethod {
  code: string
  tradeType: string
  name: string
  h5: boolean
  successToHome: boolean
  signBind: string
}

export interface RoomInfo {
  query: string
  buildingName: string
  levelName: string
  roomName: string
}

export interface Quantity {
  value: string
  unit: string
}

export interface ElecAccount {
  utilityAccount: string
  utilityUsername: string
  utilityStatusName: string
  accStatusName: string
}

export interface ElectricityAccount {
  remainingElectricity: Quantity
  room: RoomInfo
}

export interface ElecRechargeConfig {
  room: RoomInfo
  account: ElecAccount
  remainingElectricity: Quantity
  cardBalance: Quantity
  price: Quantity
  amountOptions: AmountOption[]
  payMethods: PayMethod[]
  needPaymentPassword: boolean
  canPayOther: boolean
  confirm: boolean
  hostApp: boolean
  amtInputDisabled: boolean
  tip: string
}

export interface Transaction {
  date: string
  summary: string
  merchantName: string
  amount: string
  isRefund: boolean
  operation: boolean
  journo: string
}

export interface TransactionsData {
  fromDate: string
  toDate: string
  pageNo: number
  pageSize: number
  transactions: Transaction[]
}

export interface RechargeConfigData {
  balance: string
  idSerial: string
  username: string
  amountOptions: AmountOption[]
  payMethods: PayMethod[]
  canPayOther: boolean
  hostApp: boolean
  daLianPayEnable: boolean
  wapPayEnable: boolean
}

export interface PayResult {
  type: string
  payCode: string
  partnerJourno: string
  h5Url: string
  htmlPost: string
  officialTransferUrl: string
}

export interface RechargeOrderResult {
  amount: string
  payMethod: PayMethod
  partnerJourno: string
  payResult: PayResult
}

export interface ElecRechargePayResult {
  amount: string
  room: RoomInfo
  account: ElecAccount
  payMethod: PayMethod
  partnerJourno: string
  payResult: PayResult
}
