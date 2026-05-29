

//package org.car2x.veins.examples.FuzzyVeins;

import org.car2x.veins.nodes.RSU;
import org.car2x.veins.nodes.Scenario;
import org.car2x.veins.modules.application.fuzzytrust.FuzzyTrustApp;

network FuzzyTrustScenario extends Scenario
{
    parameters:
        int Nv = default(0);
        int numNodes = default(Nv);
    submodules:
        rsu[10]: RSU {
            parameters:
                *.nic.typename = "Nic80211p";
                *.nic.mac.typename = "Mac80211p";
                *.mobility.typename = "TraCIMobility";
                *.app[0].typename = "FuzzyTrustApp";
                *.app[0].configFile = default("config.json");
                *.app[0].decisionInterval = default(0.1s);
                *.app[0].isRSU = default(true);
                *.app[0].taskUrgency = default(0.2);
                *.app[0].taskReliability = default(0.9);
                *.app[0].taskElasticity = default(0.8);
            @display("p=150,140;i=veins/sign/yellowdiamond;is=vs");
        }
        // 添加车辆节点配置（通过TraCI动态创建）
}
