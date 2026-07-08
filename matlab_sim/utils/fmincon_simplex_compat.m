function [x, fval, exitflag, output] = fmincon_simplex_compat( ...
    objective, x0, floor_x)
%FMINCON_SIMPLEX_COMPAT 单纯形上光滑(强)凸最小化的 fmincon 兼容层。
%   求解  min f(x)  s.t.  sum(x)=1, x >= floor_x,
%   其中 objective 返回 [value, gradient] (精确梯度, 与 solve_rqe /
%   solve_mf_rqe 的 B_opt 内层问题一致)。
%
%   有 Optimization Toolbox 时: 使用与原实现完全相同的 fmincon
%   interior-point 配置 (逐字保留原容差), 行为与历史版本一致。
%   无工具箱时: 熵镜像下降 (exponentiated gradient) + Armijo 回溯,
%   以单纯形一阶最优性残差 fo = g'x - min_j g_j 为停止准则 (fo 即沿最陡
%   可行方向的下降斜率, fo=0 等价于 KKT)。对 epsilon-强凸目标线性收敛。
%
%   输出与 fmincon 对齐: x, fval, exitflag (1=达到最优性容差),
%   output.firstorderopt。

    ns = numel(x0);
    x0 = max(x0(:), floor_x);
    x0 = x0 / sum(x0);

    persistent has_fmincon
    if isempty(has_fmincon)
        has_fmincon = false;
        try
            probe = optimoptions('fmincon', 'Display', 'off'); %#ok<NASGU>
            % 实测一次极小问题, 确认可运行 (避免残缺安装/无许可证误判)
            fmincon(@(z) z.^2, 0.5, [], [], [], [], 0, 1, [], ...
                optimoptions('fmincon', 'Display', 'off'));
            has_fmincon = true;
        catch
            has_fmincon = false;
        end
    end

    if has_fmincon
        options = optimoptions('fmincon', ...
            'Algorithm', 'interior-point', ...
            'SpecifyObjectiveGradient', true, ...
            'Display', 'off', ...
            'MaxIterations', 100, ...
            'OptimalityTolerance', 1e-10, ...
            'ConstraintTolerance', 1e-12, ...
            'StepTolerance', 1e-12);
        [x, fval, exitflag, output] = fmincon(objective, x0, [], [], ...
            ones(1, ns), 1, floor_x * ones(ns, 1), ones(ns, 1), [], ...
            options);
        return;
    end

    % ---- 熵镜像下降 + Frank-Wolfe 备选的回退路径 ----
    fo_tol = 1e-10;
    max_iter = 50000;
    x = x0;
    [fval, g] = objective(x);
    eta = 1.0;
    it = 0;
    for it = 1:max_iter
        fo = g' * x - min(g);          % 单纯形一阶最优性残差 (>=0)
        if fo <= fo_tol
            break;
        end

        % 候选 1: 熵镜像步 (回溯)
        best_f = fval; best_x = x;
        z = g - max(g);                % 数值稳定
        eta_try = eta;
        for bt = 1:40
            x_md = x .* exp(-eta_try * z);
            x_md = max(x_md / sum(x_md), floor_x);
            x_md = x_md / sum(x_md);
            f_md = objective(x_md);
            if f_md < best_f
                best_f = f_md; best_x = x_md; eta = min(eta_try * 2, 1e3);
                break;
            end
            eta_try = eta_try / 2;
        end

        % 候选 2: Frank-Wolfe 步 (朝 argmin g 的顶点, 回溯 t)
        [~, j_star] = min(g);
        e_star = floor_x * ones(ns, 1);
        e_star(j_star) = 1 - (ns - 1) * floor_x;
        t = 1.0;
        for bt = 1:40
            x_fw = (1 - t) * x + t * e_star;
            f_fw = objective(x_fw);
            if f_fw < best_f
                best_f = f_fw; best_x = x_fw;
                break;
            end
            t = t / 2;
        end

        if best_f >= fval - 1e-16
            break;                     % 两个方向都无法下降 (数值极限)
        end
        x = best_x;
        [fval, g] = objective(x);
    end
    fo = g' * x - min(g);
    output.firstorderopt = fo;
    output.iterations = it;
    if fo <= 1e-7
        exitflag = 1;
    else
        exitflag = 0;
    end
end
