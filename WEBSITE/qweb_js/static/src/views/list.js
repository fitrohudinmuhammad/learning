/** @odoo-module **/

import { registry } from "@web/core/registry";
import { useService } from '@web/core/utils/hooks';
import { ExpenseListController } from "@hr_expense/views/list";

export class QwebJSListController extends ExpenseListController {
    setup() {
        super.setup();
        this.orm = useService('orm');
        this.actionService = useService('action');
    }

    async onNewButtonClick() {
        console.log('CLICK BUTTON');
        const records = this.model.root.selection;
        const recordIds = records.map((a) => a.resId);
        console.log(recordIds)
        const action = await this.orm.call('hr.expense', 'button_click_qweb', [recordIds]);
        this.actionService.doAction(action);
    }
}

const expenseView = registry.category("views").get("hr_expense_dashboard_tree");
console.log(expenseView)
expenseView.buttonTemplate = 'qweb_js.ListButtons'
expenseView.Controller = QwebJSListController