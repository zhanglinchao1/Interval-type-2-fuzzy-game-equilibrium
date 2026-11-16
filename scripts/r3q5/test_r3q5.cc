// Compile against the original FuzzyVeins Chapter52 source files (C++17).
#include "veins/modules/application/fuzzytrust/Chapter52/ITGameEngine.h"
#include "veins/modules/application/fuzzytrust/Chapter52/RSUGovernanceAggregator.h"
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <random>
#include <string>
#include <vector>
#include <cmath>
#include <stdexcept>
using namespace veins::chapter52;

const MatPpay P{{.6,.3,.1},{.5,.4,.1},{.4,.35,.25},{.3,.5,.2},{.2,.3,.5}};
const Mat44 Mt{{{.9,.7,.3,.1},{.8,.6,.25,.1},{.5,.4,.2,.1},{.3,.2,.15,.05}}};
const Mat44 Md{{{.85,.75,.5,.3},{.8,.7,.45,.25},{.6,.5,.35,.2},{.4,.3,.2,.1}}};
const Mat44 Mr{{{.7,.8,.6,.4},{.65,.85,.55,.35},{.75,.7,.5,.3},{.5,.6,.4,.2}}};
template<class A, class B> double dist(const A& a,const B& b) {
    double s=0; for (size_t i=0;i<a.size();++i) s+=std::abs(a[i]-b[i]); return s;
}
template<class A> void emit(std::ostream& out,const A& a) { for(auto v:a) out << ',' << v; }
Vec4 simplex(std::mt19937& rng) {
    Vec4 a; double s=0;
    for(auto& v:a) {v=1+static_cast<double>(rng()%1000);s+=v;}
    for(auto& v:a) v/=s;
    return a;
}
void consistency(const std::string& dir) {
    std::ifstream in(dir+"/inputs.txt"); if(!in)throw std::runtime_error("Missing inputs");
    std::ofstream out(dir+"/cpp_consistency.csv");out<<std::setprecision(17);
    out<<"id,role,c0,c1,c2,c3,r0,r1,r2,r3,n0,n1,n2,n3,p0,p1,p2,p3,w0,w1,w2,w3,w4\n";
    int id,role,count=0;
    while(in>>id>>role) {
        Vec4 x,pi;std::vector<double>w(5);
        for(auto& v:x) in>>v;
        for(auto& v:pi) in>>v;
        for(auto& v:w) in>>v;
        auto theta=RSUGovernanceAggregator::projectTheta(w,P);
        ITGameEngine e;e.setParams(.15,.3,.2,.5,theta);
        if(role) e.setFeasibleMask({true,true,false,false});
        e.setInitialPi(pi);
        Vec4 centers,radii;
        for(int j=0;j<4;++j) {
            Vec4 pure{};pure[j]=1;Vec3 lo,up;
            auto mu=ITGameEngine::computeNominalMembership(pure,x,Mt,Md,Mr);
            ITGameEngine::computeIT2Bounds(mu,.2,lo,up);
            ITGameEngine::crystallizedPayoff(lo,up,theta,centers[j],radii[j]);
        }
        auto nu=e.alphaRobustNu(x,.2,theta,.5);auto after=e.step({0,0,0},x);
        RSUGovernanceAggregator::Config cfg;cfg.epsilon_g=.002;cfg.dt=2;cfg.omega_init=w;
        RSUGovernanceAggregator gov(cfg);gov.accumulateEvidence(x);gov.slowUpdate();
        out<<id<<','<<role;emit(out,centers);emit(out,radii);emit(out,nu);emit(out,after);
        emit(out,gov.getOmega());out<<'\n';++count;
    }
    if(!in.eof()||count==0)throw std::runtime_error("Malformed inputs");
    std::cout<<"Consistency cases: "<<count<<'\n';
}
void closed_loop(const std::string& dir) {
    RSUGovernanceAggregator::Config base;base.epsilon_g=.002;base.dt=2;
    RSUGovernanceAggregator refg(base);ITGameEngine refe;
    Vec4 refx{.25,.25,.25,.25};
    for(int n=0;n<30000;++n) {
        refe.setParams(.15,.3,.2,.5,refg.getTheta());
        auto xp=refe.step({0,0,0},refx);auto wp=refg.getOmega();
        refg.accumulateEvidence(xp);refg.slowUpdate();
        double r=std::max(dist(xp,refx),dist(wp,refg.getOmega()));refx=xp;
        if(r<1e-15)break;
        if(n==29999)throw std::runtime_error("Reference did not settle");
    }
    auto refw=refg.getOmega();
    std::ofstream reference(dir+"/reference.csv");reference<<std::setprecision(17)<<"p0,p1,p2,p3,w0,w1,w2,w3,w4\n"<<refx[0];
    for(int j=1;j<4;++j) reference<<','<<refx[j];
    emit(reference,refw); reference<<'\n';
    std::ofstream out(dir+"/cpp_closed_loop.csv");out<<std::setprecision(17)<<"case,seed,steps,max_pi_error,max_w_error,outage_end_error,recovery_steps\n";
    std::ofstream trace(dir+"/cpp_closed_loop_trace.csv");trace<<std::setprecision(17)<<"case,step,pi_error,w_error\n";
    for(int mode=0;mode<3;++mode)for(int seed=0;seed<20;++seed) {
        std::mt19937 rng(500+seed);std::vector<ITGameEngine> engines(20);
        std::vector<RSUGovernanceAggregator> govs;
        for(int r=0;r<4;++r){
            auto cfg=base; cfg.omega_init=std::vector<double>(5,.15);
            cfg.omega_init[(seed+r)%5]=.2;
            cfg.omega_init[(seed+r+1)%5]=.25;
            cfg.omega_init[(seed+r+2)%5]=.25;
            govs.emplace_back(cfg);
        }
        std::vector<Vec4> pi(20);
        for(int i=0;i<20;++i){
            pi[i]=simplex(rng);
            if(seed<4){pi[i]={0,0,0,0};pi[i][(seed+i)%4]=1;}
            for(auto& v:pi[i])v*=.75;
            pi[i][0]+=.25;
            if(seed==4)pi[i]={.25,.25,.25,.25};
            engines[i].setInitialPi(pi[i]);
        }
        std::vector<std::vector<Vec4>> history(12,pi);
        std::vector<std::vector<std::vector<double>>> whist(8);
        for(auto& wh:whist)for(auto& g:govs)wh.push_back(g.getOmega());
        double ep=2,ew=2,outage=0;int n=0,recovery=-1;
        for(n=1;n<=20000;++n) {
            bool blackout=mode==2 && n>=1000 && n<1100;
            for(int r=0;r<4;++r) {
                if(!blackout)for(int k=0;k<(mode==0?20:3);++k) {
                    int j=mode==0?k:(5*r+k+(mode==2?n/7:0))%20;
                    int delay=mode==2?(j+n)%11:0;
                    govs[r].accumulateEvidence(history[(n-1-delay+120)%12][j]);
                }
                govs[r].slowUpdate();
            }
            for(int i=0;i<20;++i)if(mode<2 || (n+i)%3==0) {
                int r=(i/5+(mode==2?n/9:0))%4;
                int lag=mode==2?(i+n)%7:0;
                auto w=whist[(n-1-lag+80)%8][r];
                engines[i].setParams(.15,.3,.2,.5,RSUGovernanceAggregator::projectTheta(w,P));
                pi[i]=engines[i].step({0,0,0},govs[r].getXBarLocal());
            }
            history[n%12]=pi;for(int r=0;r<4;++r)whist[n%8][r]=govs[r].getOmega();
            ep=0;ew=0;for(auto& p:pi)ep=std::max(ep,dist(p,refx));
            for(auto& g:govs)ew=std::max(ew,dist(g.getOmega(),refw));
            if(n==1099)outage=std::max(ep,ew);
            if(n>=1100 && recovery<0 && std::max(ep,ew)<1e-8)recovery=n-1100;
            if(seed==0 && n%10==0)trace<<mode<<','<<n<<','<<ep<<','<<ew<<'\n';
            if(n>1100 && std::max(ep,ew)<1e-10)break;
        }
        if(ep>1e-8||ew>1e-8)throw std::runtime_error("Closed-loop did not settle");
        out<<mode<<','<<seed<<','<<n<<','<<ep<<','<<ew<<','<<outage<<','<<recovery<<'\n';
    }
    std::cout<<"Closed loop: 60/60 runs meet 1e-8\n";
}
int main(int argc,char** argv) {
    if(argc!=2)return 2;
    try{consistency(argv[1]);closed_loop(argv[1]);}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
