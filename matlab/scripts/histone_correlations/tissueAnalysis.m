function [solution] = tissueAnalysis(exp)
    %addpath('C:\Users\scampit\Desktop\egem\matlab\scripts\metabolic_sensitivity')
    %addpath('C:\Users\scampit\Desktop\egem\matlab\scripts\visualizations')
    
    addpath('/home/scampit/Desktop/egem/matlab/scripts/nutrient_sensitivity')
    addpath('/home/scampit/Desktop/egem/matlab/scripts/visualizations')
    
    load ./../../metabolic_models/eGEM_mm.mat
    load ./../../vars/ccle_geneExpression_vars.mat
    load ./../../vars/CCLE_Proteomics
    load allVars.mat

    reactions_of_interest = {'DM_KAC'; 'DM_KMe1'; 'DM_KMe2'; 'DM_KMe3'};

    model = eGEM_mm;
    unique_tissues = unique(tissues);
    BIOMASS_OBJ_POS = find(ismember(model.rxns, 'biomass_objective')); 
    model.c(BIOMASS_OBJ_POS) = 1;
    unique_tissues = unique_tissues(8:end, 1);

    for tiss = 1:length(unique_tissues)
        oneTissue = unique_tissues(tiss);
        disp(oneTissue)

        tissuePositions = find(ismember(string(tissues), string(oneTissue)));
        tissueCellNames = cell_names(tissuePositions, :);

        tissueToGeneMatch = find(ismember(string(celllinenames_ccle1), ...
            string(tissueCellNames)));
        geneExpMatch = celllinenames_ccle1(tissueToGeneMatch);

        matched = intersect(string(tissueCellNames), string(geneExpMatch));
        matchedTissue = find(ismember(string(cell_names), string(matched)));
        matchedGenes = find(ismember(string(celllinenames_ccle1), string(matched)));
        tissueCellNames = cell_names(matchedTissue, :);
        geneExpMatch = celllinenames_ccle1(matchedGenes);

        tissueProteomicsValues = proteomics(matchedTissue, :);
        tissueMedium = medium(matchedTissue, :);

        [diffExp_genes] = find_diffexp_genes(model, geneExpMatch);

        for match = 1:length(tissueCellNames)

            ON_fieldname = string(strcat('ON_', geneExpMatch(match)));
            OFF_fieldname = string(strcat('OFF_', geneExpMatch(match)));
            str = strcat(string("ObjCoef = epsilon2_"), string(lower(tissueMedium(match))), string("(:, 1)"));
            eval(str);            
            
            constrained_model = medium_LB_constraints(model, tissueMedium(match));

            reaction_name = char(reactions_of_interest(:, 1));
            reactions_to_optimize = [find(ismember(constrained_model.rxns,...
                reaction_name))];
            constrained_model.c(reactions_to_optimize) = 0;
            
            tissue = string(oneTissue);
            tissue = strrep(tissue, ' ', '');
            
            kappa = 1;
            rho = 1;
            epsilon = 1E-3;
            mode = 0; 
            epsilon2 = 1E-3;
            minfluxflag = true;
            
            switch exp
                case {'SRA', 'NoComp'}

                    BIOMASS_OBJ_POS = find(ismember(constrained_model.rxns, 'biomass_objective')); 
                    constrained_model.c(BIOMASS_OBJ_POS) = 1;

                    for rxn = 1:length(reactions_to_optimize)
                        optimized_rxn = reactions_to_optimize(rxn);
                        constrained_model.c(reactions_to_optimize) = ObjCoef(rxn);

                        [~, solution] =  constrain_flux_regulation...
                           (constrained_model, diffExp_genes.(ON_fieldname), ...
                            diffExp_genes.(OFF_fieldname), ...
                            kappa, rho, epsilon, mode, [], minfluxflag);
                        
                        fluxVarName = string(strcat(tissue, '_flux_values(match, rxn) = solution.flux(optimized_rxn);'));
                        grateVarName = string(strcat(tissue, '_grates(match, rxn) = solution.x(BIOMASS_OBJ_POS);'));
                        eval(fluxVarName);
                        eval(grateVarName);
                        constrained_model.c(reactions_to_optimize) = 0;
                        
                    end
                    
                case 'Comp'
                    BIOMASS_OBJ_POS = find(ismember(constrained_model.rxns, 'biomass_objective')); 
                    model.c(BIOMASS_OBJ_POS) = 1;

                    %reaction_positions = find(ismember(model.rxns, reactions_to_optimize));
                    constrained_model.c(reactions_to_optimize) = ObjCoef;

                    [~, solution] =  constrain_flux_regulation...
                           (constrained_model, diffExp_genes.(ON_fieldname), ...
                            diffExp_genes.(OFF_fieldname), ...
                            kappa, rho, epsilon, mode, [], minfluxflag);

                    fluxVarName = string(strcat(tissue, '_flux_values(match, :) = solution.flux(reactions_to_optimize);'));
                    grateVarName = string(strcat(tissue, '_grates(match, 1) = solution.x(BIOMASS_OBJ_POS);'));
                    eval(fluxVarName);
                    eval(grateVarName);
                    
                case 'FVA'
                    BIOMASS_OBJ_POS = find(ismember(constrained_model.rxns, 'biomass_objective')); 
                    constrained_model.c(BIOMASS_OBJ_POS) = 1;
                    %reaction_positions = find(ismember(model.rxns, reactions_to_optimize));
                    model.c(reactions_to_optimize) = ObjCoef;
                    [~, maxFlux] = fluxVariability(constrained_model, 100, ...
                            'max', reactions_of_interest);
                    fluxVarName = string(strcat(tissue, '_flux_values(match, :) = maxFlux;'));
                    eval(fluxVarName);                    
                    
            end
        end

        corrVarName = string(strcat(tissue, '_corr = ', 'TissueCorr(', ...
           tissue, '_flux_values, tissueProteomicsValues, tissue, marks)'));
        eval(corrVarName)

        plotVarName = string(strcat('plotHistoneCorrelation(', tissue, ...
           '_corr, "correlation", exp, "tissue_corr")'));
        eval(plotVarName)
        
        histVarName = string(strcat("makeHist(", tissue, ...
            "_flux_values, string(oneTissue), 'tissue_hist', exp)"));
        eval(histVarName)
    end
end

 