import http from '@ohos.net.http'
import util from '@ohos.util'
import { SCHOOL_PERSONAL_API, SCHOOL_CARD_API } from '../utils/Constants'
import { decryptSchoolCardEnvelope } from '../utils/CryptoUtil'
import { getAccessToken, getCardToken, clearAccessToken, clearCardToken, saveSchoolSession, saveCardToken, getUsername } from './AuthManager'
import { getCacheEpoch } from './MemoryCache'

export class NativeResult {
  ok: boolean = false
  data: Record<string, Object> = {}
  error: string = ''
  statusCode: number = 0
}
function object(value: Object | undefined): Record<string, Object> {
  if (value === null || value === undefined || Array.isArray(value) || typeof value !== 'object') {
    throw new Error('学校服务响应格式不完整')
  }
  return value as Record<string, Object>
}
function text(value: Object | undefined): string { return value === null || value === undefined ? '' : String(value) }
function body(value: Object | string): Record<string, Object> {
  return object(typeof value === 'string' ? JSON.parse(value) as Object : value)
}
function errorMessage(value: Record<string, Object>): string {
  const message = text(value['message'])
  // Never echo arbitrary upstream content, tokens or HTML into product UI/logs.
  return message.includes('过期') || message.includes('登录') ? '学校登录已过期，请重新认证' : '学校服务暂时无法完成请求'
}
function query(params: Record<string, Object>): string {
  return Object.keys(params).sort().map((key: string): string => encodeURIComponent(key) + '=' + encodeURIComponent(String(params[key]))).join('&')
}
async function request(url: string, token: string, card: boolean, params: Record<string, Object>,
  epoch: number): Promise<NativeResult> {
  const result = new NativeResult()
  if (token.length === 0) {
    result.statusCode = 401
    result.error = card ? '请先在学校一卡通页面完成认证' : '请重新登录学校统一身份认证'
    return result
  }
  const headers: Record<string, Object> = { 'Accept': 'application/json' }
  if (card) { headers['Authorization'] = token; headers['Content-Type'] = 'application/json' }
  else { headers['X-Id-Token'] = token; headers['X-Terminal-Info'] = 'h5' }
  const session = http.createHttp()
  try {
    const res = await session.request(url + (!card && Object.keys(params).length > 0 ? '?' + query(params) : ''), {
      method: card ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers,
      extraData: card ? JSON.stringify(params) : '',
      usingCache: false,
      connectTimeout: 10000,
      readTimeout: 15000,
      maxLimit: 2 * 1024 * 1024,
    } as http.HttpRequestOptions)
    if (epoch !== getCacheEpoch()) { result.error = '登录状态已变化，请重试'; return result }
    result.statusCode = res.responseCode
    if (res.responseCode === 401 || res.responseCode === 403) {
      if (card && token === getCardToken()) clearCardToken(epoch)
      else if (!card && token === getAccessToken()) await clearAccessToken(epoch)
      result.error = card ? '学校一卡通登录已过期，请重新认证' : '学校登录已过期，请重新认证'
      return result
    }
    if (res.responseCode !== 200) { result.error = '学校服务暂时不可用（' + res.responseCode + '）'; return result }
    let envelope = body(res.result as Object | string)
    if (card && envelope['success'] !== true && typeof envelope['data'] === 'string') {
      envelope = body(await decryptSchoolCardEnvelope(envelope['data'] as string))
    }
    if (epoch !== getCacheEpoch()) { result.error = '登录状态已变化，请重试'; return result }
    if (card) {
      if (envelope['success'] !== true) { result.error = errorMessage(envelope); return result }
      result.data = object(envelope['resultData'])
    } else {
      if (envelope['code'] !== 0) { result.error = errorMessage(envelope); return result }
      result.data = object(envelope['data'])
    }
    result.ok = true
  } catch (_e) { result.error = '学校连接或响应校验未完成，请稍后重试' }
  finally { session.destroy() }
  return result
}
export function normalizeSchoolProfile(data: Record<string, Object>): Record<string, Object> {
  const a = object(data['attributes'])
  const account = text(a['accountId'])
  if (account.length === 0) throw new Error('学校未返回校园账号标识')
  return { 'studentId': account, 'name': text(a['userName']), 'college': text(a['organizationName']),
    'major': '', 'className': '', 'grade': '', 'gender': '' }
}
function money(value: Object | undefined): string {
  if (value === undefined || value === null || text(value).trim().length === 0 ||
    !/^-?\d+(?:\.\d+)?$/.test(text(value)) || !Number.isFinite(Number(value))) throw new Error('校园卡金额格式无效')
  return Number(value).toFixed(2)
}
function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const date = new Date(value + 'T00:00:00Z')
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value
}
export function normalizeSchoolBalance(data: Record<string, Object>): Record<string, Object> {
  const user = object(data['user'])
  const accounts: Record<string, Object>[] = []
  const types = user['accTypes']
  if (Array.isArray(types) && types.length > 0) {
    (types as Object[]).forEach((raw: Object) => {
      const item = object(raw)
      if (item['balance'] === undefined || item['balance'] === null) throw new Error('校园卡余额响应不完整')
      accounts.push({ 'typeCode': 'account-' + String(accounts.length), 'typeName': text(item['typeName']) || '校园卡账户',
        'balance': money(item['balance']), 'unit': '元' })
    })
  } else {
    if (user['balance'] === undefined || user['balance'] === null) throw new Error('校园卡余额响应不完整')
    accounts.push({ 'typeCode': 'main', 'typeName': '校园卡账户', 'balance': money(user['balance']), 'unit': '元' })
  }
  return { 'accounts': accounts, 'schoolCardName': text(user['username']), 'schoolCardIdentity': text(user['idSerial']) }
}
export function nativeTransactionsParams(params: Record<string, Object>, now: Date = new Date()): Record<string, Object> {
  const from = text(params['fromDate']) || now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-01'
  const to = text(params['toDate']) || now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0')
  if (!validDate(from) || !validDate(to) || from > to) throw new Error('请选择有效的流水日期')
  const page = params['pageNo'] === undefined ? 1 : Number(params['pageNo'])
  if (!Number.isInteger(page) || page < 1 || page > 100000) throw new Error('流水页码无效')
  return { 'starttime': from, 'endtime': to, 'tradetype': '-1',
    'pageNumber': page - 1, 'pageSize': 20 }
}
export function normalizeSchoolTransactions(data: Record<string, Object>, params: Record<string, Object>): Record<string, Object> {
  if (!Array.isArray(data['rows'])) throw new Error('校园卡流水响应缺少记录数组')
  const transactions: Record<string, Object>[] = (data['rows'] as Object[]).map((raw: Object): Record<string, Object> => {
    const row = object(raw)
    const amount = Number(row['txamt'])
    if (!Number.isSafeInteger(amount) || !/^-?\d+$/.test(text(row['txamt'])) || row['txamt'] === undefined || row['txamt'] === null || text(row['txamt']).trim().length === 0) throw new Error('校园卡流水金额无效')
    return { 'date': text(row['txdate']), 'merchantName': text(row['mername']), 'summary': text(row['mername']),
      'amount': (amount / 100).toFixed(2), 'isRefund': false, 'operation': false, 'journo': '' }
  })
  const totalPages = Number(data['totalpage'])
  if (data['totalpage'] === undefined || !Number.isInteger(totalPages) || totalPages < 0) throw new Error('流水分页信息不完整')
  return { 'fromDate': params['starttime'], 'toDate': params['endtime'], 'pageNo': Number(params['pageNumber']) + 1,
    'pageSize': 20, 'transactions': transactions, 'totalPages': totalPages }
}
export async function callSchoolNative(feature: string, params: Record<string, Object>, epoch: number): Promise<NativeResult> {
  if (feature === 'jw.profile') {
    const result = await request(SCHOOL_PERSONAL_API + '/api/v1/personal/me/user', getAccessToken(), false, {}, epoch)
    if (result.ok) result.data = normalizeSchoolProfile(result.data)
    return result
  }
  if (feature === 'newcard.balance') {
    const result = await request(SCHOOL_CARD_API + '/user/info', getCardToken(), true, {}, epoch)
    if (result.ok) result.data = normalizeSchoolBalance(result.data)
    return result
  }
  if (feature === 'newcard.transactions') {
    const nativeParams = nativeTransactionsParams(params)
    const result = await request(SCHOOL_CARD_API + '/bllt/queryCardSelfTradeList', getCardToken(), true, nativeParams, epoch)
    if (result.ok) result.data = normalizeSchoolTransactions(result.data, nativeParams)
    return result
  }
  const result = new NativeResult()
  result.error = '请打开学校服务完成此项操作'
  result.statusCode = 501
  return result
}
export function schoolTokenExpiry(token: string): number {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('学校认证凭据格式无效')
  let encoded = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  while (encoded.length % 4 !== 0) encoded += '='
  const decoded = new util.TextDecoder().decodeToString(new util.Base64Helper().decodeSync(encoded))
  const payload = body(decoded)
  const seconds = Number(payload['exp'])
  const expiry = seconds * 1000 - 60000
  if (!Number.isFinite(expiry) || expiry <= Date.now()) throw new Error('学校认证凭据已过期')
  return expiry
}
export async function acceptSchoolLogin(token: string, epoch: number): Promise<NativeResult> {
  let expiresAt: number = 0
  try { expiresAt = schoolTokenExpiry(token) } catch (_e) {
    const invalid = new NativeResult(); invalid.error = '学校认证凭据无效或已过期'; return invalid
  }
  if (epoch !== getCacheEpoch()) { const stale = new NativeResult(); stale.error = '登录状态已变化，请重试'; return stale }
  const result = await request(SCHOOL_PERSONAL_API + '/api/v1/personal/me/user', token, false, {}, epoch)
  if (!result.ok || epoch !== getCacheEpoch()) return result
  try {
    const profile = normalizeSchoolProfile(result.data)
    await saveSchoolSession(text(profile['studentId']), token, expiresAt, epoch)
    if (epoch !== getCacheEpoch()) { result.ok = false; result.error = '登录状态已变化，请重试'; return result }
    result.data = profile
  } catch (_e) { result.ok = false; result.error = '学校登录凭据校验或保存失败，请重新认证' }
  return result
}
export async function acceptSchoolCardLogin(token: string, expiresAt: number, epoch: number,
  owner: string): Promise<NativeResult> {
  if (epoch !== getCacheEpoch() || owner.length === 0 || owner !== getUsername() ||
    !Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    const invalid = new NativeResult(); invalid.error = '学校一卡通会话无效或已过期'; return invalid
  }
  const result = await request(SCHOOL_CARD_API + '/user/info', token, true, {}, epoch)
  if (!result.ok || epoch !== getCacheEpoch() || owner !== getUsername()) {
    result.ok = false
    if (result.error.length === 0) result.error = '登录状态已变化，请重试'
    return result
  }
  try {
    result.data = normalizeSchoolBalance(result.data)
    if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) throw new Error('过期')
    saveCardToken(token, expiresAt, epoch, text(result.data['schoolCardName']))
  } catch (_e) { result.ok = false; result.error = '学校一卡通会话校验失败，请重新认证' }
  return result
}
