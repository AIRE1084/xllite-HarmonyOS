import uiMaterial from '@ohos.arkui.uiMaterial'
import deviceInfo from '@ohos.deviceInfo'

const materials: Map<string, uiMaterial.ImmersiveMaterial> = new Map<string, uiMaterial.ImmersiveMaterial>()

export function supportsImmersiveMaterial(): boolean {
  try {
    const rawApi: number = deviceInfo.sdkApiVersion
    const api: number = rawApi >= 100000000 ? rawApi % 1000 : rawApi
    if (api < 26) return false
    return uiMaterial.isImmersiveMaterialSupported() && uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE
  } catch (_e) { return false }
}

export function glassMaterial(isDark: boolean, interactive: boolean = false,
  prominent: boolean = false): uiMaterial.ImmersiveMaterial {
  const key = String(isDark) + String(interactive) + String(prominent)
  const cached = materials.get(key)
  if (cached !== undefined) return cached
  const material = new uiMaterial.ImmersiveMaterial({
    style: prominent ? uiMaterial.ImmersiveStyle.REGULAR : uiMaterial.ImmersiveStyle.THIN,
    materialColor: isDark ? '#18203450' : '#18FFFFFF',
    applyShadow: false,
    interactive: interactive,
    lightEffect: interactive ? { color: isDark ? '#A9C4FF' : '#FFFFFF' } : null,
  })
  materials.set(key, material)
  return material
}

