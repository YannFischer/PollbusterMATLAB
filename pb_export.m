function pb_export(result, D, filename)
%PB_EXPORT Scores, exact reservoir contributions and social votes as CSV files.
n = numel(result.ids); Id = result.ids(:); Candidat = cell(n, 1); Couleur = cell(n, 1); Zone = cell(n, 1);
for j = 1:n, Candidat{j} = pb_get(D.names, Id{j}, Id{j}); Zone{j} = result.candidates{j}.zone; Couleur{j} = D.colors.(Zone{j}); end
Voix = result.T; Score_pct = result.pct; X = result.coordinates(:, 1); Y = result.coordinates(:, 2);
T = table(Id, Candidat, Zone, Couleur, Voix, Score_pct, X, Y); writetable(T, filename, 'Encoding', 'UTF-8');
[p, f] = fileparts(filename); nr = numel(result.reservoirs); Reservoir = cell(n * nr, 1); Candidat = cell(n * nr, 1); Voix = zeros(n * nr, 1); k = 0;
for r = 1:nr, for j = 1:n, k = k + 1; Reservoir{k} = result.reservoirs{r}.id; Candidat{k} = Id{j}; Voix(k) = result.sources(r, j); end, end
writetable(table(Reservoir, Candidat, Voix), fullfile(p, [f '_origines.csv']), 'Encoding', 'UTF-8');
T = array2table(result.V, 'VariableNames', {D.core.pcs.id}); T = addvars(T, Id, 'Before', 1); writetable(T, fullfile(p, [f '_social.csv']), 'Encoding', 'UTF-8');
end
