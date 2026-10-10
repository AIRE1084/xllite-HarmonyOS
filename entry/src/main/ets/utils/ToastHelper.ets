import { UIContext } from '@ohos.arkui.UIContext'

export function safeToast(uiContext: UIContext, message: string): void {
  if (message.length === 0) return
  try {
    uiContext.getPromptAction().showToast({ message })
  } catch (_e) {
  }
}
