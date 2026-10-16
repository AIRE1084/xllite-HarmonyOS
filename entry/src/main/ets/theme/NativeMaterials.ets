import uiMaterial from '@ohos.arkui.uiMaterial'
import hilog from '@ohos.hilog'

const materials: Map<string, uiMaterial.ImmersiveMaterial> = new Map<string, uiMaterial.ImmersiveMaterial>()
export function supportsNativeMaterial(): boolean {
  return uiMaterial.isImmersiveMaterialSupported() && uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE
}
export function createNativeMaterial(isDark: boolean, interactive: boolean, prominent: boolean): uiMaterial.ImmersiveMaterial {
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
  hilog.info(0x0000, 'XJITMaterial', 'Native material created')
  return material
}
