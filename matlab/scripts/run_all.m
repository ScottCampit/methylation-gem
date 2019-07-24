%% Run analyses for epigenome-scale metabolic models
initCobraToolbox;
changeCobraSolver('gurobi');

%% Load genome-scale metabolic models. Must run from `/matlab/scripts` directory

% The bulk eGEM model
load ./../models/eGEM.mat 
model = eGEM;

% New acetylation model containing ACSS2 and PDH in nucleus
%load ./../models/acetyl2.mat

% Minial eGEM that does not contain one carbon reactions and demethylation
% rxns
%load ./../models/min.mat % minimal eGEM model
%model = eGEM_min;

% Human metabolic reconstruction 1 (RECON1; Duarte et al., 2007)
%load ./../models/recon1
%model = metabolicmodel;

% Acetylation model from Shen et al., 2019
%load ./../shen-et-al/supplementary_software_code acetylation_model
%model = acetylation_model; 

%% Metabolic sensitivity analysis for excess and depleted medium components
    % INPUT:
        % switch case arguments:
            % single-reaction-analysis - optimizes the flux of a single
            % reaction
            % dyn - optimizes the flux of several reactions using the results
            % from `single-reaction-analysis`
            % grate - fix biomass to max value and optimize for histone
            % markers
    % OUTPUT: 
        % Heatmaps of the metabolic fluxes, shadow prices, and reduced
        % costs corresponding to each reaction / medium component pair.

% All reactions
load('./../vars/metabolites.mat')
        
% Optimization 1A: Run Single reaction activity (SRA)
%medium_of_interest = {'RPMI', 'DMEM', 'L15'};
[~, medium] = xlsfinfo('./../../data/uptake.xlsx');
medium_of_interest = medium(:, 1:5);
epsilon2 = [1E-6, 1E-5, 1E-4, 1E-3, 1E-2, 0.1, 1];
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    for n = 1:length(epsilon2)
        % Run all
        str =  strcat("[sra", string(n), '_', medium_of_interest(med),...
            "] = metabolic_sensitivity(model, metabolites, 'n',", ...
            "epsilon2(n), 'sra', medium_of_interest(med), [], 'hypoxic');");
        eval(str);
        % Plot all
        str = strcat("plot_heatmap(sra", string(n), '_',...
           medium_of_interest(med), ", metabolites, 'sra', epsilon2(n), medium_of_interest(med))");
        eval(str);
    end
end

% Calculate epsilon2 values to use for fba by dynamic range
for i=1:length(medium_of_interest)
    str = strcat("epsilon2_",lower(medium_of_interest(i)), " = ", ...
        "dynamic_range(sra1_", medium_of_interest(i), ", ", ...
        "sra2_", medium_of_interest(i), ", ", ...
        "sra3_", medium_of_interest(i), ", ", ...
        "sra4_", medium_of_interest(i), ", ", ...
        "sra5_", medium_of_interest(i), ", ", ...
        "sra6_", medium_of_interest(i), ", ", ...
        "sra7_", medium_of_interest(i), ", ", ...
        "'dynamic');");
    eval(str);
end

% Construct the LeRoy epsilon dataset
LeRoy_epsilon = struct('name', 'LeRoy');
fields = {...
    'DMEM'; 'RPMI'; 'L15'; 'McCoy5A'; 'Iscove';
    };
values = {...
    epsilon2_dmem; epsilon2_rpmi; ...
    epsilon2_l15; epsilon2_mccoy5a; ...
    epsilon2_iscove;
    };

for i=1:length(fields)
    LeRoy_epsilon.(fields{i}) = values{i};
end
save('LeRoy_epsilon1.mat', 'LeRoy_epsilon');

CCLE_epsilon = LeRoy_epsilon1;
f = fieldnames(LeRoy_epsilon3);
for i=1:length(f)
    CCLE_epsilon.(f{i}) = LeRoy_epsilon3.(f{i});
end

CCLE_epsilon = MergeStructs(LeRoy_epsilon1, LeRoy_epsilon2);

% Optimization procedures using FBA and FVA
for med = 1:length(medium_of_interest)
    % Run all reactions using FBA w/o competition for all reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_noCompetition]", ...
        "= metabolic_sensitivity(model, metabolites, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'no_competition',", ...
        "medium_of_interest(med), []);");
    eval(str);
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)),...
        "_noComp, metabolites, 'no_competition', epsilon2, medium_of_interest(med))");
    eval(str);

    % Run all reactions using FBA w/ competition for all reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"_competition, ", ...
        "] = metabolic_sensitivity(model, metabolites, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'competition',", ...
        "medium_of_interest(med), []);"); 
    eval(str);
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)), ...
        "_comp, metabolites, 'competition', epsilon2, medium_of_interest(med))");
    eval(str);

    % Run FVA for all reactions
    str =  strcat("[fva_", lower(medium_of_interest(med)),...
        "] = metabolic_sensitivity(model, metabolites, 'n', epsilon2_",...
        lower(medium_of_interest(med)), ", 'zscore', 'fva', medium_of_interest(med), 90);");
    eval(str);
    str = strcat("plot_heatmap(fva_", lower(medium_of_interest(med)),...
        ", metabolites, 'fva', epsilon2, medium_of_interest(med))");
    eval(str);
end

% Save results for all reactions - FIX AND MAKE THIS AUTOMATIC
% [fba_nocomp_rpmi_excess, fba_nocomp_rpmi_depletion] = metabolite_dict(fba_rpmi_noComp, metabolites, 'RPMI', 'T2| All Rxns FBA', 'no_competition');
% [fba_nocomp_dmem_excess, fba_nocomp_dmem_depletion] = metabolite_dict(fba_dmem_noComp, metabolites, 'DMEM', 'T2| All Rxns FBA', 'no_competition');
% [fba_nocomp_l15_excess, fba_nocomp_l15_depletion] = metabolite_dict(fba_l15_noComp, metabolites, 'L15', 'T2| All Rxns FBA', 'no_competition');
% [fba_comp_rpmi_excess, fba_comp_rpmi_depletion] = metabolite_dict(fba_rpmi_comp, metabolites, 'RPMI', 'T2| All Rxns FBA', 'competition');
% [fba_comp_dmem_excess, fba_comp_dmem_depletion] = metabolite_dict(fba_dmem_comp, metabolites, 'DMEM', 'T2| All Rxns FBA', 'competition');
% [fba_comp_l15_excess, fba_comp_l15_depletion] = metabolite_dict(fba_l15_comp,  metabolites,'L15', 'T2| All Rxns FBA', 'competition');
% [fva_rpmi_excess, fva_rpmi_depletion] = metabolite_dict(fva_rpmi,  metabolites, 'RPMI', 'T3| All Rxns FVA', 'fva');
% [fva_dmem_excess, fva_dmem_depletion] = metabolite_dict(fva_dmem,  metabolites, 'DMEM', 'T3| All Rxns FVA', 'fva');
% [fva_l15_excess, fva_l15_depletion] = metabolite_dict(fva_l15,  metabolites, 'L15', 'T3| All Rxns FVA', 'fva');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Histone reactions only
load ./../models/eGEM.mat 
model = eGEM;
load('./../vars/metabolites.mat')
histone_rxns_only = metabolites(3:6, :);
[~, medium] = xlsfinfo('./../../data/uptake.xlsx');

% Optimization 1B: Run Single reaction activity (SRA) for histone reactions
% only
epsilon2 = [1E-6, 1E-5, 1E-4, 1E-3, 1E-2, 0.1, 1];
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    for n = 1:length(epsilon2)
        % Run all
        str =  strcat("[sra_hist_", string(n), '_', medium_of_interest(med),...
            "] = metabolic_sensitivity(model, histone_rxns_only,", ...
            " epsilon2(n), 'sra', medium_of_interest(med), [], 'normoxic');");
        eval(str)
        
        % Plot all
%         str = strcat("plot_heatmap(sra_hist_", string(n), '_',...
%             medium_of_interest(med), ", histone_rxns_only, 'sra', epsilon2(n), medium_of_interest(med))");
%         eval(str)
    end
end

epsilon2 = [1E-6, 1E-5, 1E-4, 1E-3, 1E-2, 0.1, 1];
for i=1:length(medium)
    for n = 1:length(epsilon2)
        str = strcat("epsilon2_histOnly_", lower(medium_of_interest(i)), " = ", ...
            "dynamic_range(sra_hist_", string(n), '_', medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "sra_hist_",string(n), '_',  medium_of_interest(i), ", ", ...
            "'dynamic');");
        eval(str);
    end
end

% Construct the CCLE histone only epsilon dataset
CCLE_histOnly_epsilon = struct('name', 'CCLE_histOnly');
fields = {...
    'alphaMEM'; 'DMEM'; 'DMEMF12';...
    'DMEMIscove'; 'DMEMRPMI21'; ...
    'HAMF10'; 'HAMF12'; 'Iscove'; ...
    'L15'; 'M199'; 'McCoy5A'; ...
    'MCDB105'; 'MCDB105M199'; ...
    'RPMI'; 'RPMIF12'; 'RPMIIscove'; ...
    'RPMIwGln'; 'Waymouth'; 'Williams';
    };
values = {...
    epsilon2_histOnly_alphamem; epsilon2_histOnly_dmem; epsilon2_histOnly_dmemf12; ... ...
    epsilon2_histOnly_dmemiscove; epsilon2_histOnly_dmemrpmi21; ...
    epsilon2_histOnly_hamf10; epsilon2_histOnly_hamf12; epsilon2_histOnly_iscove; ...
    epsilon2_histOnly_l15; epsilon2_histOnly_m199; epsilon2_histOnly_mccoy5a; ...
    epsilon2_histOnly_mcdb105; epsilon2_histOnly_mcdb105m199; ...
    epsilon2_histOnly_rpmi; epsilon2_histOnly_rpmif12; epsilon2_histOnly_rpmiiscove; ...
    epsilon2_histOnly_rpmiwgln; epsilon2_histOnly_waymouth; epsilon2_histOnly_williams;
    };

for i=1:length(fields)
    CCLE_histOnly_epsilon.(fields{i}) = values{i};
end
save('CCLE_histOnly_epsilon.mat', 'CCLE_histOnly_epsilon');

% Construct the LeRoy histone only epsilon dataset
LeRoy_histOnly_epsilon = struct('name', 'LeRoy_histOnly');
fields = {...
    'DMEM'; 
    'HAMF12'; 'Iscove'; ...
    'L15'; 'McCoy5A'; ...
    'RPMI'; ...
    };
values = {...
    epsilon2_histOnly_dmem; ...
    epsilon2_histOnly_hamf12; epsilon2_histOnly_iscove; ...
    epsilon2_histOnly_l15; epsilon2_histOnly_mccoy5a; ...
    epsilon2_histOnly_rpmi; ...
    };

for i=1:length(fields)
    LeRoy_histOnly_epsilon.(fields{i}) = values{i};
end
save('LeRoy_histOnly_epsilon.mat', 'LeRoy_histOnly_epsilon');

load ./../vars/LeRoy_histOnly_epsilon.mat
% Optimization 2B: Run Flux balance analysis (FBA) w/ and w/o competition
for med = 1:length(medium_of_interest)
    disp(medium_of_interest(med))
    
    % Run all without competition for histone reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"histOnly_noComp]", ...
        "= metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'no_competition',", ...
        "medium_of_interest(med), []);");
    eval(str)

    % Run all w/ competition for histone reactions
    str =  strcat("[fba_", lower(medium_of_interest(med)),"histOnly_comp",
        "] = metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_", ...
        lower(medium_of_interest(med)), ", 'zscore', 'competition',", ...
        "medium_of_interest(med), []);"); 
    eval(str)
    
    str = strcat("plot_heatmap(fba_", lower(medium_of_interest(med)), ...
        "_comp, histone_rxns_only, 'competition', 'comp', medium_of_interest(med))");
    eval(str)
end

% Optimization 3C: Run Flux variability analysis (FVA) for histone
% reactions
for med=1:length(medium_of_interest)
    str =  strcat("[fva_", lower(medium_of_interest(med)),...
        "] = metabolic_sensitivity(model, histone_rxns_only, 'n', epsilon2_",...
        lower(medium_of_interest(med)), ", 'zscore', 'fva', medium_of_interest(med), 100);");
    eval(str)
    
    % Plot
    str = strcat("plot_heatmap(fva_", lower(medium_of_interest(med)),...
        ", histone_rxns_only, 'fva', 'fva_hist', medium_of_interest(med))");
    eval(str)
end

% Save results for histone reactions only - FIX AND MAKE THIS AUTOMATIC
% [fba_nocomp_rpmi_excess, fba_nocomp_rpmi_depletion] = metabolite_dict(fba_rpmi_noComp, histone_rxns_only, 'RPMI', 'T2| All Rxns FBA', 'no_competition');
% [fba_nocomp_dmem_excess, fba_nocomp_dmem_depletion] = metabolite_dict(fba_dmem_noComp, histone_rxns_only, 'DMEM', 'T2| All Rxns FBA', 'no_competition');
% [fba_nocomp_l15_excess, fba_nocomp_l15_depletion] = metabolite_dict(fba_l15_noComp, histone_rxns_only, 'L15', 'T2| All Rxns FBA', 'no_competition');
% [fba_comp_rpmi_excess, fba_comp_rpmi_depletion] = metabolite_dict(fba_rpmi_comp, histone_rxns_only, 'RPMI', 'T2| All Rxns FBA', 'competition');
% [fba_comp_dmem_excess, fba_comp_dmem_depletion] = metabolite_dict(fba_dmem_comp, histone_rxns_only, 'DMEM', 'T2| All Rxns FBA', 'competition');
% [fba_comp_l15_excess, fba_comp_l15_depletion] = metabolite_dict(fba_l15_comp, histone_rxns_only, 'L15', 'T2| All Rxns FBA', 'competition');
% [fva_rpmi_excess, fva_rpmi_depletion] = metabolite_dict(fva_rpmi, histone_rxns_only, 'RPMI', 'T3| All Rxns FVA', 'fva');
% [fva_dmem_excess, fva_dmem_depletion] = metabolite_dict(fva_dmem, histone_rxns_only, 'DMEM', 'T3| All Rxns FVA', 'fva');
% [fva_l15_excess, fva_l15_depletion] = metabolite_dict(fva_l15, histone_rxns_only, 'L15', 'T3| All Rxns FVA', 'fva');

%% Correlation values between histone markers and metabolic flux
% INPUTS:
    % h3marks: list of H3 marks from CCLE data (column values)
    % h3names: list of CCLE cell lines (row values)
    % h3vals: matrix containing values corresponding to h3marks and h3names

% Load all epsilon values
load ./../vars/LeRoy_epsilon1;
load ./../vars/CCLE_epsilon;

% Reactions of interest
load('./../vars/metabolites.mat')
histone_rxns_only = metabolites(2:5, :);

% Initialize params for iMAT algorithm
compartment = 'n';
mode = 1;
epsilon = 1E-3;
rho = 1;
kappa = 1E-3;
minfluxflag = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% All reactions
% LeRoy et al., proteomics dataset
[LeRoy_fva_statistics] = histone_corr(model, metabolites, LeRoy_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'fva', 'LeRoy', 100, 'all');
[LeRoy_competition_statistics] = histone_corr(model, metabolites, LeRoy_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'competitive_cfr', 'LeRoy', [], 'all');
[LeRoy_no_competition_statistics] = histone_corr(model, metabolites, LeRoy_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'non-competitive_cfr', 'LeRoy', [], 'all');

% Plot the heatmaps for LeRoy et al.,
plot_heatmap(LeRoy_fva_statistics, [], 'correlation', [], [], 'fva');
plot_heatmap(LeRoy_competition_statistics, [], 'correlation', [], [], 'comp');
plot_heatmap(LeRoy_no_competition_statistics, [], 'correlation', [], [], 'noComp');

plot_heatmap(LeRoy_fva_statistics, [], 'pval', [], [], 'fva');
plot_heatmap(LeRoy_competition_statistics, [], 'pval', [], [], 'comp');
plot_heatmap(LeRoy_no_competition_statistics, [], 'pval', [], [], 'noComp');

% CCLE proteomics dataset
[CCLE_fva_statistics] = histone_corr(model, metabolites, CCLE_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'fva', 'CCLE', 100, 'all');
[CCLE_competition_statistics] = histone_corr(model, metabolites, CCLE_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'competitive_cfr', 'CCLE', [], 'all');
[CCLE_no_competition_statistics] = histone_corr(model, metabolites, CCLE_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'non-competitive_cfr', 'CCLE', [], 'all');

% Plot the heatmaps for CCLE dataset
plot_heatmap(CCLE_fva_statistics, [], 'correlation', [], [], 'fva');
plot_heatmap(CCLE_competition_statistics, [], 'correlation', [], [], 'comp');
plot_heatmap(CCLE_no_competition_statistics, [], 'correlation', [], [], 'noComp');

plot_heatmap(CCLE_fva_statistics, [], 'pval', [], [], 'fva');
plot_heatmap(CCLE_competition_statistics, [], 'pval', [], [], 'comp');
plot_heatmap(CCLE_no_competition_statistics, [], 'pval', [], [], 'noComp');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Histone reactions only
% LeRoy et al., proteomics dataset
[LeRoy_histOnly_fva_statistics] = histone_corr(model, histone_rxns_only, LeRoy_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'fva', 'LeRoy', 100, 'hist');
[LeRoy_histOnly_competition_statistics] = histone_corr(model, histone_rxns_only, LeRoy_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'competitive_cfr', 'LeRoy', [], 'hist');
[LeRoy_histOnly_no_competition_statistics] = histone_corr(model, histone_rxns_only, LeRoy_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'non-competitive_cfr', 'LeRoy', [], 'hist');

% Plot the heatmaps for LeRoy et al.,
plot_heatmap(LeRoy_histOnly_fva_statistics, [], 'correlation', [], [], 'fva_histOnly');
plot_heatmap(LeRoy_histOnly_competition_statistics, [], 'correlation', [], [], 'comp_histOnly');
plot_heatmap(LeRoy_histOnly_no_competition_statistics, [], 'correlation', [], [], 'noComp_histOnly');

plot_heatmap(LeRoy_histOnly_fva_statistics, [], 'pval', [], [], 'fva');
plot_heatmap(LeRoy_histOnly_competition_statistics, [], 'pval', [], [], 'comp_histOnly');
plot_heatmap(LeRoy_histOnly_no_competition_statistics, [], 'pval', [], [], 'noComp_histOnly');

% CCLE proteomics dataset
[CCLE_histOnly_fva_statistics] = histone_corr(model, histone_rxns_only, CCLE_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'fva', 'CCLE', 100, 'hist');
[CCLE_histOnly_competition_statistics] = histone_corr(model, histone_rxns_only, CCLE_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'competitive_cfr', 'CCLE', [], 'hist');
[CCLE_histOnly_no_competition_statistics] = histone_corr(model, histone_rxns_only, CCLE_histOnly_epsilon, ...
    1, 1E-3, 1, 1E-3, 0, 'non-competitive_cfr', 'CCLE', [], 'hist');

% Plot the heatmaps for CCLE dataset
plot_heatmap(CCLE_histOnly_fva_statistics, [], 'correlation', [], [], 'fva_histOnly');
plot_heatmap(CCLE_histOnly_competition_statistics, [], 'correlation', [], [], 'comp_histOnly');
plot_heatmap(CCLE_histOnly_no_competition_statistics, [], 'correlation', [], [], 'noComp_histOnly');

plot_heatmap(CCLE_histOnly_fva_statistics, [], 'pval', [], [], 'fva_histOnly');
plot_heatmap(CCLE_histOnly_competition_statistics, [], 'pval', [], [], 'comp_histOnly');
plot_heatmap(CCLE_histOnly_no_competition_statistics, [], 'pval', [], [], 'noComp_histOnly');

%% Transform figures
path = './../figures/new-model/';
new_ext = '.tif';
old_ext = '.fig';
transform_fig(path, old_ext, new_ext)


%% Density plot
% A = densityplot('eGEMn');
% 
% [x,y,z] = meshgrid(1:50, 1:20, 1:6);
% for i=1:6
%     surf(x(:,1,1), y(1,:,1), A(:,:,i));
%     hold on;
%     colorbar
% end