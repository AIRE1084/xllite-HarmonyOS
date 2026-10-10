import { FormExtensionAbility, formProvider, formInfo } from '@kit.FormKit'
import Want from '@ohos.app.ability.Want'
import { buildWidgetBinding } from '../services/WidgetService'

export default class CampusFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    return buildWidgetBinding(this.context)
  }
  onUpdateForm(formId: string): void {
    formProvider.updateForm(formId, buildWidgetBinding(this.context)).catch((_e: Error) => {})
  }
  onChangeFormVisibility(status: Record<string, number>): void {
    Object.keys(status).forEach((formId: string) => {
      if (status[formId] === formInfo.VisibilityType.FORM_VISIBLE) this.onUpdateForm(formId)
    })
  }
  onFormEvent(formId: string, _message: string): void { this.onUpdateForm(formId) }
}
