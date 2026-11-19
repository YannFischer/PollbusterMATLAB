function scene = pb_drawmap(ax, D, result, showPCS, options)
    %PB_DRAWMAP Carte inspiree du code PollBuster fourni, grille a sept PCS.
    % Signature historique conservee. Le cinquieme argument est optionnel.
    % Les donnees du moteur restent intactes. Pas d'appel a pb_drawsocial.
    % Le canevas utilise des unites graphiques : les disques restent ronds.

    if nargin < 4
        showPCS = false;
    end

    if nargin < 5
        options = struct();
    end

    % Adapter les proportions du canevas a la place disponible.
    % Une hauteur explicite dans options reste prioritaire.
    if ~isfield(options, 'height')
        axesBox = getpixelposition(ax, true);

        if axesBox(3) > 1 && axesBox(4) > 1

            if ~isfield(options, 'width')
                options.width = 1300;
            end

            availableRatio = axesBox(4) / axesBox(3);

            options.height = max( ...
                250, ...
                options.width * availableRatio);
        end

    end

    scene = pb_mapscene(D, result, options);
    width = scene.options.width;
    height = scene.options.height;
    projection = makeProjection(scene, width, height);

    cla(ax);
    hold(ax, 'on');
    cleanup = onCleanup(@() releaseAxes(ax));
    set(ax, 'Color', [0.99 0.99 0.98], 'YDir', 'reverse', ...
        'XLim', [0 width], 'YLim', [0 height], 'XTick', [], 'YTick', [], ...
        'Box', 'off', 'Visible', 'off', 'DataAspectRatio', [1 1 1], ...
        'DataAspectRatioMode', 'manual', 'PlotBoxAspectRatioMode', 'auto');
    title(ax, ''); xlabel(ax, ''); ylabel(ax, '');
    drawBackground(ax, width, height);
    labelBoxes = drawZones(ax, scene, projection);
    drawAxes(ax, scene, projection);

    if showPCS
        labelBoxes = drawSocialGroups(ax, scene, projection, labelBoxes);
    end

    drawCandidates(ax, scene, projection, logical(showPCS), labelBoxes);
    setappdata(ax, 'PollbusterMapScene', scene);
end

function projection = makeProjection(scene, width, height)
    % Le site inclut les reperes sociaux dans le cadrage meme masques.
    points = [scene.candidatePositions; scene.zonePositions; scene.pcsPositions];
    points = points(all(isfinite(points), 2), :);
    lower = min(points, [], 1);
    upper = max(points, [], 1);
    span = max(upper - lower);
    padding = 0;
    if span > 4, padding = 0.09 * span; end
    lower = floor((lower - [0.12 0.30] - padding) * 10) / 10;
    upper = ceil((upper + [0.22 + 1.6 * padding, 0.34 + padding]) * 10) / 10;
    projection.lower = lower;
    projection.upper = upper;
    projection.scale = [width - 34, height - 34] ./ (upper - lower);
    projection.width = width;
    projection.height = height;
end

function pixel = project(points, projection)
    pixel = (points - projection.lower) .* projection.scale + [20 14];
    pixel(:, 2) = projection.height - 20 ...
        - (points(:, 2) - projection.lower(2)) * projection.scale(2);
end

function drawBackground(ax, width, height)
    patch(ax, [0 width width 0], [0 0 height height], [0.99 0.99 0.98], ...
        'EdgeColor', 'none', 'HitTest', 'off');
    [gridX, gridY] = meshgrid(29:18:width - 14, 23:18:height - 20);
    plot(ax, gridX(:), gridY(:), '.', 'Color', [0.77 0.78 0.75], ...
        'MarkerSize', 3, 'HitTest', 'off');
end

function boxes = drawZones(ax, scene, projection)
    points = project(scene.zonePositions, projection);
    radius = 46 * projection.width / 900;

    for index = 1:size(points, 1)
        disk(ax, points(index, :), radius, scene.zoneColors(index, :), 0.08, false);
    end

    boxes = zeros(0, 4);

    for index = 1:size(points, 1)
        anchor = points(index, :) + [0 radius + 12];

        if anchor(2) > projection.height - 10
            anchor(2) = points(index, 2) - radius - 12;
        end

        label = putText(ax, anchor, scene.zoneNames{index}, [0.22 0.22 0.21], 16, 'center');
        boxes(end + 1, :) = get(label, 'Extent'); %#ok<AGROW>
    end

end

function drawAxes(ax, scene, projection)
    point = project(scene.barycentre, projection);
    width = projection.width;
    height = projection.height;
    % Comme dans le site, garder les legendes visibles si le barycentre sort du cadre.
    if point(1) < 80 || point(1) > width - 74, point(1) = (20 + width - 14) / 2; end
    if point(2) < 44 || point(2) > height - 50, point(2) = (14 + height - 20) / 2; end
    line(ax, [20 width - 14], [point(2) point(2)], 'Color', [0.60 0.61 0.58]);
    line(ax, [point(1) point(1)], [14 height - 20], 'Color', [0.60 0.61 0.58]);
    disk(ax, point, 3, [0.15 0.15 0.15], 1, false);
    putText(ax, [26 point(2) - 10], 'travail', [0.28 0.28 0.26], 18, 'left');
    putText(ax, [width - 20 point(2) - 10], 'capital', [0.28 0.28 0.26], 18, 'right');
    putText(ax, [point(1) + 8 22], 'direction', [0.28 0.28 0.26], 18, 'left');
    putText(ax, [point(1) + 8 height - 28], 'subordination', [0.28 0.28 0.26], 18, 'left');
    putText(ax, [point(1) + 8 46], 'Grille electorale', [0.35 0.35 0.33], 18, 'left');
end

function boxes = drawSocialGroups(ax, scene, projection, boxes)
    points = project(scene.pcsPositions, projection);

    for index = 1:7
        share = scene.pcsShares(index);
        radius = max(9, (5 + sqrt(max(0, 1.3 * share)) * 3.2) * projection.width / 900);
        color = scene.pcsColors(index, :);
        disk(ax, points(index, :), radius, color, 0.16, true);
        labelText = sprintf('%s %.0f %%', scene.pcsNames{index}, share);
        [~, box] = placeLabel(ax, points(index, :), radius, labelText, color, ...
            boxes, projection, -1);
        boxes(end + 1, :) = box; %#ok<AGROW>
    end

end

function drawCandidates(ax, scene, projection, showPCS, boxes)
    points = project(scene.candidatePositions, projection);
    factor = projection.width / 900;
    radii = max(7, (5 + sqrt(max(0, scene.scores)) * 3.2) * factor);
    [~, order] = sort(scene.scores, 'descend');

    for index = order(:)'
        if any(~isfinite(points(index, :))), continue; end
        disk(ax, points(index, :), radii(index), scene.candidateColors(index, :), 1, true);

        if showPCS && scene.options.rings
            drawCompositionRing(ax, points(index, :), radii(index) + 2, ...
                radii(index) + 7 * factor, scene.compositions(index, :), scene.pcsColors);
        end

    end

    % Reserver aussi l'espace occupe par les bulles.
    valid = all(isfinite(points), 2);
    margin = radii + 7 * factor;
    circleBoxes = [points(valid, :) - margin(valid), 2 * margin(valid), 2 * margin(valid)];
    boxes = [boxes; circleBoxes];

    for index = order(:)'
        if any(~isfinite(points(index, :))), continue; end
        labelText = sprintf('%s %s', scene.candidateNames{index}, ...
            strrep(sprintf('%.1f', scene.scores(index)), '.', ','));
        [~, box] = placeLabel(ax, points(index, :), margin(index), labelText, ...
            [0.10 0.10 0.10], boxes, projection, 1);
        boxes(end + 1, :) = box; %#ok<AGROW>
    end

end

function drawCompositionRing(ax, center, innerRadius, outerRadius, shares, colors)
    startAngle = -pi / 2;

    for index = 1:numel(shares)
        if shares(index) <= 0, continue; end
        finishAngle = startAngle + 2 * pi * shares(index);
        angle = linspace(startAngle, finishAngle, max(3, ceil(shares(index) * 180)));
        x = center(1) + [outerRadius * cos(angle), innerRadius * cos(fliplr(angle))];
        y = center(2) + [outerRadius * sin(angle), innerRadius * sin(fliplr(angle))];
        patch(ax, x, y, colors(index, :), 'EdgeColor', 'none', 'HitTest', 'off');
        startAngle = finishAngle;
    end

end

function disk(ax, center, radius, color, alpha, outlined)
    angle = linspace(0, 2 * pi, 100);
    edge = 'none';

    if outlined
        edge = color;
        if alpha == 1, edge = [1 1 1]; end
    end

    patch(ax, center(1) + radius * cos(angle), center(2) + radius * sin(angle), color, ...
        'FaceAlpha', alpha, 'EdgeColor', edge, 'LineWidth', 1, 'HitTest', 'off');
end

function label = putText(ax, point, content, color, fontSize, alignment)
    % Taille en unites de canevas pour conserver les proportions au redimensionnement.
    label = text(ax, point(1), point(2), content, 'Interpreter', 'none', ...
        'Color', color, 'FontUnits', 'normalized', ...
        'FontSize', fontSize / diff(ylim(ax)), ...
        'HorizontalAlignment', alignment, 'VerticalAlignment', 'middle', ...
        'Clipping', 'on', 'HitTest', 'off');
end

function [label, bestBox] = placeLabel(ax, point, radius, content, color, boxes, projection, preferredSide)
    label = putText(ax, point, content, color, 18, 'left');
    set(label, 'Visible', 'off');
    extent = get(label, 'Extent');
    labelSize = extent(3:4);
    bestCost = Inf;
    bestPoint = point;
    bestAlignment = 'left';
    bestBox = [point labelSize];

    for distance = [0 16 32 52]

        for side = [preferredSide -preferredSide]

            for verticalOffset = [0 -18 18 -36 36]
                anchor = point + [side * (radius + 6 + distance), verticalOffset];
                left = anchor(1);
                alignment = 'left';

                if side < 0
                    left = left - labelSize(1);
                    alignment = 'right';
                end

                box = [left anchor(2) - labelSize(2) / 2 labelSize];
                overflow = sum(max(0, [20 14] - box(1:2))) ...
                    + sum(max(0, box(1:2) + labelSize - [projection.width - 14 projection.height - 20]));
                overlap = 0;

                if ~isempty(boxes)
                    lengths = max(0, min(box(1:2) + box(3:4), boxes(:, 1:2) + boxes(:, 3:4)) ...
                        - max(box(1:2), boxes(:, 1:2)));
                    overlap = sum(prod(lengths, 2));
                end

                cost = 1e6 * overflow + 1000 * overlap + distance + abs(verticalOffset) ...
                    + 4 * (side ~= preferredSide);

                if cost < bestCost
                    bestCost = cost;
                    bestPoint = anchor;
                    bestAlignment = alignment;
                    bestBox = box;
                end

            end

        end

    end

    set(label, 'Position', [bestPoint 0], 'HorizontalAlignment', bestAlignment, 'Visible', 'on');

    if norm(bestPoint - point) > radius + 40
        target = max(bestBox(1:2), min(point, bestBox(1:2) + bestBox(3:4)));
        direction = target - point;
        start = point + radius * direction / max(norm(direction), eps);
        line(ax, [start(1) target(1)], [start(2) target(2)], ...
            'Color', [0.60 0.60 0.57], 'LineWidth', 0.5, 'HitTest', 'off');
    end

end

function releaseAxes(ax)
    if isgraphics(ax), hold(ax, 'off'); end
end
