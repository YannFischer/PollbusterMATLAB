function scene = pb_mapscene(D, result, options)
%PB_MAPSCENE Prepare les donnees de carte sans modifier D ni result.
% political : bulles a pos/by_hist, comme la carte du site fourni.
% social7   : bulles aux barycentres sociaux des SEPT categories.
% Dans les deux modes, la grille electorale inclut toujours inact.

    if nargin < 3
        options = struct();
    end
    options = defaults(options);
    categories = D.core.pcs;
    ids = {categories.id};
    expected = {'agri','cad','PI','emp','ouv','ret','inact'};
    assert(numel(ids) == 7 && all(ismember(expected, ids)), ...
        'Pollbuster:MapPCS', 'Les sept PCS, dont inact, sont requises.');
    assert(size(result.V, 2) == 7, ...
        'Pollbuster:MapVotes', 'V doit avoir sept colonnes dans l''ordre des PCS.');
    assert(size(result.V, 1) == numel(result.candidates), ...
        'Pollbuster:MapCandidates', 'Candidats et lignes de V incoherents.');
    assert(all(isfinite(result.V(:))) && all(result.V(:) >= 0), ...
        'Pollbuster:MapVotes', 'V doit contenir des voix finies et positives ou nulles.');
    assert(numel(result.pct) == size(result.V,1) && ...
        all(isfinite(result.pct(:))) && all(result.pct(:) >= 0), ...
        'Pollbuster:MapScores', 'Scores invalides.');

    % Meme referentiel brut que le moteur MATLAB, inact compris.
    rawPCS = zeros(7, 2);
    masses = zeros(1, 7);
    colors = zeros(7, 3);
    labels = cell(1, 7);
    referenceMasses = [2.3229 5.7282 7.4497 7.3789 5.5105 18.5 7.9608];
    referenceColors = {'#65a30d','#1d4ed8','#0ea5e9','#f59e0b', ...
        '#c2410c','#6b7280','#db2777'};
    for categoryIndex = 1:7
        id = ids{categoryIndex};
        sourceIndex = find(strcmp(expected, id), 1);
        if strcmp(id, 'inact')
            point = [-2.5687835393427796 -3.3472027936890765];
        else
            point = D.history.POSTES.(id);
        end
        rawPCS(categoryIndex, :) = point(:)';
        masses(categoryIndex) = referenceMasses(sourceIndex);
        colors(categoryIndex, :) = readColor(referenceColors{sourceIndex});
        labels{categoryIndex} = strrep(categories(categoryIndex).label, ...
            ', artisans, commerçants', ', artisans');
    end
    assert(all(isfinite(rawPCS(:))), 'Pollbuster:MapPCS', 'Positions PCS invalides.');

    totals = sum(result.V, 2);
    totalVotes = sum(totals);
    assert(totalVotes > 0, 'Pollbuster:MapVotes', 'Aucun suffrage exprime.');
    valid = totals > 0;
    socialRaw = nan(size(result.V, 1), 2);
    socialRaw(valid, :) = result.V(valid, :) * rawPCS ./ totals(valid);
    % Aucune exclusion de categorie dans le numerateur ni le denominateur.
    barycentreRaw = sum(result.V, 1) * rawPCS / totalVotes;
    compositions = zeros(size(result.V));
    compositions(valid, :) = result.V(valid, :) ./ totals(valid);

    political = zeros(size(result.V, 1), 2);
    candidateColors = zeros(size(result.V, 1), 3);
    candidateNames = cell(size(result.V, 1), 1);
    for candidateIndex = 1:numel(result.candidates)
        candidate = result.candidates{candidateIndex};
        if isfield(candidate, 'pos') && ~isempty(candidate.pos)
            point = candidate.pos;
        else
            point = candidate.by_hist;
        end
        assert(numel(point) == 2 && all(isfinite(point(:))), ...
            'Pollbuster:MapPosition', 'Position politique invalide.');
        political(candidateIndex, :) = point(:)';
        candidateColors(candidateIndex, :) = readColor(D.colors.(candidate.zone));
        if isfield(D, 'names') && isfield(D.names, candidate.id)
            candidateNames{candidateIndex} = D.names.(candidate.id);
        elseif isfield(candidate, 'name')
            candidateNames{candidateIndex} = candidate.name;
        else
            candidateNames{candidateIndex} = candidate.id;
        end
    end

    zones = D.core.zones(~strcmp({D.core.zones.id}, 'Z0'));
    zonePositions = zeros(numel(zones), 2);
    zoneColors = zeros(numel(zones), 3);
    zoneNames = cell(numel(zones), 1);
    shortNames = {'Extrême gauche','Gauche radicale','Communistes', ...
        'Social-démocratie','Écologie','Centre','Macronisme','Centre droit', ...
        'Droite LR','Souverainistes','RN','Droite identitaire'};
    for zoneIndex = 1:numel(zones)
        zone = zones(zoneIndex);
        zonePositions(zoneIndex, :) = zone.mu(:)';
        zoneColors(zoneIndex, :) = readColor(D.colors.(zone.id));
        number = sscanf(zone.id, 'Z%d');
        if isscalar(number) && number >= 1 && number <= 12
            zoneNames{zoneIndex} = shortNames{number};
        else
            zoneNames{zoneIndex} = zone.nom;
        end
    end

    scene.options = options;
    scene.pcsIds = ids;
    scene.rawPCS = rawPCS;
    scene.pcsPositions = toMap(rawPCS);
    scene.pcsColors = colors;
    scene.pcsNames = labels;
    scene.referenceShares = 100 * masses / sum(masses);
    scene.voteShares = 100 * sum(result.V, 1) / totalVotes;
    scene.pcsShares = scene.referenceShares;
    if strcmp(options.socialShares, 'votes')
        scene.pcsShares = scene.voteShares;
    end
    scene.barycentreRaw = barycentreRaw;
    scene.barycentre = toMap(barycentreRaw);
    scene.socialBarycentresRaw = socialRaw;
    scene.socialBarycentres = toMap(socialRaw);
    scene.candidatePositions = political;
    if strcmp(options.mode, 'social7')
        scene.candidatePositions = scene.socialBarycentres;
    end
    scene.candidateColors = candidateColors;
    scene.candidateNames = candidateNames;
    scene.compositions = compositions;
    scene.scores = result.pct(:);
    scene.zonePositions = zonePositions;
    scene.zoneColors = zoneColors;
    scene.zoneNames = zoneNames;
    scene.totalVotes = totalVotes;
end

function options = defaults(options)
    if ~isfield(options, 'mode'), options.mode = 'political'; end
    if ~isfield(options, 'socialShares'), options.socialShares = 'reference'; end
    if ~isfield(options, 'rings'), options.rings = true; end
    if ~isfield(options, 'width'), options.width = 1300; end
    if ~isfield(options, 'height'), options.height = 500; end
    assert(any(strcmp(options.mode, {'political','social7'})), ...
        'Pollbuster:MapMode', 'Mode attendu : political ou social7.');
    assert(any(strcmp(options.socialShares, {'reference','votes'})), ...
        'Pollbuster:MapShares', 'Parts attendues : reference ou votes.');
    assert(isscalar(options.width) && isfinite(options.width) && options.width >= 500 ...
        && isscalar(options.height) && isfinite(options.height) && options.height >= 250, ...
        'Pollbuster:MapCanvas', 'Largeur >= 500 et hauteur >= 250 attendues.');
end

function coordinates = toMap(raw)
    scale = 1 / 16;
    offset = [0.253 - 0.407 / 16, -0.173 + 1.467 / 16];
    coordinates = raw * scale + offset;
end

function color = readColor(value)
    if isnumeric(value)
        color = value(:)';
    else
        value = char(value);
        if startsWith(value, '#'), value = value(2:end); end
        color = sscanf(value, '%2x%2x%2x', [1 3]) / 255;
    end
    assert(numel(color) == 3 && all(isfinite(color)) && ...
        all(color >= 0 & color <= 1), 'Pollbuster:MapColor', 'Couleur RGB invalide.');
end
