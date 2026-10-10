/**
 * Push Kit 空壳(Q1=B 预留)
 *
 * 后端 Push Kit 接入后,在此实现:
 *   1. 通过 notificationManager.requestEnableNotification 开启普通通知
 *   2. pushService.getToken() → 上报到后端
 *   3. on('pushMessage', ...) 接收推送
 *
 * 当前:开发期用本地通知(NotificationHelper.ets)模拟 UI
 */

let pushToken: string = ''

export function setPushToken(token: string): void {
  pushToken = token
}

export function getPushToken(): string {
  return pushToken
}

export async function initPushService(): Promise<void> {
  // TODO: 接入鸿蒙 Push Kit
  console.info('PushService: 空壳模式,等待后端接入')
}
