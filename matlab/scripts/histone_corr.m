%% histone_corr calculates the correlation value between various histone 
...markers and the metabolic flux obtained from the iMAT algorithm
function [rho, pval] = histone_corr(model, dat, compartment, media, mode,...
epsilon, epsilon2, rho, kappa, minfluxflag)

%% INPUTS:
    % model: Initial genome scale model
    % compartment: Subcellular compartment of interest
    % mode: for constrain flux regulation
    % epsilon: for constrain flux regulation
    % epsilon2: obj coef weight for reaction of interest
    % rho: for constrain flux regulation
    % kappa: for constrain flux regulation
    % minfluxflag: for parsimonious flux balance analysis
%% OUTPUTS:
    % correl: correlation values associated with each histone marker/rxn 
    % pval: the p-value associated with correl
    % cell_line_match: cell lines that matched between gene expression and
    % proteomics
    % heatmap that visualizes the correlation values

%% histone_corr
load ./../vars/supplementary_software_code...
    celllinenames_ccle1... % CCLE cellline names
    ccleids_met... % Gene symbols
    ccle_expression_metz % Z-transformed gene expression

% New variables
path1 = './../new_var/';
path2 = './../vars/';
vars = {...
    [path1 'h3_ccle_names.mat'],... % CCLE cellline names for H3 proteomics, 
    [path1 'h3_marks.mat'],... % H3 marker IDs
    [path1 'h3_media.mat'],... % H3 growth media
    [path1 'h3_relval.mat'],...% H3 proteomics data, Z-transformed
    [path2 'metabolites.mat'] % Map of demand rxns, metabolite and descriptor
    }; 

for kk = 1:numel(vars) 
    load(vars{kk})
end

% Default dataset is from CCLE data
if (~exist('dat', 'var')) || (isempty('dat'))
    dat = h3_relval;
end

% impute missing values using KNN and scale from [0,1]
h3_relval = knnimpute(h3_relval);
h3_relval = normalize(h3_relval, 'range');

% Match data from gene expression and histone proteomics to get proteomics
% data that will be used downstream
idx = find(ismember(h3_ccle_names, celllinenames_ccle1));
tmp = length(idx);
h3_relval = h3_relval(idx, :);
h3_ccle_names = h3_ccle_names(idx,1);

% Change idx to map to gene expression array and iterate for all 885 cancer
% cell lines that match between genexp and proteomics dataset
idx = find(ismember(celllinenames_ccle1, h3_ccle_names));
for i = 1:tmp
    model2 = model;
    
    % Takes in genes that are differentially expressed from Z-score scale
    % and that are in metabolic model
    ongenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) >= 2));
    offgenes = unique(ccleids_met(ccle_expression_metz(:,idx(i)) <= -2));
    ongenes = intersect(ongenes, model2.rxns);
    offgenes = intersect(offgenes, model2.rxns);
    
    % set medium conditions unique to each cell line
    model2 = media(model2, media);
    
    % Get the reactions corresponding to on- and off-genes
    [~,~,onreactions,~] =  deleteModelGenes(model2, ongenes);
    [~,~,offreactions,~] =  deleteModelGenes(model2, offgenes);

    % Get the WT growth rate associated with different media components
    [~, grate_ccle_exp_dat(i,1), ~] =...
     constrain_flux_regulation(model2, onreactions, offreactions,...
     kappa, rho, epsilon, mode, [], minfluxflag);
        
    % Make methionine levels non-limiting in the metabolic model
    model3 = model2;
    [ix, pos]  = ismember({'EX_met_L(e)'}, model3.rxns);
    model3.lb(pos) = -0.5;
    
    % Get the demand reaction positions of interest and calculate metabolic
    % flux for each cell line using the iMAT algorithm
    rxnname = char(metabolites(:, 1)); 
    rxnpos = [find(ismember(model3.rxns, rxnname))];
    model3.c(rxnpos) = epsilon2(:, 1); 
    
    [fluxstate_gurobi, ~, ~] =  constrain_flux_regulation(model3,...
        onreactions, offreactions, kappa, rho, epsilon, mode ,[],...
        minfluxflag);
    
    % Concatenate onto the growth rate array
    grate_ccle_exp_dat(:,i) = fluxstate_gurobi(rxnpos);
end

% Calculate the pearson correlation coefficients for every demand reaction
% w.r.t to H3 expression
grate_ccle_exp_dat = grate_ccle_exp_dat';
[rho, pval] = corr(grate_ccle_exp_dat, h3_relval);
rxns = metabolites(:,3);

%% I created this section, because it's before the printing of numbers 2-885
    % Add demand reactions from the metabolite list to the metabolic model
    for m = 1:length(metabolites(:,1))  
        %tmp_met = char(metabolites(m,2));
        %tmp = [tmp_met '[' compartment '] -> '];
        tmpname = char(metabolites(m,1));
        
        % limit methionine levels for all reactions in the model; it has to be non limiting
        model3 = model2;
        [~, pos]  = ismember({'EX_met_L(e)'}, model3.rxns);
        model3.lb(pos) = -0.5;
        model3.c(find(ismember(model.rxns, 'biomass_objective'))) = 1;
        rxnpos = find(ismember(model3.rxns, tmpname));
        
        % LF created an if-branch
        if rxnpos ~= []
            model3.c(rxnpos) = epsilon2;
            
            % get the flux values from iMAT
            [fluxstate_gurobi] =  constrain_flux_regulation(model3,...
                onreactions, offreactions, kappa, rho, epsilon, mode ,[],...
                minfluxflag);
            grate_ccle_exp_dat(i,1+m) = fluxstate_gurobi(rxnpos);
            model3.c(rxnpos) = 0;
        end
% =======
%         rxnpos = [find(ismember(model3.rxns, tmpname))];
%         model3.c(rxnpos) = epsilon2; 
% 
%         % get the flux values from iMAT
%         [fluxstate_gurobi] =  constrain_flux_regulation(model3,...
%             onreactions, offreactions, kappa, rho, epsilon, mode ,[],...
%             minfluxflag);
%         grate_ccle_exp_dat(i,1+m) = fluxstate_gurobi(rxnpos);
%         model3.c(rxnpos) = 0; 
% >>>>>>> 5c15a54a070a7bdf1d569795eb445600f9381482
    end
end

% Calculate the pearson correlation coefficients for every demand reaction
[row, col] = size(grate_ccle_exp_dat);

test = interp1(1:numel(grate_ccle_exp_dat), grate_ccle_exp_dat,...
    linspace(1, numel(grate_ccle_exp_dat), numel(h3_relval)));
% LF: For each gene, calculate correl & pval across all cell lines
for i = 1:length(h3_relval(:,1))
    [correl, pval] = corr(grate_ccle_exp_dat(i,:), h3_relval(i,:));
end
% LF: For each cell line, calculate correl and pval between flux data and
% expression level for all genes?

%% I created this section. (I did not write new code)
c=zeros(length(h3_ccle_names), size(h3_relval,2));
for i = 1:length(h3_ccle_names)
    tmp1 = grate_ccle_exp_dat(i,:);
    tmp2 = h3_relval(i,:);
    [correl, pval] = corr(tmp1, tmp2);
    c(i,:)=correl;
    %tmp3 = diag(correl);        % Why? What used for?
end

% Make a heatmap of correlation coefficients versus histone markers for
% several demand reactions
rxns = metabolites(:,1);

%% Make Figures
fig = figure;
heatmap(correl)
ax = gca;
ax.Colormap = parula;
ax.Title = 'Histone markers and metabolic flux correlation';
ax.XData = h3_marks;
ax.YData = rxns;
xlabel(ax, 'Histone Markers');
ylabel(ax, 'Demand Reactions');
base = strcat('./../figures/corr/histone_mark_corr_', string(epsilon2)); 
fig_str = strcat(base, '.fig');
%saveas(fig, fig_str);
end 