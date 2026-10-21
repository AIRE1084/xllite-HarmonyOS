import { FormExtensionAbility, formProvider, formInfo } from '@kit.FormKit'
import Want from '@ohos.app.ability.Want'
import { buildFormBinding } from '../services/WidgetService'

export default class CampusFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    const name = String(want.parameters?.[formInfo.FormParam.NAME_KEY] ?? 'CampusScheduleCard')
    return buildFormBinding(this.context, name)
  }
  onUpdateForm(formId: string): void {
    this.updateBinding(formId).catch((_e: Error) => {})
  }
  private async updateBinding(formId: string): Promise<void> {
    const forms = await formProvider.getPublishedRunningFormInfos()
    for (const form of forms) {
      if (form.formId === formId) {
        await formProvider.updateForm(formId, buildFormBinding(this.context, form.formName))
        return
      }
    }
  }
  onChangeFormVisibility(status: Record<string, number>): void {
    Object.keys(status).forEach((formId: string) => {
      if (status[formId] === formInfo.VisibilityType.FORM_VISIBLE) this.onUpdateForm(formId)
    })
  }
  onFormEvent(formId: string, _message: string): void { this.onUpdateForm(formId) }
}
