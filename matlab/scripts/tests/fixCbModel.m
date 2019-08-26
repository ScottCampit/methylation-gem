% @author: Scott Campit
function fixedModel = fixCbModel(model)
    % 1. Set all demand reactions to have no backwards flux
    DMlb = find(model.lb(strmatch('DM_', model.rxns)) < 0);
    if ~isempty(DMlb)
        warning("Setting demand reactions to have 0 flux for backwards")
        for dm_rxn = 1:length(DMlb)
            model.lb(DMlb(dm_rxn)) = 0;
        end
    else
        disp("No demand reactions have backwards flux")
    end
    fixedModel = model;
end