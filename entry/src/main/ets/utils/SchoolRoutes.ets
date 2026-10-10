import { SCHOOL_CAS, SCHOOL_SUPERAPP, SCHOOL_CARD } from './Constants'

export function isSchoolHttps(url: string): boolean {
  // Exact host boundary: credentials, userinfo, ports and lookalike domains are rejected.
  return /^https:\/\/(?:[a-z0-9-]+\.)*xjit\.edu\.cn(?:\/|$)/i.test(url)
}
export function isSuperappUrl(url: string): boolean {
  return url === SCHOOL_SUPERAPP || url.startsWith(SCHOOL_SUPERAPP + '/')
}
export function isCardUrl(url: string): boolean {
  return url === SCHOOL_CARD || url.startsWith(SCHOOL_CARD + '/')
}
export function schoolLoginUrl(): string {
  return SCHOOL_CAS + '?service=' + encodeURIComponent(SCHOOL_SUPERAPP + '/pages/tab/index/index')
}
export function hasNativeAdapter(feature: string): boolean {
  return feature === 'jw.profile' || feature === 'newcard.balance' || feature === 'newcard.transactions'
}
export function schoolFeatureUrl(feature: string): string {
  switch (feature) {
    case 'jw.schedule': return SCHOOL_SUPERAPP + '/pages/tab/schedule/schedule'
    case 'jw.profile': return SCHOOL_SUPERAPP + '/pages/tab/my/my'
    case 'newcard.balance': return SCHOOL_CARD + '/#/pages_home/home'
    case 'newcard.transactions': return SCHOOL_CARD + '/#/pages_plugins/mybill/transaction/transaction'
    case 'newcard.campus_code.qrcode': return SCHOOL_CARD + '/#/pages_plugins/cardQrcode/cardQrcode'
    case 'newcard.recharge.config':
    case 'newcard.recharge.create_order': return SCHOOL_CARD + '/#/pages_plugins/recharge/recharge'
    case 'newcard.electricity.account':
    case 'newcard.electricity.recharge.config':
    case 'newcard.electricity.recharge.pay': return SCHOOL_CARD + '/#/pages_payment/electrictyFees/electrictyFees'
    default: return SCHOOL_SUPERAPP + '/pages/tab/service/index'
  }
}
