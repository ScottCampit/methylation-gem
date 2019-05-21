%% histone_corr calculates the correlation value between various histone markers and the metabolic flux obtained from the iMAT algorithm
function [correl, pval, cell_line_match] = histone_corr(model, compartment, mode, epsilon, epsilon2, rho, kappa, minfluxflag)
%% INPUTS:
    % model: Initial genome scale model
    % metabolite: The metabolite we're interested in creating a demand
    % reaction. If this argument is left empty, it will take the rxn
    % argument.
    % rxn: The rxn of interest that we are creating a demand reaction through.
    % compartment: specifying the compartment. 
    % mode: for constrain flux regulation
    % epsilon: for constrain flux regulation
    % rho: 
    % kappa:
    % minfluxflag:
%% OUTPUTS:
    % histogram plotting the correlation value (x-axis) corresponding
    % to each histone marker (y-axis) for the demand reaction of
    % interest.
%% histone_corr
load supplementary_software_code celllinenames_ccle1 ccleids_met ccle_expression_metz % contains CCLE cellline names for gene exp, enzymes encoding specific metabolites, and gene expression data (z-transformed)

% New variables
path = './../new_var/';
vars = {...
    [path 'h3_ccle_names.mat'], [path 'h3_marks.mat'],...
    [path 'h3_media.mat'], [path 'h3_relval.mat']...
    }; % contains CCLE cellline names for H3 proteomics, corresponding marker ids, growth media, relative H3 proteomics
for kk = 1:numel(vars)
    load(vars{kk})
end

% impute missing values using KNN. Maybe try other functions if the results
% look like shit. 
h3_relvals = knnimpute(h3_relval);

% old variables but slightly modified
path = './../vars/';
vars = {[path 'metabolites.mat']};
for kk = 1:numel(vars)
    load(vars{kk})
end

idx = find(ismember(celllinenames_ccle1, h3_ccle_names));
tmp = length(idx);

for i = 1:tmp
    model2 = model;

    % Takes in genes that are differentially expression from Z-score
    % scale
    ongenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) >= 2));
    offgenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) <= -2));
    
    % Keep the genes that match with the metabolic model.
    ongenes = intersect(ongenes, model2.rxns);
    offgenes = intersect(offgenes, model2.rxns);
    
    %medium = string(h3_media(i,1));
    % set medium conditions unique to each cell line
    model2 = media(model2, h3_media(i));
    disp(i)
    % Get the reactions corresponding to on- and off-genes
    [~,~,onreactions,~] =  deleteModelGenes(model2, ongenes);
    [~,~,offreactions,~] =  deleteModelGenes(model2, offgenes);

    % Get the flux redistribution values associated with different media component addition and deletion
    [fluxstate_gurobi, grate_ccle_exp_dat(i,1), solverobj_ccle(i,1)] =...
        constrain_flux_regulation(model2, onreactions, offreactions,...
        kappa, rho, epsilon, mode, [], minfluxflag);

    % Add demand reactions from the metabolite list to the metabolic model
    for m = 1:length(metabolites(:,1))
        %tmp_met = char(metabolites(m,2));
        %tmp = [tmp_met '[' compartment '] -> '];
        tmpname = char(metabolites(m,1));
        %model3 = addReaction(model, tmpname, 'reactionFormula', tmp);
        

        % limit methionine levels for all reactions in the model; it has to be non limiting
        model3 = model2;
        [ix, pos]  = ismember({'EX_met_L(e)'}, model3.rxns);
        model3.lb(pos) = -0.5;
        %model3.c(3743) = 0;
        rxnpos = [find(ismember(model3.rxns, tmpname))];
        model3.c(rxnpos) = epsilon2; 

        % get the flux values from iMAT
        [fluxstate_gurobi] =  constrain_flux_regulation(model3,...
            onreactions, offreactions, kappa, rho, epsilon, mode ,[],...
            minfluxflag);
        grate_ccle_exp_dat(i,1+m) = fluxstate_gurobi(rxnpos);
        model3.c(rxnpos) = 0; 
    end
end

% Calculate the pearson correlation coefficients for every demand reaction
[~, col] = size(grate_ccle_exp_dat);
for j = 1:length(col)
    [correl, pval] = corr(grate_ccle_exp_dat(:,j),...
        h3_relvals);  
end
correl = correl';

% Make a heatmap of correlation coefficients versus histone markers for
% several demand reactions
rxns = metabolites(:,1);


fig = figure;
heatmap(correl)
ax = gca;
ax.XData = h3_marks;
ax.YData = ;
ax.Title = 'Histone markers and metabolic flux correlation'
xlabel(ax, 'Histone Markers');
ylabel(ax, 'Cancer Cell Lines (CCLE)'
saveas(fig, ['./../figures/fig/histone_mark_corr.fig']);
end 