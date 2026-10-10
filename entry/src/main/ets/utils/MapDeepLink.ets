import common from '@ohos.app.ability.common'
import { UIContext } from '@ohos.arkui.UIContext'
import { BusinessError } from '@kit.BasicServicesKit'
import { safeToast } from './ToastHelper'

/**
 * 跳转到地图导航(高德/百度) - 步 9 完整实现
 *
 * 顺序:
 *   1. 高德(androidamap://navi?...) - 大多数 Android 设备自带高德
 *   2. 百度(baidumap://map/direction?...) - 鸿蒙兼容
 *   3. 都失败时弹 Toast 提示
 */
export function navToMap(location: string, uiContext: UIContext): void {
  const host = uiContext.getHostContext()
  const ctx: common.UIAbilityContext | undefined = host as common.UIAbilityContext
  if (!ctx) {
    safeToast(uiContext, '上下文未就绪')
    return
  }

  const encoded: string = encodeURIComponent(location)
  const amapUri: string = `androidamap://navi?sourceApplication=xjit&keyword=${encoded}&dev=0&style=2`
  const baiduUri: string = `baidumap://map/direction?destination=${encoded}&mode=walking&src=xjit&coord_type=bd09ll`

  // 试高德
  ctx.startAbility({ uri: amapUri }, (err: BusinessError) => {
    if (!err || (err.code === undefined || err.code === 0)) {
      return
    }
    // 试百度
    ctx.startAbility({ uri: baiduUri }, (err2: BusinessError) => {
      if (!err2 || (err2.code === undefined || err2.code === 0)) {
        return
      }
      // 都失败
      safeToast(uiContext, '请先安装高德/百度地图')
    })
  })
}
