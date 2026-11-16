"""Add opt-in, off-wire R3-5 tracing; changes no payload, policy or RNG call.

Run in the guest with the FuzzyTrustApp.cc path. Applying twice is an error.
The trace joins cMessage tree IDs across sender/receiver copies.
"""
from pathlib import Path
import difflib
import hashlib
import json
import sys

p = Path(sys.argv[1])
before = p.read_text()
assert 'R3Q5_TRACE' not in before, 'Trace already installed'
text = before


def replace(old, new):
    global text
    assert text.count(old) == 1, (old, text.count(old))
    text = text.replace(old, new)


replace('using namespace veins;', '''#include <cstdlib>
#include <iomanip>

using namespace veins;

namespace {
// Diagnostics only: enabled explicitly for the R3-5 validation runs.
void r3q5Trace(const char* event, const std::string& node, double time,
               long tree, double generated, int index,
               const veins::chapter52::Vec4& pi,
               const veins::chapter52::Vec4& x,
               const veins::chapter52::Vec3& theta,
               const std::vector<double>& omega = {}) {
    const char* path = std::getenv("R3Q5_TRACE");
    if (!path || !*path) return;
    static std::ofstream out(path);
    if (!out) throw cRuntimeError("Cannot write R3Q5 trace");
    static bool header = false;
    if (!header) {
        out << "event,node,time,tree,generated,index,p0,p1,p2,p3,x0,x1,x2,x3,t0,t1,t2,w0,w1,w2,w3,w4\\n";
        out << std::setprecision(17);
        header = true;
    }
    out << event << ',' << node << ',' << time << ',' << tree << ',' << generated << ',' << index;
    for (auto v : pi) out << ',' << v;
    for (auto v : x) out << ',' << v;
    for (auto v : theta) out << ',' << v;
    for (int j = 0; j < 5; ++j) out << ',' << (omega.empty() ? -1.0 : omega[j]);
    out << '\\n';
}
} // namespace
''')
replace('void FuzzyTrustApp::finish() {', '''void FuzzyTrustApp::finish() {
    if (itGameEngine) r3q5Trace("finish", getParentModule()->getFullPath(), simTime().dbl(),
        -1, 0, lastGovernanceIndex, itGameEngine->getPi(), cachedXBarLocal, cachedTheta);''')
replace('                membershipExtractor = std::make_unique<veins::chapter52::MembershipExtractor>();', '''                r3q5Trace("init", getParentModule()->getFullPath(), simTime().dbl(),
                    -1, 0, lastGovernanceIndex, itGameEngine->getPi(), cachedXBarLocal, cachedTheta);
                membershipExtractor = std::make_unique<veins::chapter52::MembershipExtractor>();''')
replace('            rsuGovernance->accumulateEvidence(pi_vehicle);', '''            r3q5Trace("recv_report", getParentModule()->getFullPath(), simTime().dbl(),
                srm->getTreeId(), srm->getTimestamp().dbl(), -1, pi_vehicle, cachedXBarLocal, cachedTheta);
            rsuGovernance->accumulateEvidence(pi_vehicle);''')
replace('            lastGovernanceIndex = incoming_h;', '''            lastGovernanceIndex = incoming_h;
            r3q5Trace("accept_gov", getParentModule()->getFullPath(), simTime().dbl(),
                gwm->getTreeId(), gwm->getTimestamp().dbl(), incoming_h,
                itGameEngine ? itGameEngine->getPi() : veins::chapter52::Vec4{}, cachedXBarLocal, cachedTheta);''')
replace('        rsuGovernance->slowUpdate();', '''        r3q5Trace("gov_before", getParentModule()->getFullPath(), simTime().dbl(),
            -1, 0, static_cast<int>(rsuGovernance->evidenceCount()),
            itGameEngine->getPi(), cachedXBarLocal, cachedTheta, rsuGovernance->getOmega());
        rsuGovernance->slowUpdate();''')
replace('        sendDown(gwm);', '''        r3q5Trace("broadcast", getParentModule()->getFullPath(), simTime().dbl(),
            gwm->getTreeId(), gwm->getTimestamp().dbl(), lastGovernanceIndex,
            itGameEngine->getPi(), cachedXBarLocal, cachedTheta, rsuGovernance->getOmega());
        sendDown(gwm);''')
replace('        veins::chapter52::Vec4 pi_new = itGameEngine->step(mu_nominal, cachedXBarLocal);', '''        r3q5Trace("decision_before", getParentModule()->getFullPath(), simTime().dbl(),
            -1, 0, lastGovernanceIndex, itGameEngine->getPi(), cachedXBarLocal, cachedTheta);
        veins::chapter52::Vec4 pi_new = itGameEngine->step(mu_nominal, cachedXBarLocal);
        r3q5Trace("decision_after", getParentModule()->getFullPath(), simTime().dbl(),
            -1, 0, lastGovernanceIndex, pi_new, cachedXBarLocal, cachedTheta);''')
replace('            sendDown(srm);', '''            r3q5Trace("send_report", getParentModule()->getFullPath(), simTime().dbl(),
                srm->getTreeId(), srm->getTimestamp().dbl(), -1, pi_new, cachedXBarLocal, cachedTheta);
            sendDown(srm);''')
patch = ''.join(difflib.unified_diff(before.splitlines(True),text.splitlines(True),
                                   fromfile='a/FuzzyTrustApp.cc',tofile='b/FuzzyTrustApp.cc'))
out = Path(__file__).resolve().parent
(out/'trace.patch').write_text(patch)
(out/'source_hashes.json').write_text(json.dumps(dict(
    original_sha256=hashlib.sha256(before.encode()).hexdigest(),
    instrumented_sha256=hashlib.sha256(text.encode()).hexdigest()),indent=2)+'\n')
p.write_text(text)
print('Added opt-in trace; original core algorithm files unchanged.')
