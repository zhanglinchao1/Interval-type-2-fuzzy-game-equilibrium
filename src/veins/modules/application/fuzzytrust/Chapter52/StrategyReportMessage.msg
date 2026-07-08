//
// StrategyReportMessage.msg
// Vehicle -> RSU uplink: each vehicle reports its current mixed strategy pi
// every decision period, so the RSU governance aggregator computes x_bar from
// the true vehicle population instead of its own pi proxy (plan MC4 closure).
//

import veins.modules.messages.BaseFrame1609_4;

namespace veins;

packet StrategyReportMessage extends BaseFrame1609_4 {
    double pi[4];
}
