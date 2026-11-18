function cfg = pb_defaults(D)
%PB_DEFAULTS H11, themes off, as the reference engine (not arbitrary UI state).
if nargin == 0, D = pb_load(); end
cfg.active = pb_cells(D.scenario.h11);
cfg.options = D.scenario.options;
cfg.build = D.scenario.cfg;
cfg.weights = D.scenario.notoweights;
cfg.themesEnabled = false;
cfg.salience = D.themes.S_DEFAULT;
cfg.themeProfiles = D.themes.O_DEFAULT;
cfg.themeTheta = 1;
cfg.candidateOverrides = struct();
cfg.reservoirOverrides = struct();
cfg.mode = '2027';
end
