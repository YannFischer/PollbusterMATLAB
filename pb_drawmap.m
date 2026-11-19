function pb_drawmap(ax, D, result, showPCS)
    %PB_DRAWMAP Affiche la carte sociale sans modifier les resultats.
    % Les aires politiques sont indicatives. Leur conversion affine vers le
    % referentiel social n'est pas une reproduction verifiee du site PollBuster.

    if nargin < 4
        showPCS = false;
    end

    style = mapStyle();
    coordinates = result.coordinates;
    validCandidates = all(isfinite(coordinates), 2);
    barycentre = result.barycentre(:)';
    socialPositions = getSocialPositions(D);
    regions = getPoliticalRegions(D, socialPositions, style);
    limits = getMapLimits(coordinates(validCandidates, :), ...
        barycentre, socialPositions, regions, showPCS);

    cla(ax);
    hold(ax, 'on');
    cleanup = onCleanup(@() releaseAxes(ax));
    set(ax, 'Color', style.background, 'XTick', [], 'YTick', [], ...
        'Box', 'off', 'YDir', 'normal', 'FontName', 'Arial');
    % Utiliser toute la surface disponible, sans imposer une unite carree.
    set(ax, ...
        'DataAspectRatioMode', 'auto', ...
        'PlotBoxAspectRatioMode', 'auto');

    xlim(ax, limits(1, :));
    ylim(ax, limits(2, :));

    drawDottedGrid(ax, limits, style);
    regionLabels = drawPoliticalRegions(ax, regions, style);
    drawReferenceAxes(ax, barycentre, limits, style);

    if showPCS
        pb_drawsocial( ...
            ax, ...
            D, ...
            result, ...
            socialPositions, ...
            style.bubbleScale);
    end

    bubbleSizes = max(1, style.bubbleScale * max(result.pct(:), 0));
    drawCandidateBubbles(ax, D, result, validCandidates, bubbleSizes);
    drawCandidateLabels(ax, D, result, validCandidates, ...
        bubbleSizes, regionLabels, style);

    title(ax, sprintf('Simulation | %.2f M de suffrages exprimes', ...
        result.E / 1e6), 'FontWeight', 'normal', 'FontSize', 10);
    xlabel(ax, ...
        'Surface des bulles proportionnelle au score ; aires indicatives', ...
        'FontSize', 8);
end

function style = mapStyle()
    style.background = [0.99 0.99 0.98];
    style.gridColor = [0.80 0.81 0.80];
    style.axisColor = [0.57 0.58 0.54];
    style.textColor = [0.12 0.12 0.12];
    style.bubbleScale = 55;
    style.labelFontSize = 9;
    style.regionAlpha = 0.085;
    % Rayon fixe en unites sociales : independant du cadrage et des PCS.
    style.regionRadius = 0.65;
    style.regionRadiusFraction = 0.10;
    style.labelSearchRings = [0 12 26 44 68 96];
end

function positions = getSocialPositions(D)
    positions = nan(numel(D.core.pcs), 2);

    for index = 1:numel(D.core.pcs)
        id = D.core.pcs(index).id;

        if strcmp(id, 'inact')
            point = [-2.5687835393427796 -3.3472027936890765];
        elseif isfield(D.history.POSTES, id)
            point = D.history.POSTES.(id);
        else
            error('Pollbuster:MissingSocialPosition', ...
                'Coordonnees sociales absentes pour "%s".', id);
        end

        positions(index, :) = point(:)';
    end

end

function regions = getPoliticalRegions(D, socialPositions, style)
    %GETPOLITICALREGIONS Aires de reference dans le referentiel social.
    %
    % Chaque centre est le barycentre social du profil historique de sa zone.
    % Les poids utilisent les effectifs PCS et la participation de reference.
    % Les aires restent indicatives : ce ne sont pas des regions statistiques.

    regions = struct( ...
        'center', {}, ...
        'radius', {}, ...
        'name', {}, ...
        'color', {});

    categories = D.core.pcs;
    categoryCount = numel(categories);

    referencePopulation = zeros(categoryCount, 1);

    for categoryIndex = 1:categoryCount
        category = categories(categoryIndex);

        referencePopulation(categoryIndex) = ...
            category.n * D.core.part.(category.id);
    end

    for zoneIndex = 1:numel(D.core.zones)
        zone = D.core.zones(zoneIndex);

        if strcmp(zone.id, 'Z0')
            continue
        end

        historicalProfile = D.core.hist.(zone.key);
        weights = zeros(categoryCount, 1);

        for categoryIndex = 1:categoryCount
            categoryId = categories(categoryIndex).id;
            historicalValues = historicalProfile.(categoryId);

            penetration = mean(historicalValues(:));

            weights(categoryIndex) = ...
                penetration * referencePopulation(categoryIndex);
        end

        validRows = ...
            all(isfinite(socialPositions), 2) ...
            & isfinite(weights) ...
            & weights > 0;

        totalWeight = sum(weights(validRows));

        if totalWeight <= 0
            warning( ...
                'Pollbuster:EmptyMapRegion', ...
                'Aire ignoree : profil vide pour %s.', ...
                zone.id);

            continue
        end

        center = ...
            weights(validRows)' * socialPositions(validRows, :) ...
            / totalWeight;

        region = struct( ...
            'center', center, ...
            'radius', style.regionRadius, ...
            'name', shortZoneName(zone), ...
            'color', zoneColor(D, zone.id));

        regions(end + 1) = region; %#ok<AGROW>
    end

    % Taille graphique fondee sur les reperes historiques uniquement.
    % Elle ne change pas quand on active un candidat ou les reperes PCS.

    if numel(regions) >= 2
        centers = vertcat(regions.center);

        referenceSpan = ...
            max(centers, [], 1) - min(centers, [], 1);

        referenceRadius = ...
            style.regionRadiusFraction * max(referenceSpan);

        if isfinite(referenceRadius) && referenceRadius > 0

            for regionIndex = 1:numel(regions)
                regions(regionIndex).radius = referenceRadius;
            end

        end

    end

end

function limits = getMapLimits(points, barycentre, socialPositions, regions, showPCS)

    if all(isfinite(barycentre))
        points = [points; barycentre];
    end

    if showPCS
        points = [points; socialPositions];
    end

    for index = 1:numel(regions)
        center = regions(index).center;
        radius = regions(index).radius;
        points = [points; center - radius; center + radius]; %#ok<AGROW>
    end

    points = points(all(isfinite(points), 2), :);

    if isempty(points)
        points = [-1 -1; 1 1];
    end

    lower = min(points, [], 1);
    upper = max(points, [], 1);
    span = max(upper - lower, [2 2]);
    lower = lower - 0.12 * span;
    upper = upper + 0.16 * span;
    limits = [lower(1) upper(1); lower(2) upper(2)];
end

function drawDottedGrid(ax, limits, style)
    step = max(diff(limits, 1, 2)) / 65;
    [gridX, gridY] = meshgrid(limits(1, 1):step:limits(1, 2), ...
        limits(2, 1):step:limits(2, 2));
    plot(ax, gridX(:), gridY(:), '.', 'Color', style.gridColor, ...
        'MarkerSize', 3, 'HitTest', 'off');
end

function labels = drawPoliticalRegions(ax, regions, style)
    labels = gobjects(numel(regions), 1);
    angle = linspace(0, 2 * pi, 100);

    for index = 1:numel(regions)
        region = regions(index);
        patch(ax, region.center(1) + region.radius * cos(angle), ...
            region.center(2) + region.radius * sin(angle), region.color, ...
            'FaceAlpha', style.regionAlpha, 'EdgeColor', 'none', ...
            'HitTest', 'off');
        labels(index) = text(ax, region.center(1), ...
            region.center(2) - 0.74 * region.radius, region.name, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 8, 'Color', [0.32 0.32 0.32], ...
            'Interpreter', 'none', 'Clipping', 'on', 'HitTest', 'off');
    end

end

function drawReferenceAxes(ax, barycentre, limits, style)

    if any(~isfinite(barycentre))
        return
    end

    plot(ax, limits(1, :), [barycentre(2) barycentre(2)], ...
        'Color', style.axisColor, 'LineWidth', 0.7);
    plot(ax, [barycentre(1) barycentre(1)], limits(2, :), ...
        'Color', style.axisColor, 'LineWidth', 0.7);
    scatter(ax, barycentre(1), barycentre(2), 14, [0.28 0.29 0.27], 'filled');
    text(ax, limits(1, 1), barycentre(2), ' travail', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9);
    text(ax, limits(1, 2), barycentre(2), 'capital ', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    text(ax, barycentre(1), limits(2, 2), ' direction', ...
        'VerticalAlignment', 'top', 'FontSize', 9);
    text(ax, barycentre(1), limits(2, 1), ' subordination', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9);
end

function drawCandidateBubbles(ax, D, result, validCandidates, bubbleSizes)
    [~, order] = sort(result.pct(:), 'descend');

    for index = order(:)'

        if ~validCandidates(index)
            continue
        end

        candidate = result.candidates{index};
        scatter(ax, result.coordinates(index, 1), result.coordinates(index, 2), ...
            bubbleSizes(index), zoneColor(D, candidate.zone), 'filled', ...
            'MarkerEdgeColor', 'white', 'LineWidth', 0.9);
    end

end

function drawCandidateLabels(ax, D, result, validCandidates, bubbleSizes, regionLabels, style)
    drawnow;
    geometry = getPlotGeometry(ax);
    candidatePixels = (result.coordinates - geometry.origin) .* geometry.scale;
    % Marge conservative pour la collision, pas un rayon physique exact.
    dpi = get(groot, 'ScreenPixelsPerInch');
    bubbleMargins = 0.60 * sqrt(bubbleSizes) * dpi / 72 + 2;
    regionBoxes = getLabelBoxes(regionLabels, geometry);
    occupiedBoxes = zeros(0, 4);
    [~, order] = sort(result.pct(:), 'descend');

    for index = order(:)'

        if ~validCandidates(index)
            continue
        end

        candidate = result.candidates{index};
        fallback = pb_get(candidate, 'name', result.ids{index});
        name = pb_get(D.names, result.ids{index}, fallback);
        score = strrep(sprintf('%.1f', result.pct(index)), '.', ',');
        labelText = sprintf('%s %s %%', char(name), score);
        label = text(ax, 0, 0, labelText, 'Interpreter', 'none', ...
            'FontSize', style.labelFontSize, 'Color', style.textColor, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'Visible', 'off', 'Clipping', 'on');
        set(label, 'Units', 'pixels');
        extent = get(label, 'Extent');
        labelSize = extent(3:4);
        rectangle = chooseLabelBox(candidatePixels(index, :), ...
            bubbleMargins(index), labelSize, geometry.size, ...
            occupiedBoxes, regionBoxes, candidatePixels(validCandidates, :), ...
            bubbleMargins(validCandidates), style.labelSearchRings);
        occupiedBoxes(end + 1, :) = rectangle + [-3 -2 6 4]; %#ok<AGROW>
        labelAnchor = [rectangle(1) rectangle(2) + rectangle(4) / 2];
        labelPosition = labelAnchor ./ geometry.scale + geometry.origin;
        set(label, 'Units', 'data', 'Position', [labelPosition 0], 'Visible', 'on');
        drawLabelConnector(ax, candidatePixels(index, :), ...
            bubbleMargins(index), rectangle, geometry);
    end

end

function geometry = getPlotGeometry(ax)
    %GETPLOTGEOMETRY Conversion des coordonnees de donnees en pixels.
    % A utiliser avec les rapports d'aspect en mode automatique.

    drawnow;

    axesBox = getpixelposition(ax, true);

    horizontalLimits = xlim(ax);
    verticalLimits = ylim(ax);

    dataWidth = diff(horizontalLimits);
    dataHeight = diff(verticalLimits);

    geometry.origin = [ ...
                           horizontalLimits(1), ...
                           verticalLimits(1)];

    geometry.size = axesBox(3:4);

    geometry.scale = [ ...
                          geometry.size(1) / dataWidth, ...
                          geometry.size(2) / dataHeight];
end

function boxes = getLabelBoxes(labels, geometry)
    boxes = zeros(numel(labels), 4);

    for index = 1:numel(labels)
        label = labels(index);
        position = get(label, 'Position');
        center = (position(1:2) - geometry.origin) .* geometry.scale;
        set(label, 'Units', 'pixels');
        extent = get(label, 'Extent');
        set(label, 'Units', 'data');
        labelSize = extent(3:4);
        boxes(index, :) = [center - labelSize / 2 labelSize];
    end

end

function bestBox = chooseLabelBox(point, margin, labelSize, viewportSize, ...
        occupiedBoxes, regionBoxes, candidatePixels, bubbleMargins, searchRings)
    directions = [1 0; -1 0; 1 1; 1 -1; -1 1; -1 -1; 0 1; 0 -1];
    bestCost = Inf;
    bestBox = [point labelSize];

    for ring = searchRings

        for directionIndex = 1:size(directions, 1)
            direction = directions(directionIndex, :);
            anchor = point + (margin + 5 + ring) * direction;

            if direction(1) > 0
                left = anchor(1);
            elseif direction(1) < 0
                left = anchor(1) - labelSize(1);
            else
                left = anchor(1) - labelSize(1) / 2;
            end

            rectangle = [left anchor(2) - labelSize(2) / 2 labelSize];
            overflow = sum(max(0, -rectangle(1:2))) ...
                + sum(max(0, rectangle(1:2) + labelSize - viewportSize));
            cost = 1e6 * overflow ...
                +2e3 * overlapArea(rectangle, occupiedBoxes) ...
                + 30 * overlapArea(rectangle, regionBoxes) ...
                + 2 * ring + directionIndex;

            for candidateIndex = 1:size(candidatePixels, 1)
                closest = max(rectangle(1:2), min(candidatePixels(candidateIndex, :), ...
                    rectangle(1:2) + labelSize));
                distance = norm(closest - candidatePixels(candidateIndex, :));
                penetration = max(0, bubbleMargins(candidateIndex) - distance);
                cost = cost + 300 * penetration ^ 2;
            end

            if cost < bestCost
                bestCost = cost;
                bestBox = rectangle;
            end

        end

    end

end

function total = overlapArea(rectangle, boxes)

    if isempty(boxes)
        total = 0;
        return
    end

    lower = max(rectangle(1:2), boxes(:, 1:2));
    upper = min(rectangle(1:2) + rectangle(3:4), boxes(:, 1:2) + boxes(:, 3:4));
    intersection = max(0, upper - lower);
    total = sum(prod(intersection, 2));
end

function drawLabelConnector(ax, point, margin, rectangle, geometry)
    target = max(rectangle(1:2), min(point, rectangle(1:2) + rectangle(3:4)));
    distance = norm(target - point);

    if distance <= margin + 23
        return
    end

    direction = (target - point) / distance;
    start = (point + margin * direction) ./ geometry.scale + geometry.origin;
    finish = target ./ geometry.scale + geometry.origin;
    line(ax, [start(1) finish(1)], [start(2) finish(2)], ...
        'Color', [0.58 0.59 0.56], 'LineWidth', 0.5, 'HitTest', 'off');
end

function color = zoneColor(D, id)
    value = pb_get(D.colors, id, '#888888');

    if isnumeric(value)
        color = value(:)';
        return
    end

    value = char(value);

    if startsWith(value, '#')
        value = value(2:end);
    end

    color = sscanf(value, '%2x%2x%2x', [1 3]) / 255;

    if numel(color) ~= 3
        color = [0.5 0.5 0.5];
    end

end

function name = shortZoneName(zone)
    ids = {'Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', ...
               'Z7', 'Z8', 'Z9', 'Z10', 'Z11', 'Z12'};
    names = {'Extreme gauche', 'Gauche radicale', 'Communistes', ...
                 'Social-democratie', 'Ecologie', 'Centre', 'Macronisme', ...
                 'Centre droit', 'Droite LR', 'Souverainistes', 'RN', 'Droite identitaire'};
    index = find(strcmp(ids, zone.id), 1);

    if isempty(index)
        name = zone.nom;
    else
        name = names{index};
    end

end

function releaseAxes(ax)

    if isgraphics(ax)
        hold(ax, 'off');
    end

end
