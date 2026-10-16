import { getCacheEpoch } from './MemoryCache'

/**
 * 会话级 UI 状态缓存：只存内存、不落盘，登出（缓存代次变化）自动整体清空。
 * 用途：跨页面往返/重启保留周次选择、分页位置等界面状态；业务数据仍由 ApiService 缓存负责。
 * cardEpoch 用于一卡通会话隔离：卡片切换/失效后保存的状态一律丢弃。
 */
interface UiSnapshot {
  epoch: number
  cardEpoch: number
  state: Record<string, Object>
}

const store: Map<string, UiSnapshot> = new Map<string, UiSnapshot>()
const MAX_PAGES: number = 20

export function saveUiState(page: string, cardEpoch: number, state: Record<string, Object>): void {
  store.delete(page)
  store.set(page, { epoch: getCacheEpoch(), cardEpoch: cardEpoch, state: state })
  if (store.size > MAX_PAGES) {
    const oldest: string | undefined = store.keys().next().value
    if (oldest !== undefined) store.delete(oldest)
  }
}

export function loadUiState(page: string, cardEpoch: number): Record<string, Object> | null {
  const snapshot: UiSnapshot | undefined = store.get(page)
  if (snapshot === undefined) return null
  if (snapshot.epoch !== getCacheEpoch() || snapshot.cardEpoch !== cardEpoch) {
    store.delete(page)
    return null
  }
  return snapshot.state
}

export function clearUiState(page: string): void {
  store.delete(page)
}
