classdef M1PayoffConsistencyTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function mixedExtensionMatchesPurePayoffWeights(testCase)
            [params, piProfile] = M1PayoffConsistencyTest.fixture();

            [Ulower, Uupper, Uhat, rho, pure] = ...
                sec4_1_2_mixed_payoff( ...
                piProfile, params.delta, params.theta, params);

            testCase.verifyEqual(Ulower, ...
                sum(piProfile .* pure.U_lower, 2), AbsTol=1e-12);
            testCase.verifyEqual(Uupper, ...
                sum(piProfile .* pure.U_upper, 2), AbsTol=1e-12);
            testCase.verifyEqual(Uhat, ...
                sum(piProfile .* pure.U_hat, 2), AbsTol=1e-12);
            testCase.verifyEqual(rho, ...
                sum(piProfile .* pure.rho, 2), AbsTol=1e-12);
        end

        function linearAggregationCommutesWithExpectation(testCase)
            [params, piProfile] = M1PayoffConsistencyTest.fixture();
            params.payoff_aggregation = 'linear';

            [Ulower, Uupper, ~, ~, pure] = ...
                sec4_1_2_mixed_payoff( ...
                piProfile, 0.02, params.theta, params);
            weights = reshape(piProfile, size(piProfile, 1), ...
                size(piProfile, 2), 1);
            mixedMuLower = squeeze(sum(weights .* pure.mu_lower, 2));
            mixedMuUpper = squeeze(sum(weights .* pure.mu_upper, 2));

            testCase.verifyEqual(Ulower, mixedMuLower * params.theta, ...
                AbsTol=1e-12);
            testCase.verifyEqual(Uupper, mixedMuUpper * params.theta, ...
                AbsTol=1e-12);
        end

        function concaveAggregationDoesNotCommuteWithExpectation(testCase)
            [params, piProfile] = M1PayoffConsistencyTest.fixture();

            [~, ~, Uhat, ~, pure] = sec4_1_2_mixed_payoff( ...
                piProfile, 0, params.theta, params);
            weights = reshape(piProfile, size(piProfile, 1), ...
                size(piProfile, 2), 1);
            mixedMu = squeeze(sum(weights .* pure.mu_lower, 2));
            aggregateThenTransform = ...
                (2 * mixedMu - mixedMu.^2) * params.theta;

            testCase.verifyGreaterThan( ...
                max(abs(Uhat - aggregateThenTransform)), 1e-4);
        end

        function purePayoffUsesLeaveOneOutMeanField(testCase)
            params = M1PayoffConsistencyTest.smallParams();
            piProfile = [1, 0, 0, 0; 0, 1, 0, 0; 0, 0, 1, 0];
            expectedMean = [0, 0.5, 0.5, 0];
            expectedTrust = params.trust_matrix * expectedMean';

            [~, ~, ~, ~, muLower, muUpper] = ...
                sec4_1_2_pure_interval_payoff_vector( ...
                piProfile, 0, params.theta, params, 1);

            testCase.verifyEqual(muLower(:, 1), expectedTrust, ...
                AbsTol=1e-12);
            testCase.verifyEqual(muUpper(:, 1), expectedTrust, ...
                AbsTol=1e-12);
        end

        function softmaxSolvesEntropyRegularizedLinearResponse(testCase)
            payoff = [0.2; 0.4; 0.1; 0.3];
            lambda = 0.15;
            expected = exp(payoff / lambda);
            expected = expected / sum(expected);

            actual = sec4_3_1_softmax_br(payoff, lambda);

            testCase.verifyEqual(actual, expected, AbsTol=1e-12);
        end

        function solverHistoryUsesCanonicalMixedEvaluator(testCase)
            params = M1PayoffConsistencyTest.smallParams();
            params.R_max = 200;

            [piStar, history] = sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta);
            [~, ~, Uhat] = sec4_1_2_mixed_payoff( ...
                piStar, params.delta, params.theta, params);

            testCase.verifyTrue(history.converged);
            testCase.verifyEqual(history.avg_payoff(end), mean(Uhat), ...
                AbsTol=1e-12);
        end

        function alphaWrapperUsesCanonicalSolver(testCase)
            params = M1PayoffConsistencyTest.smallParams();
            params.fou_modulation = true;
            params.fou_strategy_scale = [1.5, 1.2, 0.8, 0.6];
            alpha = 0.4;
            focusS = 2;

            [piCanonical, historyCanonical] = ...
                sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta, alpha, focusS);
            [piWrapper, historyWrapper] = ...
                sec5_1_alpha_robust_solve( ...
                params, params.delta, params.theta, alpha, focusS);

            testCase.verifyEqual(piWrapper, piCanonical, AbsTol=1e-12);
            testCase.verifyEqual(historyWrapper.residual, ...
                historyCanonical.residual, AbsTol=1e-12);
            testCase.verifyEqual(historyCanonical.alpha, alpha);
            testCase.verifyEqual(historyCanonical.focus_s, focusS);
        end

        function midpointCallMatchesExplicitAlphaOne(testCase)
            params = M1PayoffConsistencyTest.smallParams();

            [piLegacy, historyLegacy] = sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta);
            [piExplicit, historyExplicit] = sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta, 1, 0);

            testCase.verifyEqual(piLegacy, piExplicit, AbsTol=1e-12);
            testCase.verifyEqual(historyLegacy.residual, ...
                historyExplicit.residual, AbsTol=1e-12);
        end

        function rejectsInvalidFamilyParameters(testCase)
            params = M1PayoffConsistencyTest.smallParams();

            testCase.verifyError(@() sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta, -0.1, 0), ...
                'sec4_3_1_wfbri_solve:badAlpha');
            testCase.verifyError(@() sec4_3_1_wfbri_solve( ...
                params, params.delta, params.theta, 0.5, -1), ...
                'sec4_3_1_wfbri_solve:badFocus');
        end

        function leaveOneOutRejectsSingleAgentProfile(testCase)
            params = M1PayoffConsistencyTest.smallParams();
            profile = ones(1, params.num_strategies) ...
                / params.num_strategies;

            testCase.verifyError(@() ...
                sec4_1_2_pure_interval_payoff_vector( ...
                profile, params.delta, params.theta, params, 1), ...
                'sec4_1_2_pure_interval_payoff_matrix:requiresTwoAgents');
        end

        function productionCodeDoesNotUseForbiddenMixedPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            files = [dir(fullfile(root, '*.m')); ...
                dir(fullfile(root, 'utils', '*.m'))];
            forbidden = 'sec4_1_1_induced_membership(';
            allowed = ["verify_setup.m", "sec4_1_1_induced_membership.m"];

            for idx = 1:numel(files)
                if any(string(files(idx).name) == allowed)
                    continue;
                end
                text = fileread(fullfile(files(idx).folder, files(idx).name));
                testCase.verifyFalse(contains(text, forbidden), ...
                    sprintf('Forbidden mixed-membership path in %s.', ...
                    files(idx).name));
            end
        end
    end

    methods (Static, Access=private)
        function [params, piProfile] = fixture()
            params = M1PayoffConsistencyTest.smallParams();
            piProfile = [0.55, 0.20, 0.15, 0.10; ...
                         0.10, 0.45, 0.25, 0.20; ...
                         0.25, 0.15, 0.45, 0.15; ...
                         0.20, 0.25, 0.10, 0.45; ...
                         0.30, 0.20, 0.25, 0.25];
        end

        function params = smallParams()
            params = config_params();
            params.N = 5;
            params.rng_seed = 42;
            params.beta = 0.3;
            params.lambda = 0.15;
            params.eps_tol = 1e-6;
            params.R_max = 100;
        end
    end
end
