import { UIContext } from '@ohos.arkui.UIContext'
import router from '@ohos.router'
import { BusinessError } from '@kit.BasicServicesKit'

export function safePush(uiContext: UIContext, options: router.RouterOptions): void {
  try {
    uiContext.getRouter().pushUrl(options).catch((_e: BusinessError) => {})
  } catch (_e) {
  }
}

export function safeReplace(uiContext: UIContext, options: router.RouterOptions): void {
  try {
    uiContext.getRouter().replaceUrl(options).catch((_e: BusinessError) => {})
  } catch (_e) {
  }
}

export function safeBack(uiContext: UIContext): void {
  try {
    uiContext.getRouter().back()
  } catch (_e) {
  }
}

export function safeClear(uiContext: UIContext): void {
  try {
    uiContext.getRouter().clear()
  } catch (_e) {
  }
}
