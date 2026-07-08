classdef SOTASolverContractTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function isobeUsesOuterNativeResidual(testCase)
            params = SOTASolverContractTest.params();
            [profile, history] = solve_isobe_app( ...
                params, 0, params.theta, 1);

            testCase.verifyTrue(history.converged);
            testCase.verifyLessThanOrEqual( ...
                history.final_native_residual, params.eps_tol);
            SOTASolverContractTest.verifyProfile(testCase, profile);
        end

        function rqeConvergesAndRiskKnobChangesPolicy(testCase)
            params = SOTASolverContractTest.params();
            lowRisk = params;
            lowRisk.rqe_tau = 0.01;
            highRisk = params;
            highRisk.rqe_tau = 100;

            [lowProfile, lowHistory] = solve_rqe( ...
                lowRisk, 0, params.theta, 1);
            [highProfile, highHistory] = solve_rqe( ...
                highRisk, 0, params.theta, 1);

            testCase.verifyTrue(lowHistory.converged);
            testCase.verifyTrue(highHistory.converged);
            testCase.verifyGreaterThan(norm( ...
                mean(lowProfile, 1) - mean(highProfile, 1), 1), 1e-3);
            kktResidual = SOTASolverContractTest.rqeKktResidual( ...
                highProfile, highRisk);
            testCase.verifyLessThanOrEqual( ...
                kktResidual, 2 * highRisk.eps_tol);
            SOTASolverContractTest.verifyProfile(testCase, highProfile);
        end

        function mfRqeConvergesOnSharedIntervalScenarios(testCase)
            params = SOTASolverContractTest.params();
            params.fou_modulation = true;
            [profile, history] = solve_mf_rqe( ...
                params, 0.20, params.theta, 1);

            testCase.verifyTrue(history.converged);
            testCase.verifyLessThanOrEqual( ...
                history.residual(end), params.eps_tol);
            SOTASolverContractTest.verifyProfile(testCase, profile);
        end

        function cvarRiskKnobMovesAwayFromAggressiveAction(testCase)
            params = SOTASolverContractTest.params();
            env = scenario_b_config('concentrated');
            params = scenario_b_env(params, env.fou_scale);
            mild = params;
            mild.cvar_alpha = 0.90;
            severe = params;
            severe.cvar_alpha = 0.05;

            [mildProfile, mildHistory] = solve_cvar_game( ...
                mild, env.delta, params.theta, 1);
            [severeProfile, severeHistory] = solve_cvar_game( ...
                severe, env.delta, params.theta, 1);

            testCase.verifyTrue(mildHistory.converged);
            testCase.verifyTrue(severeHistory.converged);
            testCase.verifyGreaterThan( ...
                mean(mildProfile(:, 1)), mean(severeProfile(:, 1)) + 0.5);
            SOTASolverContractTest.verifyProfile(testCase, severeProfile);
        end

        function drneReportsErgodicGapWithoutFalseConvergence(testCase)
            params = SOTASolverContractTest.params();
            params.R_max = 1000;
            params.fou_modulation = true;
            [profile, history] = solve_drne_vi( ...
                params, 0.20, params.theta, 1);

            testCase.verifyGreaterThan(history.residual(1), ...
                history.residual(end));
            testCase.verifyLessThan( ...
                history.residual(end), 0.1 * history.residual(1));
            testCase.verifyEqual(history.converged, ...
                history.residual(end) <= params.eps_tol);
            SOTASolverContractTest.verifyProfile(testCase, profile);
        end
    end

    methods (Static, Access=private)
        function params = params()
            params = config_params();
            params.N = 20;
            params.R_max = 300;
            params.eps_tol = 1e-4;
            params.rng_seed = 42;
        end

        function verifyProfile(testCase, profile)
            testCase.verifyTrue(all(isfinite(profile), 'all'));
            testCase.verifyGreaterThanOrEqual(min(profile, [], 'all'), 0);
            testCase.verifyEqual(sum(profile, 2), ...
                ones(size(profile, 1), 1), AbsTol=1e-10);
        end

        function residual = rqeKktResidual(profile, params)
            q = mean(profile, 1)';
            M = sota_reduced_matrix(params.theta, params);
            z = -params.rqe_tau * (M' * q);
            z = z - max(z);
            adversary = q .* exp(z);
            adversary = adversary / sum(adversary);
            target = sec4_3_1_softmax_br( ...
                M * adversary, params.lambda);
            residual = sum(abs(target - q));
        end
    end
end
