% Exemple natif et reproductible, sans interface et sans outil externe.
D = pb_load(); cfg = pb_defaults(D);
r = pb_simulate(D, cfg);
disp(table(string(r.ids(:)), r.pct, 'VariableNames', {'Candidat', 'Score_pct'}));
figure('Color', 'white'); ax = axes; pb_drawmap(ax, D, r, false);
% Modifier les themes et le moteur :
cfg.themesEnabled = true; cfg.salience.soc = 45; cfg.options.beta = .8;
r2 = pb_simulate(D, cfg);
figure('Color', 'white'); pb_drawmap(axes, D, r2, false);
% Export : cree trois CSV (scores, origines, composition sociale).
% pb_export(r2,D,'scores_modifies.csv');
