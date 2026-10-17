import { clearTodoReminders } from './TodoReminderService'
import { clearTodos } from './TodoService'
import { clearCampusCompanion } from './CampusCompanionService'
import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import webview from '@ohos.web.webview'
import { clearAllCachedValues, setCacheContext, getCacheEpoch } from './MemoryCache'

const PREFS_NAME: string = 'xjit_session'
const SESSION_PROTOCOL: string = 'school-native-v1'
const GATEWAY_AUTH_SOURCE: string = 'xllite-gateway'
let savedUsername: string = ''
let savedAccessToken: string = ''
let savedTokenExpiresAt: number = 0
let savedAuthSource: string = ''
let cardToken: string = ''
let cardExpiresAt: number = 0
let cardSessionEpoch: number = 0
let cardAccountLabel: string = ''
const cardCacheNamespace: string = Date.now().toString(36) + '-' + Math.random().toString(36).slice(2)
let appContext: common.UIAbilityContext | null = null
let prefsTask: Promise<preferences.Preferences> | null = null
let persistenceTask: Promise<void> = Promise.resolve()

export function setAuthContext(ctx: common.UIAbilityContext): void {
  appContext = ctx
  setCacheContext(ctx)
}
function getPrefs(): Promise<preferences.Preferences> | null {
  if (appContext === null) return null
  if (prefsTask === null) prefsTask = preferences.getPreferences(appContext, PREFS_NAME).catch((e: Error) => {
    prefsTask = null
    throw e
  })
  return prefsTask
}
function enqueue(action: () => Promise<void>): Promise<void> {
  const task = persistenceTask.then(action)
  persistenceTask = task.catch((_e: Error) => {})
  return task
}
export async function loadElectricityRoom(): Promise<string> {
  const epoch = getCacheEpoch()
  const owner = savedUsername
  let room: string = ''
  await enqueue(async () => {
    const task = getPrefs()
    if (task === null || owner.length === 0 || epoch !== getCacheEpoch() || owner !== savedUsername) return
    const prefs = await task
    const value = await prefs.get('electricity_room', '')
    if (epoch === getCacheEpoch() && owner === savedUsername && typeof value === 'string') room = value
  })
  return room
}
export function saveElectricityRoom(value: string): Promise<void> {
  const epoch = getCacheEpoch()
  const owner = savedUsername
  const room = value.trim()
  return enqueue(async () => {
    const task = getPrefs()
    if (task === null || owner.length === 0 || room.length === 0 || epoch !== getCacheEpoch() || owner !== savedUsername) return
    const prefs = await task
    if (epoch !== getCacheEpoch() || owner !== savedUsername) return
    await prefs.put('electricity_room', room)
    await prefs.flush()
  })
}
export async function loadSession(): Promise<boolean> {
  const epoch = getCacheEpoch()
  let valid: boolean = false
  await enqueue(async () => {
    const task = getPrefs()
    if (task === null || epoch !== getCacheEpoch()) return
    const prefs = await task
    const protocol = await prefs.get('protocol', '')
    if (epoch !== getCacheEpoch()) return
    // Legacy IP-gateway tokens and passwords must never enter school requests.
    if (protocol !== SESSION_PROTOCOL) {
      savedUsername = ''; savedAccessToken = ''; savedTokenExpiresAt = 0; savedAuthSource = ''
      clearCardToken()
      await prefs.clear()
      await prefs.flush()
      await Promise.all([clearAllCachedValues(), clearCampusCompanion().catch((_e: Error) => {})])
      return
    }
    const u = await prefs.get('username', '')
    const t = await prefs.get('access_token', '')
    const exp = await prefs.get('token_expires_at', 0)
    const source = await prefs.get('auth_source', '')
    if (epoch !== getCacheEpoch() || typeof u !== 'string' || typeof t !== 'string' ||
      typeof exp !== 'number' || typeof source !== 'string' || u.length === 0 || t.length === 0 || exp <= Date.now()) return
    savedUsername = u; savedAccessToken = t; savedTokenExpiresAt = exp; savedAuthSource = source; valid = true
  })
  return valid && epoch === getCacheEpoch()
}
export function getTokenExpiresAt(): number { return savedTokenExpiresAt }
export function getUsername(): string { return savedUsername }
// Compatibility for existing page signatures; no password is retained or submitted.
export function getPassword(): string { return '' }
export function getAccessToken(): string {
  return savedTokenExpiresAt > Date.now() ? savedAccessToken : ''
}
// True when the stored access token came from the XLLite-style unified gateway
// (login via /api/v1/auth/login, business via /api/v1/run with Bearer token).
export function isGatewayAuth(): boolean {
  return savedAuthSource === GATEWAY_AUTH_SOURCE && savedAccessToken.length > 0
}
export function getAuthSource(): string {
  return savedAuthSource
}
export function getCardToken(): string { return cardExpiresAt > Date.now() ? cardToken : '' }
export function getCardAccountLabel(): string { return cardAccountLabel }
export function getCardCacheNamespace(): string { return cardCacheNamespace }
export function getCardSessionEpoch(): number { return cardSessionEpoch }
export function saveCardToken(token: string, expiresAt: number, epoch: number, label: string = ''): void {
  if (epoch !== getCacheEpoch() || token.length === 0 || !Number.isFinite(expiresAt) || expiresAt <= Date.now()) return
  if (token !== cardToken) cardSessionEpoch++
  cardToken = token; cardExpiresAt = expiresAt; cardAccountLabel = label
}
export function clearCardToken(epoch: number = getCacheEpoch()): void {
  if (epoch !== getCacheEpoch()) return
  cardToken = ''; cardExpiresAt = 0; cardSessionEpoch++; cardAccountLabel = ''
}
export async function saveSchoolSession(username: string, token: string, expiresAt: number,
  epoch: number = getCacheEpoch(), source: string = 'school-native'): Promise<void> {
  if (epoch !== getCacheEpoch()) return
  if (username.length === 0 || token.length === 0 || !Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    throw new Error('学校会话无效，请重新认证')
  }
  try {
    await enqueue(async () => {
      const task = getPrefs()
      if (epoch !== getCacheEpoch()) return
      if (task === null) throw new Error('会话存储尚未准备')
      const prefs = await task
      if (epoch !== getCacheEpoch()) return
      await prefs.delete('password')
      await prefs.put('protocol', SESSION_PROTOCOL)
      await prefs.put('username', username)
      await prefs.put('access_token', token)
      await prefs.put('token_expires_at', expiresAt)
      await prefs.put('auth_source', source)
      await prefs.flush()
    })
    if (epoch === getCacheEpoch()) { savedUsername = username; savedAccessToken = token; savedTokenExpiresAt = expiresAt; savedAuthSource = source }
  } catch (_e) {
    if (epoch === getCacheEpoch()) {
      savedUsername = ''; savedAccessToken = ''; savedTokenExpiresAt = 0; clearCardToken(epoch)
      await enqueue(async () => {
        const task = getPrefs(); if (task === null || epoch !== getCacheEpoch()) return
        const prefs = await task; if (epoch !== getCacheEpoch()) return
        await prefs.clear(); await prefs.flush()
      }).catch((_e: Error) => {})
    }
    throw new Error('登录状态保存失败，请重试')
  }
}
export function clearAccessToken(epoch: number = getCacheEpoch()): Promise<void> {
  if (epoch !== getCacheEpoch()) return Promise.resolve()
  savedAccessToken = ''; savedTokenExpiresAt = 0
  clearCardToken(epoch)
  return enqueue(async () => {
    const task = getPrefs()
    if (task === null || epoch !== getCacheEpoch()) return
    const prefs = await task
    if (epoch !== getCacheEpoch()) return
    await prefs.delete('access_token'); await prefs.delete('token_expires_at'); await prefs.flush()
  })
}
export async function clearSession(): Promise<void> {
  const cacheClearTask = clearAllCachedValues()
  const companionTask = clearCampusCompanion()
  savedUsername = ''; savedAccessToken = ''; savedTokenExpiresAt = 0; cardToken = ''; cardExpiresAt = 0; cardSessionEpoch++
  // School pages use the app's private incognito WebView store.
  try { webview.WebCookieManager.clearAllCookiesSync(true); webview.WebStorage.deleteAllData(true) } catch (_e) {}
  const authClearTask = enqueue(async () => {
    const task = getPrefs()
    if (task === null) return
    const prefs = await task; await prefs.clear(); await prefs.flush()
  })
  await Promise.all([cacheClearTask, authClearTask, companionTask, clearTodos(), clearTodoReminders()])
}
