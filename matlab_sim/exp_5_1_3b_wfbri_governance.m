function exp_5_1_3b_wfbri_governance(mode)
%EXP_5_1_3B_WFBRI_GOVERNANCE R3-4: the actual discrete solver/governance loop.
% prepare: export canonical configurations and check warm starts.
% run (default): 20 starts, three effective governance steps, matched slow
% time and long-run checks. Certificate generation can run independently;
% verify_r3_closed_loop.py must finish before rendering the combined report.
% render: rebuild figure and summary from the saved raw trajectories.
if nargin < 1; mode = 'run'; end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'utils'));
td = fullfile(root,'table'); id = fullfile(root,'image');
if ~exist(td,'dir'); mkdir(td); end
if ~exist(id,'dir'); mkdir(id); end
if strcmp(mode,'render')
    render_results(td,id); return;
end
cases = configurations(root);
if strcmp(mode,'prepare')
    warm_checks = check_warm_starts(cases);
    save(fullfile(td,'table5_3b_r3_closed_loop_inputs.mat'),'cases','warm_checks');
    fprintf('R3-4 inputs and warm-start checks saved.\n'); return;
end
assert(strcmp(mode,'run'),'Unknown experiment mode.');
stored = load(fullfile(td,'table5_3b_r3_closed_loop_inputs.mat'),'cases');
assert(isequaln(cases,stored.cases),'Configuration changed after certification.');
steps = [1e-4,1e-3,1e-2]; seeds = 42:61;
raw_rows = cell(0,18); long_rows = cell(0,13); matched_rows = cell(0,9);
traces = cell(2,3); long_traces = cell(2,1); references = cell(2,1);
for ci = 1:numel(cases)
    cfg = cases{ci}; p = cfg.p;
    [pr,wr,ref_res] = joint_reference(cfg);
    references{ci} = struct('pi',pr,'omega',wr,'residual',ref_res);
    p1 = p; p1.R_max = 1;
    for si = 1:numel(seeds)
        [z0,w0] = initial_state(si,seeds(si),p.N);
        for hi = 1:numel(steps)
            h = steps(hi); z = z0; w = w0; T = round(1/h);
            checkpoints = unique([0,round(logspace(0,log10(T),65)),round(.5/h),T]);
            rec = zeros(0,8); max_mass = 0; min_prob = 1;
            for n = 0:T
                if any(n==checkpoints)
                    [er,fr,gr,rs] = diagnostics(z,w,cfg);
                    rec(end+1,:) = [n,n*h,er,fr,gr,rs,mean(z(:,1)),w(4)]; %#ok<AGROW>
                    if n==round(.5/h) || n==T
                        raw_rows(end+1,:) = {cfg.name,seeds(si),si,h,n*h,er,fr,gr,rs, ...
                            mean(sum(abs(z-pr),2)),norm(w-wr,1),max_mass,min_prob, ...
                            mean(z(:,1)),mean(z(:,2)),mean(z(:,3)),mean(z(:,4)),w(4)}; %#ok<AGROW>
                    end
                end
                if n==T; break; end
                z = sec4_3_1_wfbri_solve(p1,cfg.delta,p.P_pay*w,.5,cfg.focus,z);
                w = (1-h)*w+h*governance(mean(z,1)',w,p);
                max_mass = max(max_mass,max([abs(sum(z,2)-1);abs(sum(w)-1)]));
                min_prob = min(min_prob,min([z(:);w]));
            end
            if si==1; traces{ci,hi} = rec; end
        end
        % Long-run test uses the largest tested step. It stops only when both
        % actual update residuals pass, and is compared with an independent root.
        z = z0; w = w0; h = .01; rec = zeros(0,6); fr = Inf; gr = Inf;
        for n = 0:3000
            if mod(n,10)==0
                [fr,gr] = residuals(z,w,cfg);
                pe = mean(sum(abs(z-pr),2)); we = norm(w-wr,1);
                rec(end+1,:) = [n,n*h,fr,gr,pe,we]; %#ok<AGROW>
                if max(fr,gr)<1e-8; break; end
            end
            z = sec4_3_1_wfbri_solve(p1,cfg.delta,p.P_pay*w,.5,cfg.focus,z);
            w = (1-h)*w+h*governance(mean(z,1)',w,p);
        end
        assert(max(fr,gr)<1e-8,'Long-run joint residual failed.');
        assert(pe+we<2e-8,'Different joint limit across initial states.');
        long_rows(end+1,:) = {cfg.name,seeds(si),si,h,n,n*h,fr,gr,pe,we, ...
            max(abs(sum(z,2)-1)),min(z(:)),ref_res}; %#ok<AGROW>
        if si==1; long_traces{ci} = rec; end
        fprintf('R3-4 %s start %02d/20: residual %.3g, joint error %.3g\n', ...
            cfg.name,si,max(fr,gr),pe+we);
    end
    % Matched payoff: compare logit and replicator rest points at the SAME w.
    w = wr; xs = mean(pr,1)'; ns = population_nu(xs,w,cfg);
    rep_at_logit = norm(xs.*(ns-xs'*ns),Inf);
    for si = 1:20
        rng(seeds(si)); x = .05+rand(4,1); x = x/sum(x);
        for it = 1:200000
            nu = population_nu(x,w,cfg); dx = x.*(nu-x'*nu);
            if norm(dx,Inf)<1e-11; break; end
            xn = x+.1*dx;
            assert(all(xn>=0),'Replicator Euler step left simplex.');
            x = xn/sum(xn);
        end
        assert(norm(dx,Inf)<1e-11,'Matched replicator did not settle.');
        exploit = max(nu)-x'*nu;
        assert(exploit<1e-8,'Replicator rest point is not a Nash point.');
        % This equality checks the canonical mean-field payoff independently
        % of the finite-N strategy distribution used in the coupled run.
        payoff_error = norm(population_nu(x,w,cfg)-profile_nu(repmat(x',p.N,1),w,cfg,1)',Inf);
        matched_rows(end+1,:) = {cfg.name,seeds(si),norm(x-xs,1),rep_at_logit, ...
            norm(dx,Inf),exploit,payoff_error,x(2),it}; %#ok<AGROW>
    end
end
raw = cell2table(raw_rows,'VariableNames',{'Case','Seed','Start','Step','SlowTime', ...
    'TrackingError','FixedPointResidual','GovernanceResidual','ReferenceResidual', ...
    'StrategyJointError','GovernanceJointError','MaxSimplexError','MinProbability', ...
    'SC','SP','DC','DP','Omega4'});
longrun = cell2table(long_rows,'VariableNames',{'Case','Seed','Start','Step','Rounds', ...
    'SlowTime','FixedPointResidual','GovernanceResidual','StrategyJointError', ...
    'GovernanceJointError','SimplexError','MinProbability','JointReferenceResidual'});
matched = cell2table(matched_rows,'VariableNames',{'Case','Seed','EquilibriumL1Gap', ...
    'ReplicatorResidualAtLogit','ReplicatorResidual','UnregularizedExploitability', ...
    'CanonicalPayoffError','ReplicatorSP','ReplicatorRounds'});
writetable(raw,fullfile(td,'table5_3b_r3_tracking_raw.csv'));
writetable(longrun,fullfile(td,'table5_3c_r3_joint_raw.csv'));
writetable(matched,fullfile(td,'table5_3d_r3_matched_payoff.csv'));
save(fullfile(td,'table5_3b_r3_closed_loop.mat'),'raw','longrun','matched', ...
    'traces','long_traces','references','cases','steps','seeds');
assert(all(raw.MaxSimplexError<1e-12) && all(raw.MinProbability>=0));
assert(max(matched.CanonicalPayoffError)<1e-12);
if exist(fullfile(td,'table5_3b_r3_closed_loop_certificate.json'),'file')
    render_results(td,id);
end
fprintf('R3-4: 120 tracking runs, 40 long runs and 40 matched-payoff checks PASS.\n');
end

function cases = configurations(root)
p = config_params(); p.N = 50; p.R_max = 2000; p.eps_tol = 1e-12;
p.governance_noise_std = 0;
% Read the four numeric assignments from the existing Simulation III rather
% than maintain another copy of its kernels. str2num sees numeric literals only.
txt = fileread(fullfile(root,'exp_5_1_3_dual_timescale.m'));
p3 = p; keys = {'trust_matrix','delay_matrix','res_matrix','P_pay'};
for j = 1:numel(keys)
    tok = regexp(txt,['params\.',keys{j},'\s*=\s*\[([\s\S]*?)\];'],'tokens');
    assert(isscalar(tok) && isempty(regexp(tok{1}{1},'[^0-9.,;\s]','once')));
    p3.(keys{j}) = str2num(tok{1}{1}); %#ok<ST2NM>
end
env = scenario_b_config('concentrated'); pb = scenario_b_env(p,env.fou_scale);
pb.lambda = .002;
cases = {struct('name','SimulationIII','p',p3,'delta',.1,'focus',0), ...
    struct('name','ScenarioB','p',pb,'delta',env.delta,'focus',40)};
end

function report = check_warm_starts(cases)
report = zeros(numel(cases),4);
for ci = 1:numel(cases)
    cfg = cases{ci}; p = cfg.p; p.eps_tol = 0; p.R_max = 17;
    rng(441); z = rand(p.N,4); z = z./sum(z,2); theta = p.theta;
    [whole,hw] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,z);
    p.R_max = 6;
    [part,h1] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,z);
    p.R_max = 11;
    [part,h2] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,part);
    assert(isequal(whole,part) && isequal(hw.residual,[h1.residual;h2.residual]));
    p.R_max = 1; rng_before = rng;
    one = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,z);
    rng_after = rng; [two,~] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,z);
    assert(isequal(one,two) && isequal(rng_before,rng_after));
    p.R_max = 2000; p.eps_tol = 1e-12;
    [legacy,hl] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus);
    [empty,he] = sec4_3_1_wfbri_solve(p,cfg.delta,theta,.5,cfg.focus,[]);
    assert(isequal(legacy,empty) && isequal(hl,he));
    report(ci,:) = [max(abs(whole-part),[],'all'),max(abs(one-two),[],'all'), ...
        max(abs(legacy-empty),[],'all'),hl.fixed_point_residual];
end
end

function [z,w] = initial_state(idx,seed,N)
rng(seed);
if idx==1
    z = repmat([.30,.25,.25,.20],N,1)+.02*rand(N,4);
    w = [.15;.15;.15;.35;.20];
elseif idx<=5
    z = zeros(N,4); z(:,idx-1) = 1; w = zeros(5,1); w(idx-1) = 1;
elseif idx==6
    z = zeros(N,4); z(sub2ind([N,4],(1:N)',1+mod((1:N)'-1,4))) = 1;
    w = [0;0;0;0;1];
else
    z = -log(rand(N,4)); w = -log(rand(5,1)); w = w/sum(w);
end
z = z./sum(z,2);
end

function target = governance(x,w,p)
target = sec3_2_bounded_sigma(sec4_4_3_governance_performance(x,w,p.P_pay,p));
end

function [z,w,res] = joint_reference(cfg)
% Independent reduced solve: fully solve the fast game at each undamped
% governance update, instead of using the tested one-step coupled trajectory.
p = cfg.p; p.eps_tol = 1e-14; w = ones(5,1)/5;
for it = 1:100
    [z,hh] = sec4_3_1_wfbri_solve(p,cfg.delta,p.P_pay*w,.5,cfg.focus);
    assert(hh.converged);
    wn = governance(mean(z,1)',w,p);
    if norm(wn-w,1)<1e-13; break; end
    w = wn;
end
[a,b] = residuals(z,w,cfg); res = max(a,b);
assert(res<1e-11,'Joint reference failed its independent residual check.');
end

function [e,fr,gr,rr] = diagnostics(z,w,cfg)
p = cfg.p; p.eps_tol = 1e-14;
[ref,hr] = sec4_3_1_wfbri_solve(p,cfg.delta,p.P_pay*w,.5,cfg.focus);
assert(hr.converged); rr = hr.fixed_point_residual;
e = mean(sum(abs(z-ref),2)); [fr,gr] = residuals(z,w,cfg);
end

function [fr,gr] = residuals(z,w,cfg)
p = cfg.p; p.R_max = 1;
zp = sec4_3_1_wfbri_solve(p,cfg.delta,p.P_pay*w,.5,cfg.focus,z);
fr = mean(sum(abs(zp-z),2));
gr = norm(governance(mean(zp,1)',w,p)-w,1);
end

function nu = profile_nu(z,w,cfg,row)
[~,~,ch,rr] = sec4_1_2_pure_interval_payoff_matrix(z,cfg.delta,cfg.p.P_pay*w,cfg.p);
v = ch-.5*rr.*(rr./max(max(rr,[],2),.01)).^cfg.focus;
nu = v(row,:);
end

function nu = population_nu(x,w,cfg)
% Two identical agents have leave-one-out mean x; this gives the exact
% homogeneous population payoff for the SAME Gamma_{alpha,s}.
nu = profile_nu(repmat(x',2,1),w,cfg,1)';
end

function render_results(td,id)
d = load(fullfile(td,'table5_3b_r3_closed_loop.mat'));
cc = jsondecode(fileread(fullfile(td,'table5_3b_r3_closed_loop_certificate.json')));
assert(strcmp(cc.status,'PASS'));
cross_checks = check_certificate_against_solver(d.cases,cc);
writetable(cross_checks,fullfile(td,'table5_3e_r3_certificate_crosscheck.csv'));
rows = cell(2,14);
for ci = 1:2
    name = d.cases{ci}.name; r = d.raw(strcmp(d.raw.Case,name)&d.raw.SlowTime==1,:);
    l = d.longrun(strcmp(d.longrun.Case,name),:); m = d.matched(strcmp(d.matched.Case,name),:);
    med = arrayfun(@(h) median(r.TrackingError(r.Step==h)),d.steps);
    fit = polyfit(log10(d.steps),log10(med),1); c = cc.cases(ci);
    rows(ci,:) = {name,str2double(c.kappa),str2double(c.B),str2double(c.c), ...
        str2double(c.d),str2double(c.feedback),med(1),med(2),med(3),fit(1), ...
        max(l.FixedPointResidual),max(l.GovernanceResidual), ...
        max(l.StrategyJointError+l.GovernanceJointError),max(m.EquilibriumL1Gap)};
end
summary = cell2table(rows,'VariableNames',{'Case','Kappa','B','c','d','Feedback', ...
    'MedianTracking_h1e4','MedianTracking_h1e3','MedianTracking_h1e2','TrackingSlope', ...
    'MaxFastResidual','MaxGovernanceResidual','MaxJointError','EquilibriumL1Gap'});
writetable(summary,fullfile(td,'table5_3b_r3_closed_loop_summary.csv')); disp(summary);
f = figure('Visible','off','Position',[80,80,1150,680],'Color','w');
set(f,'DefaultAxesFontName','Times New Roman','DefaultTextFontName','Times New Roman', ...
    'DefaultAxesFontSize',13.5,'DefaultLegendFontSize',12);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact'); colors = lines(3);
for ci = 1:2
    nexttile; hold on;
    for hi = 1:3
        tr = d.traces{ci,hi};
        keep = tr(:,2)>0;
        loglog(tr(keep,2),max(tr(keep,3),1e-14), ...
            'Color',colors(hi,:),'LineWidth',1.2);
    end
    set(gca,'XScale','log','YScale','log'); grid on;
    display_name = strrep(strrep(d.cases{ci}.name,'SimulationIII','Simulation III'), ...
        'ScenarioB','Scenario B');
    xlabel('Slow time h n'); ylabel('Tracking error'); title(display_name);
    legend('h = 10^{-4}','h = 10^{-3}','h = 10^{-2}','Location','southoutside','NumColumns',3);
    nexttile; tr = d.long_traces{ci};
    semilogy(tr(:,2),max(tr(:,3),1e-16),'LineWidth',1.2); hold on;
    semilogy(tr(:,2),max(tr(:,4),1e-16),'LineWidth',1.2);
    grid on; xlabel('Slow time h n'); ylabel('Update residual');
    legend('W-FBRI','Governance','Location','southwest'); title('Joint convergence, h = 10^{-2}');
    nexttile; hold on;
    r = d.raw(strcmp(d.raw.Case,d.cases{ci}.name)&d.raw.SlowTime==1,:);
    lo = arrayfun(@(h) min(r.TrackingError(r.Step==h)),d.steps);
    hi = arrayfun(@(h) max(r.TrackingError(r.Step==h)),d.steps);
    med = arrayfun(@(h) median(r.TrackingError(r.Step==h)),d.steps);
    errorbar(d.steps,med,med-lo,hi-med,'o-','LineWidth',1.2);
    loglog(d.steps,med(1)*d.steps/d.steps(1),'k--','LineWidth',1);
    set(gca,'XScale','log','YScale','log'); grid on;
    xlabel('Governance step h'); ylabel('Tracking error at h n = 1');
    title(sprintf('20 starts; slope = %.3f',summary.TrackingSlope(ci)));
    legend('Median and range','Slope 1','Location','northwest');
end
exportgraphics(f,fullfile(id,'fig5_13b_r3_wfbri_governance.pdf'),'ContentType','vector');
exportgraphics(f,fullfile(id,'fig5_13b_r3_wfbri_governance.png'),'Resolution',180);
close(f);

% Compact main-paper view; the complete six-panel figure is supplementary.
f = figure('Visible','off','Units','inches','Position',[1,1,3.5,2.9],'Color','w');
set(f,'DefaultAxesFontName','Times New Roman','DefaultTextFontName','Times New Roman', ...
    'DefaultAxesFontSize',8,'DefaultLegendFontSize',7.5);
colors = lines(2); styles = {'-','--'};
ax = axes(f,'Position',[.17,.20,.79,.76]); hold(ax,'on');
for ci = 1:2
    tr = d.long_traces{ci};
    semilogy(ax,tr(:,2),max(tr(:,3:4),[],2),styles{ci}, ...
        'Color',colors(ci,:),'LineWidth',1.2);
end
set(ax,'YScale','log','XLim',[0,16],'YLim',[1e-10,1],'YTick',10.^(-10:2:0), ...
    'YMinorGrid','off','XMinorGrid','off','GridAlpha',.15);
grid(ax,'on'); xlabel(ax,'Slow time h n'); ylabel(ax,'Joint residual');
legend(ax,'Simulation III','Scenario B','Location','northeast','Box','off');
inset = axes(f,'Position',[.27,.31,.35,.24],'FontSize',7,'Box','on');
hold(inset,'on');
for ci = 1:2
    r = d.raw(strcmp(d.raw.Case,d.cases{ci}.name)&d.raw.SlowTime==1,:);
    med = arrayfun(@(h) median(r.TrackingError(r.Step==h)),d.steps);
    lo = arrayfun(@(h) min(r.TrackingError(r.Step==h)),d.steps);
    hi = arrayfun(@(h) max(r.TrackingError(r.Step==h)),d.steps);
    errorbar(inset,d.steps,med,med-lo,hi-med,'o','LineStyle',styles{ci}, ...
        'Color',colors(ci,:),'LineWidth',1,'MarkerSize',3,'CapSize',3);
end
set(inset,'XScale','log','YScale','log','XLim',[7e-5,1.4e-2], ...
    'XTick',d.steps,'YLim',[1e-13,1e-3],'YTick',[1e-10,1e-6], ...
    'YMinorGrid','off','XMinorGrid','off','GridAlpha',.15);
grid(inset,'on'); xlabel(inset,'Step h');
title(inset,'Tracking error, h n = 1','FontWeight','normal','FontSize',7);
exportgraphics(f,fullfile(id,'fig5_13b_r3_wfbri_governance_compact.pdf'),'ContentType','vector');
exportgraphics(f,fullfile(id,'fig5_13b_r3_wfbri_governance_compact.png'),'Resolution',300);
close(f);
end

function out = check_certificate_against_solver(cases,cert)
% Independent implementation check only; the full-domain interval proof is
% provided by verify_r3_closed_loop.py, not by these finite differences.
rows = cell(2,7); dxpairs = nchoosek(1:4,2); dwpairs = nchoosek(1:5,2);
for ci = 1:2
    cfg = cases{ci}; p = cfg.p; p.N = 2; p.R_max = 1; p.beta = 1;
    c = cert.cases(ci); bounds = str2double({c.kappa,c.B,c.c,c.d}); maxima = zeros(1,4);
    rng(349); step = 1e-6;
    for sample = 1:100
        x = .1+rand(4,1); x = x/sum(x); w = .1+rand(5,1); w = w/sum(w);
        for mode = 1:2
            if mode==1; pairs = dxpairs; dim=4; else; pairs=dwpairs; dim=5; end
            for j = 1:size(pairs,1)
                v = zeros(dim,1); v(pairs(j,1))=1; v(pairs(j,2))=-1;
                if mode==1
                    xp=x+step*v; xm=x-step*v; wp=w; wm=w;
                else
                    xp=x; xm=x; wp=w+step*v; wm=w-step*v;
                end
                bp=sec4_3_1_wfbri_solve(p,cfg.delta,p.P_pay*wp,.5,cfg.focus,repmat(xp',2,1));
                bm=sec4_3_1_wfbri_solve(p,cfg.delta,p.P_pay*wm,.5,cfg.focus,repmat(xm',2,1));
                a=norm(bp(1,:)-bm(1,:),1)/(4*step);
                b=norm(governance(xp,wp,p)-governance(xm,wm,p),1)/(4*step);
                maxima(mode)=max(maxima(mode),a); maxima(mode+2)=max(maxima(mode+2),b);
            end
        end
    end
    assert(all(maxima<=bounds+1e-8),'Canonical derivative exceeds certified bound.');
    rows(ci,:)={cfg.name,100,1600,maxima(1),maxima(2),maxima(3),maxima(4)};
end
out=cell2table(rows,'VariableNames',{'Case','Profiles','Directions','SampleKappa', ...
    'SampleB','Samplec','Sampled'});
end
