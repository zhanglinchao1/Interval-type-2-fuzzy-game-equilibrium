classdef M2FocusedCertificateTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                root, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function focusedCertificateBoundsExactRobustGap(testCase)
            params = M2FocusedCertificateTest.params();
            piStar = M2FocusedCertificateTest.profile();

            report = sec4_2_2_robust_alpha_fne( ...
                piStar, 0.2, params.theta, 0.5, params, 0, 6);

            testCase.verifyGreaterThanOrEqual( ...
                report.certificate_slack, -1e-12);
            testCase.verifyLessThanOrEqual( ...
                report.profile_interval_term, report.theoretical_bound + 1e-12);
            testCase.verifyEqual(report.total_checks, ...
                params.N * params.num_strategies);
        end

        function scalarFamilyRecoversTwoRadiusBound(testCase)
            params = M2FocusedCertificateTest.params();
            piStar = M2FocusedCertificateTest.profile();

            report = sec4_2_2_robust_alpha_fne( ...
                piStar, 0.2, params.theta, 0.5, params, 0, 0);

            testCase.verifyLessThanOrEqual( ...
                report.profile_interval_term, report.theoretical_bound + 1e-12);
            testCase.verifyEqual(report.focus_s, 0);
        end

        function oldTwoRadiusClaimFailsForFocusedPenalty(testCase)
            barR = 0.10;
            lowR = 0.05;
            focusExponent = 10;
            pDev = barR;
            pInc = lowR * (lowR / barR)^focusExponent;
            intervalTerm = barR + pDev + lowR - pInc;

            testCase.verifyGreaterThan(intervalTerm, 2 * barR);
            testCase.verifyLessThanOrEqual(intervalTerm, 3 * barR);
        end

        function actionVariationMissesPeakNormalizationShift(testCase)
            alpha = 0.2;
            focusExponent = 3;
            rhoA = [0.10, 0.20, 0.30, 0.40];
            rhoB = rhoA + 0.05;
            deltaRho = rhoB - rhoA;

            penaltyA = M2FocusedCertificateTest.focusedPenalty( ...
                rhoA, alpha, focusExponent);
            penaltyB = M2FocusedCertificateTest.focusedPenalty( ...
                rhoB, alpha, focusExponent);
            deltaPenalty = penaltyB - penaltyA;

            testCase.verifyEqual( ...
                max(deltaRho) - min(deltaRho), 0, AbsTol=1e-12);
            penaltyVariation = max(deltaPenalty) - min(deltaPenalty);
            testCase.verifyGreaterThan(penaltyVariation, 1e-5);

            strongBound = 2 * (1 - alpha) * ...
                (1 + 2 * focusExponent) * norm(deltaRho, Inf);
            testCase.verifyLessThanOrEqual( ...
                penaltyVariation, strongBound);
        end
    end

    methods (Static, Access=private)
        function penalty = focusedPenalty(rho, alpha, focusExponent)
            rhoPeak = max(max(rho), 0.01);
            penalty = (1 - alpha) * rho .* ...
                (rho / rhoPeak).^focusExponent;
        end

        function params = params()
            params = config_params();
            params.N = 5;
            params.fou_modulation = true;
            params.fou_strategy_scale = [1.6, 1.15, 0.85, 0.7];
        end

        function piStar = profile()
            piStar = [0.55, 0.20, 0.15, 0.10; ...
                      0.10, 0.45, 0.25, 0.20; ...
                      0.25, 0.15, 0.45, 0.15; ...
                      0.20, 0.25, 0.10, 0.45; ...
                      0.30, 0.20, 0.25, 0.25];
        end
    end
end
