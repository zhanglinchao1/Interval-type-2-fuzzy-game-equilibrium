function exp_5_2_r3_sparse_validation(stage)
% R3-5 cross-language audit using the existing canonical payoff and W-FBRI.
    if nargin==0, stage='check'; end
    root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'utils'));
    out=fullfile(root,'table','r3q5');
    p=config_params(); p.N=2; p.lambda=.15; p.beta=.3; p.R_max=1;
    p.eps_tol=0; p.fou_modulation=false;
    P=[.6 .5 .4 .3 .2;.3 .4 .35 .5 .3;.1 .1 .25 .2 .5];
    pg=p; pg.payoff_aggregation='linear'; pg.governance_noise_std=0;
    pg.delay_matrix=[.85 .75 .5 .3;.8 .7 .45 .25;.6 .55 .4 .2;.4 .35 .25 .15];
    pg.res_matrix=[.7 .8 .6 .4;.65 .75 .55 .35;.55 .65 .5 .3;.45 .55 .4 .25];
    if strcmp(stage,'prepare')
        rng(305); rows=zeros(440,15);
        for k=1:440
            role=mod(k,2); x=rand(1,4); x=x/sum(x);
            pi=rand(1,4); if role, pi(3:4)=0; end; pi=pi/sum(pi);
            w=rand(1,5); w=w/sum(w);
            if k<=40, x=zeros(1,4);x(1+mod(k,4))=1;w=zeros(1,5);w(1+mod(k,5))=1;end
            rows(k,:)=[k role x pi w];
        end
        writematrix(rows,fullfile(out,'inputs.txt'),'Delimiter',' ');
        save(fullfile(out,'matlab_inputs.mat'),'p','pg','P','rows');
        fprintf('Prepared %d paired cases, including all x/P vertices and both roles.\n',size(rows,1));
        return
    end
    data=load(fullfile(out,'matlab_inputs.mat')); rows=data.rows;
    cpp=readmatrix(fullfile(out,'cpp_consistency.csv'));
    assert(isequal(cpp(:,1:2),rows(:,1:2)));
    expected=zeros(size(cpp)); expected(:,1:2)=cpp(:,1:2);
    for k=1:size(rows,1)
        role=rows(k,2);x=rows(k,3:6);pi=rows(k,7:10);w=rows(k,11:15)';
        theta=P*w;theta=theta/sum(theta);
        pp=p; pp.feasible_mask=true(2,4);
        if role,pp.feasible_mask(1,3:4)=false;end
        % N=2 gives exactly the prescribed local x for the first agent.
        [~,~,c,r]=sec4_1_2_pure_interval_payoff_matrix([pi;x],.2,theta,pp);
        pn=sec4_3_1_wfbri_solve(pp,.2,theta,.5,0,[pi;x]);
        delta=sec4_4_3_governance_performance(x',w,P,pg);
        wn=sec3_2_project_simplex(w+.004*(sec3_2_bounded_sigma(delta)-w));
        expected(k,3:end)=[c(1,:) r(1,:) c(1,:)-.5*r(1,:) pn(1,:) wn'];
    end
    err=abs(cpp-expected);
    names={'center';'radius';'scalar_payoff';'damped_step';'governance_step'};
    groups={3:6,7:10,11:14,15:18,19:23}; max_error=zeros(5,1);
    for k=1:5,max_error(k)=max(err(:,groups{k}),[],'all');end
    assert(all(max_error<3e-14),'C++/MATLAB mismatch');
    writetable(table(names,max_error),fullfile(out,'consistency_summary.csv'));
    disp(table(names,max_error));
    ref=readmatrix(fullfile(out,'reference.csv'));
    x=ref(1:4);w=ref(5:9)';theta=P*w;theta=theta/sum(theta);
    pp=p;pp.R_max=1;xn=sec4_3_1_wfbri_solve(pp,.2,theta,.5,0,[x;x]);
    d=sec4_4_3_governance_performance(x',w,P,pg);
    fixed_residual=max(norm(xn(1,:)-x,1),norm(sec3_2_bounded_sigma(d)-w,1));
    fprintf('Independent MATLAB joint reference residual: %.17g\n',fixed_residual);
    assert(fixed_residual<1e-11);
    cert=jsondecode(fileread(fullfile(out,'certificate.json')));
    rng(3055); maxima=zeros(1,6); step=1e-6;
    for n=1:100
        z=rand(4,1);z=z/sum(z);z=.75*z;z(1)=z(1)+.25;
        u=rand(5,1);u=.2+.03*(u-mean(u));
        for a=1:4
            for b=a+1:4
                v=zeros(4,1);v(a)=step;v(b)=-step;
                for role=0:1
                    diff=local_br(p,z+v,P*u,role)-local_br(p,z-v,P*u,role);
                    maxima(1+role)=max(maxima(1+role),norm(diff,1)/(4*step));
                end
                diff=local_sigma(pg,z+v,u,P)-local_sigma(pg,z-v,u,P);
                maxima(5)=max(maxima(5),norm(diff,1)/(4*step));
            end
        end
        for a=1:5
            for b=a+1:5
                v=zeros(5,1);v(a)=step;v(b)=-step;
                for role=0:1
                    diff=local_br(p,z,P*(u+v),role)-local_br(p,z,P*(u-v),role);
                    maxima(3+role)=max(maxima(3+role),norm(diff,1)/(4*step));
                end
                diff=local_sigma(pg,z,u+v,P)-local_sigma(pg,z,u-v,P);
                maxima(6)=max(maxima(6),norm(diff,1)/(4*step));
            end
        end
    end
    bounds=[str2double(cert.kappa_vehicle),str2double(cert.kappa_rsu), ...
        str2double(cert.B_vehicle),str2double(cert.B_rsu),str2double(cert.c),str2double(cert.d)];
    assert(all(maxima<bounds));
    labels={'kappa_vehicle';'kappa_rsu';'B_vehicle';'B_rsu';'c';'d'};
    writetable(table(labels,maxima',bounds','VariableNames',{'constant','sampled_max','certified_bound'}), ...
        fullfile(out,'matlab_derivative_crosscheck.csv'));
    % A verified negative control, outside the actual invariant domain.
    z=[.104;.066;.022;.808];u=[.92;.05;.01;.01;.01];v=[step;0;0;-step];
    full_domain_counter=norm(local_br(p,z+v,P*u,0)-local_br(p,z-v,P*u,0),1)/(4*step);
    assert(full_domain_counter>1.14);
    fprintf('Canonical derivative cross-check PASS; full-domain counterexample %.9f.\n',full_domain_counter);
    fid=fopen(fullfile(out,'matlab_check.json'),'w');
    fprintf(fid,'{"status":"PASS","cases":%d,"max_error":%.17g,"reference_residual":%.17g}\n',size(rows,1),max(max_error),fixed_residual);fclose(fid);
end

function b=local_br(p,x,theta,role)
    theta=theta/sum(theta);
    [~,~,c,r]=sec4_1_2_pure_interval_payoff_matrix([ones(1,4)/4;x'],.2,theta,p);
    nu=c(1,:)-.5*r(1,:);if role,nu(3:4)=-inf;end
    b=sec4_3_1_softmax_br(nu',p.lambda);
end

function s=local_sigma(p,x,w,P)
    s=sec3_2_bounded_sigma(sec4_4_3_governance_performance(x,w,P,p));
end
