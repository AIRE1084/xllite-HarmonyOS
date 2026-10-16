import type uiMaterial from '@ohos.arkui.uiMaterial'
import deviceInfo from '@ohos.deviceInfo'

let checkSupport: (() => boolean) | null = null
let createMaterial: ((isDark: boolean, interactive: boolean, prominent: boolean) => uiMaterial.ImmersiveMaterial) | null = null
let loading: Promise<boolean> | null = null

export function supportsImmersiveMaterial(): boolean {
  try { return checkSupport !== null && checkSupport() } catch (_error) { return false }
}
export function loadImmersiveMaterial(): Promise<boolean> {
  const rawApi = deviceInfo.sdkApiVersion
  const api = rawApi >= 100000000 ? rawApi % 1000 : rawApi
  if (api < 26) return Promise.resolve(false)
  if (checkSupport !== null) return Promise.resolve(supportsImmersiveMaterial())
  if (loading !== null) return loading
  loading = import('./NativeMaterials').then((adapter) => {
    checkSupport = adapter.supportsNativeMaterial
    createMaterial = adapter.createNativeMaterial
    return supportsImmersiveMaterial()
  }).catch((): boolean => false).finally(() => { loading = null })
  return loading
}
export function glassMaterial(isDark: boolean, interactive: boolean = false,
  prominent: boolean = false): uiMaterial.ImmersiveMaterial {
  if (createMaterial === null) throw new Error('Native material not loaded')
  return createMaterial(isDark, interactive, prominent)
}
