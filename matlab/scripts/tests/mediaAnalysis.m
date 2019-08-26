%initCobraToolbox
%changeCobraSolver('gurobi');
function mediaAnalysis()
%addpath('/home/scampit/Desktop/eGEM/matlab/scripts/metabolic_sensitivity/')
addpath('C:\Users\scampit\Desktop\egem\matlab\scripts\metabolic_sensitivity')

%addpath('/home/scampit/Desktop/eGEM/matlab/scripts/visualizations')
addpath('C:\Users\scampit\Desktop\egem\matlab\scripts\visualizations')
addpath('C:\Users\scampit\Desktop\eGEM\matlab\scripts\metabolic_sensitivity')
load ./../../metabolic_models/eGEM_mm.mat
load ./../../vars/ccle_geneExpression_vars.mat
load ./../../vars/CCLE_Proteomics

reactions_of_interest = {'DM_KAC'; 'DM_KMe1'; 'DM_KMe2'; 'DM_KMe3'};
[~, mediaList] = xlsfinfo('./../../../data/Medium_Component_Maps/final_medium2.xlsx');
model = eGEM_mm;
BIOMASS_OBJ_POS = find(ismember(model.rxns, 'biomass_objective')); 
model.c(BIOMASS_OBJ_POS) = 1;
unique_medium = unique(medium);
mediaList = intersect(string(unique_medium), string(mediaList));

for med = 1:length(mediaList)
    disp(mediaList(med))
    medium = strtrim(medium);
    mediaPositions = find(ismember(string(medium), string(mediaList(med))));
    mediaCellNames = cell_names(mediaPositions, :);
    
    mediaToGeneMatch = find(ismember(string(celllinenames_ccle1), ...
        string(mediaCellNames)));
    geneExpMatch = celllinenames_ccle1(mediaToGeneMatch);
    
    matched = intersect(string(mediaCellNames), string(geneExpMatch));
    matchedMedia = find(ismember(string(cell_names), string(matched)));
    matchedGenes = find(ismember(string(celllinenames_ccle1), string(matched)));
    mediaCellNames = cell_names(matchedMedia, :);
    geneExpMatch = celllinenames_ccle1(matchedGenes);
    
    mediaProteomicsValues = proteomics(matchedMedia, :);
    
    [diffExp_genes] = find_diffexp_genes(model, geneExpMatch);

    for match = 1:length(mediaCellNames)
        obj_coef = [1E-3, 1E-3, 1E-3, 1E-3];

        ON_fieldname = string(strcat('ON_', geneExpMatch(match)));
        OFF_fieldname = string(strcat('OFF_', geneExpMatch(match)));

        constrained_model = medium_LB_constraints(model, mediaList(med));

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
            
            medium_flux_values(match, rxn) = solution.flux(optimized_rxn);
            medium_grates(match, rxn) = solution.flux(BIOMASS_OBJ_POS);
            constrained_model.c(reactions_to_optimize) = 0;
            final_medium = string(mediaList(med));
            final_medium = strrep(final_medium, '-', '');
            final_medium = strrep(final_medium, ' ', '');
            fluxVarName = string(strcat(final_medium, '_flux_values(match, rxn) = solution.flux(optimized_rxn);'));
            grateVarName = string(strcat(final_medium, '_grates(match, rxn) = solution.x(BIOMASS_OBJ_POS);'));
            eval(fluxVarName);
            eval(grateVarName);
        end
    end
    
    corrVarName = string(strcat(final_medium, '_corr = ', 'MediumCorr(', ...
        final_medium, '_flux_values, mediaProteomicsValues, mediaList(med), marks)'));
    eval(corrVarName)
    
    plotVarName = string(strcat('plot_heatmap(', final_medium, ...
        '_corr', ', [], "correlation", [], [], [])'));
    eval(plotVarName)
end

 