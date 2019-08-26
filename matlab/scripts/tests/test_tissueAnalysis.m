git pinitCobraToolbox
changeCobraSolver('gurobi');

addpath('/home/scampit/Desktop/eGEM/matlab/scripts/metabolic_sensitivity/')
addpath('/home/scampit/Desktop/eGEM/matlab/scripts/visualizations')
%addpath('C:\home\scampit\Desktop\eGEM\matlab\scripts\metabolic_sensitivity\')
load ./../../metabolic_models/eGEM_mm.mat
load ./../../vars/ccle_geneExpression_vars.mat
load ./../../vars/CCLE_epsilon.mat
load ./../../vars/CCLE_Proteomics.mat

reactions_of_interest = {'DM_KAC'; 'DM_KMe1'; 'DM_KMe2'; 'DM_KMe3'};

model = eGEM_mm;
unique_tissues = unique(tissues);
BIOMASS_OBJ_POS = find(ismember(model.rxns, 'biomass_objective')); 
model.c(BIOMASS_OBJ_POS) = 1;

unique_tissues = unique_tissues(12:end, 1);

for tiss = 1:length(unique_tissues)
    tissue = unique_tissues(tiss);
    disp(tissue)
    
    tissue_positions = find(ismember(string(tissues), string(tissue)));
    tissue_proteomics = proteomics(tissue_positions, :);
    tissue_cellNames = cell_names(tissue_positions, :);
    tissue_medium = medium(tissue_positions, :);

    proteomics_CL_match_positions = find(ismember(string(tissue_cellNames), ...
        string(celllinenames_ccle1)));
    proteomics_CL_match = 

    tissue_matched_proteomics = tissue_proteomics(proteomics_CL_match_positions, :);
    tissue_matched_cellNames = tissue_cellNames(proteomics_CL_match_positions,1);
    geneExp_CL_match_positions = find(ismember(string(celllinenames_ccle1),...
        string(tissue_matched_cellNames)));
    geneExp_CL_match_cellNames = celllinenames_ccle1(geneExp_CL_match_positions);

    [diffExp_genes] = find_diffexp_genes(model, geneExp_CL_match_cellNames);

    for match = 1:length(proteomics_CL_match_positions)
        obj_coef = [1E-3, 1E-3, 1E-3, 1E-3];

        ON_fieldname = string(strcat('ON_', ...
            tissue_matched_cellNames(proteomics_CL_match_positions(match))));
        OFF_fieldname = string(strcat('OFF_', ...
            tissue_matched_cellNames(proteomics_CL_match_positions(match))));

        constrained_model = medium_LB_constraints(model, tissue_medium(match));

        reaction_name = char(reactions_of_interest(:, 1));
        reactions_to_optimize = [find(ismember(constrained_model.rxns,...
            reaction_name))];
        
        for rxn = 1:length(reactions_to_optimize)
            optimized_rxn = reactions_to_optimize(rxn);
            constrained_model.c(reactions_to_optimize) = obj_coef(rxn);

            kappa = 1;
            rho = 1;
            epsilon = 1E-3;
            mode = 0; 
            epsilon2 = 1E-3;
            minfluxflag = true;
            
            [cellLine_model, solution] =  constrain_flux_regulation...
               (constrained_model, diffExp_genes.(ON_fieldname), ...
                diffExp_genes.(OFF_fieldname), ...
                kappa, rho, epsilon, mode, [], minfluxflag);
            
            tissue_flux_values(match, rxn) = solution.flux(optimized_rxn);
            tissue_grates(match, rxn) = solution.flux(BIOMASS_OBJ_POS);
            constrained_model.c(reactions_to_optimize) = 0;
            
            tissue = string(tissue);
            tissue = strrep(tissue, ' ', '');
            fluxVarName = string(strcat(tissue, '_flux_values(match, rxn) = solution.flux(optimized_rxn);'));
            grateVarName = string(strcat(tissue, '_grates(match, rxn) = solution.x(BIOMASS_OBJ_POS);'));
            eval(fluxVarName);
            eval(grateVarName);
        end
    end
    
    corrVarName = string(strcat(tissue, '_corr = ', 'TissueCorr(', ...
        tissue, '_flux_values, tissue_matched_proteomics, tissue, marks)'));
    eval(corrVarName)
    
    plotVarName = string(strcat('plot_heatmap(', tissue, ...
        '_corr', ', [], "correlation", [], [], [])'));
    eval(plotVarName)
end


 