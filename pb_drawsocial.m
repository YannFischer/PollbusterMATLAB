function handles = pb_drawsocial(ax, D, result, positions, sizeScale)
    %PB_DRAWSOCIAL Reperes PCS colores dans le referentiel social du moteur.
    % positions : N x 2, memes lignes que D.core.pcs et colonnes que result.V.
    % Les parts representent les suffrages exprimes simules, pas la population.
    % Utiliser la meme echelle de surface que pour les candidats.
    % Le placement des noms est simple ; il ne garantit pas l'absence de conflits.

    if nargin < 5
        sizeScale = 55;
    end

    categoryCount = numel(D.core.pcs);
    assert(isequal(size(positions), [categoryCount 2]), ...
        'Pollbuster:SocialPositions', 'positions doit etre une matrice N x 2.');
    assert(size(result.V, 2) == categoryCount, ...
        'Pollbuster:SocialVotes', 'Les colonnes de V doivent correspondre aux PCS.');
    assert(isscalar(sizeScale) && isfinite(sizeScale) && sizeScale > 0, ...
        'Pollbuster:SocialScale', 'Echelle de surface positive attendue.');

    votes = sum(result.V, 1);
    assert(all(isfinite(votes)) && all(votes >= 0) && sum(votes) > 0, ...
        'Pollbuster:SocialVotes', 'Volumes de voix invalides.');
    shares = 100 * votes / sum(votes);

    previousHold = ishold(ax);
    hold(ax, 'on');
    cleanup = onCleanup(@() restoreHold(ax, previousHold));

    handles = struct();
    handles.bubbles = gobjects(categoryCount, 1);
    handles.labels = gobjects(categoryCount, 1);
    handles.shares = shares;
    offsets = zeros(categoryCount, 2);
    alignments = cell(categoryCount, 1);

    % Dessiner les grands cercles d'abord, puis les petits.
    [~, order] = sort(shares, 'descend');

    for index = order(:)'

        if any(~isfinite(positions(index, :)))
            continue
        end

        id = D.core.pcs(index).id;
        [name, color, side] = categoryStyle(id, D.core.pcs(index).label);
        point = positions(index, :);
        markerSize = max(1, sizeScale * shares(index));

        handles.bubbles(index) = scatter(ax, point(1), point(2), ...
            markerSize, color, 'filled', 'MarkerEdgeColor', color, ...
            'MarkerFaceAlpha', 0.16, 'LineWidth', 1.2);
        handles.labels(index) = text(ax, point(1), point(2), ...
            sprintf('%s %.0f %%', name, shares(index)), ...
            'FontSize', 9, 'Color', color, 'Interpreter', 'none', ...
            'VerticalAlignment', 'middle', 'Clipping', 'on');

        if side > 0
            alignments{index} = 'left';
        else
            alignments{index} = 'right';
        end

        % Marge graphique indicative, en pixels.
        dpi = get(groot, 'ScreenPixelsPerInch');
        offsets(index, :) = [side * (0.60 * sqrt(markerSize) * dpi / 72 + 6), 0];
    end

    % Decaler les etiquettes sans modifier les positions sociales.
    drawnow;

    for index = 1:categoryCount

        if ~isgraphics(handles.labels(index))
            continue
        end

        label = handles.labels(index);
        set(label, 'Units', 'pixels');
        pixelPosition = get(label, 'Position');
        pixelPosition(1:2) = pixelPosition(1:2) + offsets(index, :);
        set(label, 'Position', pixelPosition, ...
            'HorizontalAlignment', alignments{index});
        set(label, 'Units', 'data');
    end

end

function [name, color, side] = categoryStyle(id, fallback)
    side = -1;

    switch id
        case 'cad'
            name = 'Cadres';
            color = [0.10 0.27 0.95];
        case 'PI'
            name = 'Professions intermediaires';
            color = [0.00 0.65 0.85];
        case 'ret'
            name = 'Retraites';
            color = [0.44 0.46 0.52];
        case 'emp'
            name = 'Employes';
            color = [0.95 0.59 0.00];
        case 'ouv'
            name = 'Ouvriers';
            color = [0.88 0.24 0.02];
        case 'inact'
            name = 'Inactifs';
            color = [0.96 0.13 0.51];
        case 'agri'
            name = 'Agriculteurs, artisans, commercants';
            color = [0.39 0.65 0.02];
            side = 1;
        otherwise
            name = fallback;
            color = [0.40 0.40 0.40];
    end

end

function restoreHold(ax, previousHold)

    if isgraphics(ax) && ~previousHold
        hold(ax, 'off');
    end

end
