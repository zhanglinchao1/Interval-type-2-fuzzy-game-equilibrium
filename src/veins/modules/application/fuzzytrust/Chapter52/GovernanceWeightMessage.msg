//
// GovernanceWeightMessage.msg
// RSU broadcasts governance weights theta and population mean x_bar to vehicles.
// See plan.MD section 2.3 / 9.2.
//

import veins.modules.messages.BaseFrame1609_4;

namespace veins;

packet GovernanceWeightMessage extends BaseFrame1609_4 {
    double theta[3];
    double xBarLocal[4];
    int omegaIndex;
}
