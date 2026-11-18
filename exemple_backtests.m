% Backtests natifs sur les entrees historiques fournies avec le projet.
% Le moteur est execute ici en MATLAB ; les scores ne sont pas simplement lus.
D = pb_load(); here = fileparts(mfilename('fullpath'));
cases = pb_cells(jsondecode(fileread(fullfile(here, 'data', 'references.json'))));

for k = 1:numel(cases)
    c = cases{k}; if ~startsWith(c.name, 'Backtest'), continue, end
    r = pb_engine(D, c.input.reservoirs, c.input.candidates, c.input.options);
    actual = zeros(numel(r.ids), 1);
    for j = 1:numel(r.ids), actual(j) = c.real.(r.ids{j}); end
    disp(c.name); disp(table(string(r.ids(:)), r.pct, actual, r.pct - actual, 'VariableNames', {'Candidat', 'Simulation', 'Reference', 'Ecart_points'}));
    figure('Name', c.name); pb_drawmap(axes, D, r, false);
end
