function [x, fval, exitflag] = lp_linprog_compat(f, A, b, Aeq, beq, lb, ub)
%LP_LINPROG_COMPAT linprog 兼容层: min f'x s.t. A x <= b, Aeq x = beq, lb<=x<=ub.
%   有 Optimization Toolbox 时直接用原生 linprog (dual-simplex, 高精度容差);
%   否则回落到宿主机 Python 的 scipy.optimize.linprog (HiGHS)。两条路径求解
%   同一 LP, 最优值一致; 简并时可能返回不同最优顶点 (对本仓库的阻尼固定点
%   迭代无影响, 目标值唯一)。
%
%   返回: x (列向量), fval = f'x, exitflag (1=成功, <=0 失败)。

    persistent use_native
    if isempty(use_native)
        use_native = exist('linprog', 'file') == 2 && ...
            exist('optimoptions', 'file') == 2 && ...
            license('test', 'Optimization_Toolbox');
    end

    if use_native
        options = optimoptions('linprog', 'Display', 'none', ...
            'OptimalityTolerance', 1e-10, 'ConstraintTolerance', 1e-10);
        [x, fval, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, options);
        return;
    end

    % ---- scipy fallback (HiGHS) ----
    np = py.importlib.import_module('numpy');
    opt = py.importlib.import_module('scipy.optimize');

    n = numel(f);
    bounds = py.list();
    for j = 1:n
        if isinf(lb(j)); lo = py.None; else; lo = lb(j); end
        if isinf(ub(j)); hi = py.None; else; hi = ub(j); end
        bounds.append(py.tuple({lo, hi}));
    end

    if isempty(A);   A_ub = py.None; b_ub = py.None;
    else;            A_ub = to_np2(np, A); b_ub = to_np(np, b(:)'); end
    if isempty(Aeq); A_eq = py.None; b_eq = py.None;
    else;            A_eq = to_np2(np, Aeq); b_eq = to_np(np, beq(:)'); end
    kw = pyargs( ...
        'A_ub', A_ub, 'b_ub', b_ub, 'A_eq', A_eq, 'b_eq', b_eq, ...
        'bounds', bounds, 'method', 'highs');
    res = opt.linprog(to_np(np, f(:)'), kw);

    ok = logical(py.getattr(res, 'success'));
    if ok
        exitflag = 1;
        x = double(py.getattr(res, 'x'));
        x = x(:);
        fval = double(py.getattr(res, 'fun'));
    else
        exitflag = -1;
        x = nan(n, 1);
        fval = NaN;
    end
end

function a = to_np(np, m)
%TO_NP MATLAB 行向量 -> numpy 1D 数组。
    a = np.array(m(:)');
end

function a = to_np2(np, m)
%TO_NP2 MATLAB 矩阵 -> numpy 2D 数组 (逐行传递, 单行也保持 2D)。
    rows = py.list();
    for r = 1:size(m, 1)
        rows.append(np.array(m(r, :)));
    end
    a = np.vstack(rows);
end
